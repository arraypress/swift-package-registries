//
//  RegistryError.swift
//  PackageRegistries
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a registry can say other than an answer.
public enum RegistryError: Error, LocalizedError, Sendable, Equatable {
    /// The registry answered: no such package. Distinct from failure,
    /// because "not on PyPI" is an answer the caller shows.
    case notFound(name: String, registry: Registry)
    /// The registry answered with an unexpected status.
    case http(Int, registry: Registry)
    /// The response was not the shape the registry documents.
    case malformed(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let name, let registry): return "\(name) is not on \(registry.displayName)"
        case .http(let status, let registry): return "\(registry.displayName) answered HTTP \(status)"
        case .malformed(let detail): return "unexpected response: \(detail)"
        }
    }
}
