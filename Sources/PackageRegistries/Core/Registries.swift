//
//  Registries.swift
//  PackageRegistries
//
//  Created by David Sherlock on 2026.
//
//  The front door: the four clients under one roof, and the all-at-once
//  lookup that asks them in parallel. "Which registry is `foo` on, and
//  what is it there?" is one call.
//

import Foundation

/// All four registries, one interface.
public struct Registries: Sendable {

    /// Identifies this library to the registries, as crates.io asks
    /// nicely for and enforces. Repo URL, not a person — the polite form.
    public static let defaultUserAgent =
        "swift-package-registries/0.1 (+https://github.com/arraypress/swift-package-registries)"

    /// URLSession, as a `Transport`.
    public static let defaultTransport: Transport = { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RegistryError.malformed("not an HTTP response")
        }
        return (data, http)
    }

    public let npm: NPMClient
    public let pypi: PyPIClient
    public let crates: CratesClient
    public let brew: BrewClient

    public init(userAgent: String = Registries.defaultUserAgent,
                transport: @escaping Transport = Registries.defaultTransport) {
        let fetch = Fetcher(transport: transport, userAgent: userAgent)
        npm = NPMClient(fetch: fetch)
        pypi = PyPIClient(fetch: fetch)
        crates = CratesClient(fetch: fetch)
        brew = BrewClient(fetch: fetch)
    }

    /// One registry's answer.
    public func info(_ name: String, in registry: Registry) async throws -> PackageInfo {
        switch registry {
        case .npm: return try await npm.info(name)
        case .pypi: return try await pypi.info(name)
        case .crates: return try await crates.info(name)
        case .brew: return try await brew.info(name)
        }
    }

    /// One registry's published versions, newest first.
    public func versions(_ name: String, in registry: Registry) async throws -> [PackageVersion] {
        switch registry {
        case .npm: return try await npm.versions(name)
        case .pypi: return try await pypi.versions(name)
        case .crates: return try await crates.versions(name)
        case .brew: return try await brew.versions(name)
        }
    }

    /// Every registry asked at once. Each key holds either the package or
    /// why not — a 404 on PyPI is an answer worth showing, not a failure
    /// that should hide npm's hit.
    public func lookup(_ name: String) async -> [Registry: Result<PackageInfo, Error>] {
        await withTaskGroup(of: (Registry, Result<PackageInfo, Error>).self) { group in
            for registry in Registry.allCases {
                group.addTask {
                    do { return (registry, .success(try await info(name, in: registry))) }
                    catch { return (registry, .failure(error)) }
                }
            }
            var results: [Registry: Result<PackageInfo, Error>] = [:]
            for await (registry, result) in group { results[registry] = result }
            return results
        }
    }
}
