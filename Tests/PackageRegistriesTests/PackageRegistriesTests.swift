//
//  PackageRegistriesTests.swift
//  PackageRegistriesTests
//
//  Created by David Sherlock on 2026.
//
//  Recorded registry responses in, normalised answers out — no network.
//  The fixtures are real captures (2026-08-30): left-pad from npm,
//  requests from PyPI, serde from crates.io, jq from Homebrew.
//

import Foundation
import XCTest
@testable import PackageRegistries

/// Requests seen by the stub transport, lock-guarded — a @Sendable
/// closure cannot capture a mutable local.
final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []
    func add(_ request: URLRequest) { lock.lock(); requests.append(request); lock.unlock() }
    var all: [URLRequest] { lock.lock(); defer { lock.unlock() }; return requests }
}

final class PackageRegistriesTests: XCTestCase {

    func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    /// A transport answering from fixtures by URL substring.
    func stub(_ routes: [(contains: String, status: Int, body: Data)], log: RequestLog? = nil) -> Transport {
        { request in
            log?.add(request)
            let url = request.url!.absoluteString
            guard let route = routes.first(where: { url.contains($0.contains) }) else {
                XCTFail("unrouted request: \(url)")
                throw RegistryError.malformed("unrouted")
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: route.status,
                                           httpVersion: nil, headerFields: nil)!
            return (route.body, response)
        }
    }

    func testNPMInfoMergesLatestAndDownloads() async throws {
        let log = RequestLog()
        let client = NPMClient(transport: stub([
            (contains: "api.npmjs.org/downloads", status: 200, body: try fixture("npm-downloads")),
            (contains: "registry.npmjs.org/left-pad/latest", status: 200, body: try fixture("npm-latest")),
        ], log: log))
        let info = try await client.info("left-pad")
        XCTAssertEqual(info.version, "1.3.0")
        XCTAssertEqual(info.registry, .npm)
        XCTAssertEqual(info.license, "WTFPL")
        XCTAssertEqual(info.downloads, 1855290)
        XCTAssertEqual(info.downloadsPeriod, "week")
        XCTAssertNotNil(info.description)
        XCTAssertTrue(log.all.allSatisfy { $0.value(forHTTPHeaderField: "User-Agent")?.contains("swift-package-registries") == true },
                      "every request identifies the library")
    }

    func testNPMDownloadsFailureDoesNotSinkTheAnswer() async throws {
        let client = NPMClient(transport: stub([
            (contains: "api.npmjs.org/downloads", status: 500, body: Data()),
            (contains: "registry.npmjs.org/left-pad/latest", status: 200, body: try fixture("npm-latest")),
        ]))
        let info = try await client.info("left-pad")
        XCTAssertEqual(info.version, "1.3.0")
        XCTAssertNil(info.downloads)
    }

    func testNPMVersionsComeNewestFirstWithDates() async throws {
        let client = NPMClient(transport: stub([
            (contains: "registry.npmjs.org/left-pad", status: 200, body: try fixture("npm-full")),
        ]))
        let versions = try await client.versions("left-pad")
        XCTAssertEqual(versions.count, 15)
        XCTAssertEqual(versions.first?.version, "1.3.0", "newest first")
        XCTAssertNotNil(versions.first?.publishedAt)
    }

    func testNPMScopedNamesEncodeTheSlash() {
        XCTAssertEqual(pathEncoded("@types/node"), "@types%2Fnode")
        XCTAssertEqual(pathEncoded("left-pad"), "left-pad")
    }

    func testPyPIInfoReadsTheOneDocument() async throws {
        let client = PyPIClient(transport: stub([
            (contains: "pypi.org/pypi/requests/json", status: 200, body: try fixture("pypi")),
        ]))
        let info = try await client.info("requests")
        XCTAssertEqual(info.version, "2.34.2")
        XCTAssertEqual(info.license, "Apache-2.0")
        XCTAssertEqual(info.versionsCount, 163)
        XCTAssertNotNil(info.description)
        XCTAssertNotNil(info.homepage)
    }

    func testPyPIVersionsAreDatedFromUploads() async throws {
        let client = PyPIClient(transport: stub([
            (contains: "pypi.org", status: 200, body: try fixture("pypi")),
        ]))
        let versions = try await client.versions("requests")
        XCTAssertEqual(versions.count, 163)
        XCTAssertEqual(versions.first?.version, "2.34.2", "newest release first")
    }

    func testCratesInfoReadsCrateAndVersions() async throws {
        let client = CratesClient(transport: stub([
            (contains: "crates.io/api/v1/crates/serde", status: 200, body: try fixture("crates")),
        ]))
        let info = try await client.info("serde")
        XCTAssertEqual(info.version, "1.0.229")
        XCTAssertEqual(info.downloads, 1331262583)
        XCTAssertEqual(info.downloadsPeriod, "all time")
        XCTAssertEqual(info.versionsCount, 316)
        XCTAssertEqual(info.license, "MIT OR Apache-2.0")
    }

    func testBrewInfoReadsTheFormula() async throws {
        let client = BrewClient(transport: stub([
            (contains: "formulae.brew.sh/api/formula/jq.json", status: 200, body: try fixture("brew")),
        ]))
        let info = try await client.info("jq")
        XCTAssertEqual(info.version, "1.8.2")
        XCTAssertEqual(info.license, "MIT")
        XCTAssertEqual(info.dependencies, 1)
        XCTAssertNotNil(info.description)
    }

    func testLookupAsksAllFourAndKeepsMissesAsAnswers() async throws {
        let registries = Registries(transport: stub([
            (contains: "api.npmjs.org/downloads", status: 200, body: try fixture("npm-downloads")),
            (contains: "registry.npmjs.org", status: 200, body: try fixture("npm-latest")),
            (contains: "pypi.org", status: 404, body: Data()),
            (contains: "crates.io", status: 200, body: try fixture("crates")),
            (contains: "formulae.brew.sh", status: 404, body: Data()),
        ]))
        let results = await registries.lookup("left-pad")
        XCTAssertEqual(results.count, 4)
        XCTAssertEqual(try results[.npm]?.get().version, "1.3.0")
        XCTAssertEqual(try results[.crates]?.get().version, "1.0.229")
        guard case .failure(let error as RegistryError) = results[.pypi] else { return XCTFail("pypi should miss") }
        XCTAssertEqual(error, .notFound(name: "left-pad", registry: .pypi))
    }

    func testUnexpectedStatusIsTyped() async {
        let client = BrewClient(transport: stub([(contains: "formulae", status: 500, body: Data())]))
        do {
            _ = try await client.info("jq")
            XCTFail("500 should throw")
        } catch let error as RegistryError {
            XCTAssertEqual(error, .http(500, registry: .brew))
        } catch { XCTFail("wrong error: \(error)") }
    }

    func testInstallLines() {
        XCTAssertEqual(Registry.npm.installLine(for: "left-pad"), "npm install left-pad")
        XCTAssertEqual(Registry.brew.installLine(for: "jq"), "brew install jq")
    }
}
