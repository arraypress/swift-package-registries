//
//  CratesClient.swift
//  PackageRegistries
//
//  Created by David Sherlock on 2026.
//
//  crates.io/api/v1/crates/<name> — crate plus every version in one
//  response. crates.io is the registry that REQUIRES the User-Agent; the
//  license lives on the version, not the crate.
//

import Foundation

/// crates.io.
public struct CratesClient: Sendable {
    let fetch: Fetcher

    init(fetch: Fetcher) { self.fetch = fetch }

    public init(userAgent: String = Registries.defaultUserAgent,
                transport: @escaping Transport = Registries.defaultTransport) {
        self.init(fetch: Fetcher(transport: transport, userAgent: userAgent))
    }

    /// The crate: latest stable version, all-time downloads, versions count.
    public func info(_ name: String) async throws -> PackageInfo {
        let doc = try await document(name)
        return PackageInfo(name: doc.crate.name ?? name, registry: .crates,
                           version: doc.crate.maxStableVersion ?? doc.crate.maxVersion,
                           description: doc.crate.description,
                           license: doc.versions?.first?.license,
                           homepage: doc.crate.homepage ?? doc.crate.repository,
                           downloads: doc.crate.downloads, downloadsPeriod: doc.crate.downloads.map { _ in "all time" },
                           versionsCount: doc.versions?.count)
    }

    /// Every published version, newest first (the API's own order).
    public func versions(_ name: String) async throws -> [PackageVersion] {
        let doc = try await document(name)
        return (doc.versions ?? []).map { PackageVersion(version: $0.num, publishedAt: $0.createdAt) }
    }

    private func document(_ name: String) async throws -> Doc {
        try await fetch.decode(Doc.self,
            from: URL(string: "https://crates.io/api/v1/crates/\(pathEncoded(name))")!,
            registry: .crates, name: name)
    }

    private struct Doc: Decodable {
        let crate: Crate
        let versions: [Version]?
    }

    private struct Crate: Decodable {
        let name: String?
        let maxVersion: String
        let maxStableVersion: String?
        let description: String?
        let homepage: String?
        let repository: String?
        let downloads: Int?
        enum CodingKeys: String, CodingKey {
            case name, description, homepage, repository, downloads
            case maxVersion = "max_version"
            case maxStableVersion = "max_stable_version"
        }
    }

    private struct Version: Decodable {
        let num: String
        let license: String?
        let createdAt: String?
        enum CodingKeys: String, CodingKey {
            case num, license
            case createdAt = "created_at"
        }
    }
}
