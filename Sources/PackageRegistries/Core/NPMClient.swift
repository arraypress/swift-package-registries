//
//  NPMClient.swift
//  PackageRegistries
//
//  Created by David Sherlock on 2026.
//
//  registry.npmjs.org. The info call is `/<name>/latest` — small — plus a
//  best-effort weekly download count from the separate api.npmjs.org;
//  the full document (every version ever) is fetched only for `versions`.
//

import Foundation

/// npm.
public struct NPMClient: Sendable {
    let fetch: Fetcher

    init(fetch: Fetcher) { self.fetch = fetch }

    public init(userAgent: String = Registries.defaultUserAgent,
                transport: @escaping Transport = Registries.defaultTransport) {
        self.init(fetch: Fetcher(transport: transport, userAgent: userAgent))
    }

    /// The latest version and its metadata, with last week's downloads.
    public func info(_ name: String) async throws -> PackageInfo {
        let latest = try await fetch.decode(LatestDoc.self,
            from: URL(string: "https://registry.npmjs.org/\(pathEncoded(name))/latest")!,
            registry: .npm, name: name)
        // Downloads live on a different host and its hiccups should not
        // sink the answer — best effort, nil when unreachable.
        let downloads = try? await fetch.decode(DownloadsDoc.self,
            from: URL(string: "https://api.npmjs.org/downloads/point/last-week/\(pathEncoded(name))")!,
            registry: .npm, name: name).downloads
        return PackageInfo(name: latest.name ?? name, registry: .npm, version: latest.version,
                           description: latest.description, license: latest.license,
                           homepage: latest.homepage,
                           downloads: downloads, downloadsPeriod: downloads.map { _ in "week" },
                           dependencies: latest.dependencies?.count)
    }

    /// Every published version, newest first, dated from the `time` map.
    public func versions(_ name: String) async throws -> [PackageVersion] {
        let doc = try await fetch.decode(FullDoc.self,
            from: URL(string: "https://registry.npmjs.org/\(pathEncoded(name))")!,
            registry: .npm, name: name)
        // ISO 8601 sorts chronologically as text; no date parsing needed.
        return (doc.versions ?? [:]).keys
            .map { PackageVersion(version: $0, publishedAt: doc.time?[$0]) }
            .sorted { ($0.publishedAt ?? "") > ($1.publishedAt ?? "") }
    }

    private struct LatestDoc: Decodable {
        let name: String?
        let version: String
        let description: String?
        let license: String?
        let homepage: String?
        let dependencies: [String: String]?

        enum CodingKeys: String, CodingKey { case name, version, description, license, homepage, dependencies }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            version = try c.decode(String.self, forKey: .version)
            description = try c.decodeIfPresent(String.self, forKey: .description)
            homepage = try c.decodeIfPresent(String.self, forKey: .homepage)
            dependencies = try c.decodeIfPresent([String: String].self, forKey: .dependencies)
            // Old packages carry license as {type, url}; new ones a string.
            if let text = try? c.decode(String.self, forKey: .license) {
                license = text
            } else if let object = try? c.decode(LicenseObject.self, forKey: .license) {
                license = object.type
            } else {
                license = nil
            }
        }
    }

    private struct LicenseObject: Decodable { let type: String? }
    private struct DownloadsDoc: Decodable { let downloads: Int }
    private struct Empty: Decodable {}
    private struct FullDoc: Decodable {
        let versions: [String: Empty]?
        let time: [String: String]?
    }
}
