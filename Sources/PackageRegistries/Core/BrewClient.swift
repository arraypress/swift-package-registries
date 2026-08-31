//
//  BrewClient.swift
//  PackageRegistries
//
//  Created by David Sherlock on 2026.
//
//  formulae.brew.sh/api/formula/<name>.json — the static API the brew
//  client itself reads. One stable version per formula is the model, so
//  `versions` honestly returns one entry.
//

import Foundation

/// Homebrew.
public struct BrewClient: Sendable {
    let fetch: Fetcher

    init(fetch: Fetcher) { self.fetch = fetch }

    public init(userAgent: String = Registries.defaultUserAgent,
                transport: @escaping Transport = Registries.defaultTransport) {
        self.init(fetch: Fetcher(transport: transport, userAgent: userAgent))
    }

    /// The formula: stable version, license, direct dependencies.
    public func info(_ name: String) async throws -> PackageInfo {
        let doc = try await document(name)
        return PackageInfo(name: doc.name ?? name, registry: .brew, version: doc.versions.stable,
                           description: doc.desc, license: doc.license, homepage: doc.homepage,
                           dependencies: doc.dependencies?.count)
    }

    /// Homebrew keeps one stable version; that one, honestly.
    public func versions(_ name: String) async throws -> [PackageVersion] {
        let doc = try await document(name)
        return [PackageVersion(version: doc.versions.stable)]
    }

    private func document(_ name: String) async throws -> Doc {
        try await fetch.decode(Doc.self,
            from: URL(string: "https://formulae.brew.sh/api/formula/\(pathEncoded(name)).json")!,
            registry: .brew, name: name)
    }

    private struct Doc: Decodable {
        let name: String?
        let desc: String?
        let license: String?
        let homepage: String?
        let versions: Versions
        let dependencies: [String]?
    }

    private struct Versions: Decodable { let stable: String }
}
