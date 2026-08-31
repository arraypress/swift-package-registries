//
//  PyPIClient.swift
//  PackageRegistries
//
//  Created by David Sherlock on 2026.
//
//  pypi.org/pypi/<name>/json — one call carries everything: metadata and
//  the full release map. PyPI's license field is the messy one: old
//  packages hold entire license TEXTS there, new ones an SPDX expression
//  in license_expression, so the expression wins when present.
//

import Foundation

/// PyPI.
public struct PyPIClient: Sendable {
    let fetch: Fetcher

    init(fetch: Fetcher) { self.fetch = fetch }

    public init(userAgent: String = Registries.defaultUserAgent,
                transport: @escaping Transport = Registries.defaultTransport) {
        self.init(fetch: Fetcher(transport: transport, userAgent: userAgent))
    }

    /// The project's metadata and how many releases it has made.
    public func info(_ name: String) async throws -> PackageInfo {
        let doc = try await document(name)
        let license = [doc.info.licenseExpression, doc.info.license]
            .compactMap { $0 }.first { !$0.isEmpty }
        return PackageInfo(name: doc.info.name ?? name, registry: .pypi, version: doc.info.version,
                           description: doc.info.summary, license: license,
                           homepage: doc.info.bestHomepage,
                           dependencies: doc.info.requiresDist?.count,
                           versionsCount: doc.releases?.count)
    }

    /// Every release, newest first, dated from its first uploaded file.
    public func versions(_ name: String) async throws -> [PackageVersion] {
        let doc = try await document(name)
        return (doc.releases ?? [:])
            .map { PackageVersion(version: $0.key, publishedAt: $0.value.first?.uploadTime) }
            .sorted { ($0.publishedAt ?? "") > ($1.publishedAt ?? "") }
    }

    private func document(_ name: String) async throws -> Doc {
        try await fetch.decode(Doc.self,
            from: URL(string: "https://pypi.org/pypi/\(pathEncoded(name))/json")!,
            registry: .pypi, name: name)
    }

    private struct Doc: Decodable {
        let info: Info
        let releases: [String: [FileMeta]]?
    }

    private struct Info: Decodable {
        let name: String?
        let version: String
        let summary: String?
        let license: String?
        let licenseExpression: String?
        let homePage: String?
        let projectUrls: [String: String?]?
        let requiresDist: [String]?

        /// The nearest thing to a home page. Modern packages skip
        /// home_page and file everything under project_urls with keys of
        /// their choosing — requests, for one, offers only Documentation
        /// and Source — so preference order, then anything, deterministically.
        var bestHomepage: String? {
            if let homePage, !homePage.isEmpty { return homePage }
            let urls = (projectUrls ?? [:]).compactMapValues { $0 }
            for key in ["Homepage", "homepage", "Documentation", "Source", "Repository"] {
                if let url = urls[key] { return url }
            }
            return urls.sorted { $0.key < $1.key }.first?.value
        }

        // Spelled out: .convertFromSnakeCase mangles digit-bearing keys
        // like upload_time_iso_8601's siblings, so no strategy is trusted.
        enum CodingKeys: String, CodingKey {
            case name, version, summary, license
            case licenseExpression = "license_expression"
            case homePage = "home_page"
            case projectUrls = "project_urls"
            case requiresDist = "requires_dist"
        }
    }

    private struct FileMeta: Decodable {
        let uploadTime: String?
        enum CodingKeys: String, CodingKey { case uploadTime = "upload_time_iso_8601" }
    }
}
