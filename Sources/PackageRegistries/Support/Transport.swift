//
//  Transport.swift
//  PackageRegistries
//
//  Created by David Sherlock on 2026.
//
//  One function type is the whole network seam. Tests hand in a closure
//  that returns fixtures; the app never notices. The Fetcher on top adds
//  the three things every registry call needs — the polite User-Agent
//  (crates.io refuses without one), the Accept header, and the mapping
//  of 404 to "not there", which is an answer, not an error.
//

import Foundation

/// How bytes are fetched. Inject to test; default is URLSession.
public typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

/// The shared request path: headers on, status codes read.
struct Fetcher: Sendable {
    let transport: Transport
    let userAgent: String

    func json(_ url: URL, registry: Registry, name: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await transport(request)
        switch response.statusCode {
        case 200: return data
        case 404: throw RegistryError.notFound(name: name, registry: registry)
        default: throw RegistryError.http(response.statusCode, registry: registry)
        }
    }

    func decode<T: Decodable>(_ type: T.Type, from url: URL, registry: Registry, name: String) async throws -> T {
        let data = try await json(url, registry: registry, name: name)
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw RegistryError.malformed("\(registry.displayName): \(error)")
        }
    }
}

/// A package name made path-safe. Only the slash needs encoding in
/// practice — npm's `@scope/name` must travel as `@scope%2Fname` or the
/// registry reads it as two path segments.
func pathEncoded(_ name: String) -> String {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "/")
    return name.addingPercentEncoding(withAllowedCharacters: allowed) ?? name
}
