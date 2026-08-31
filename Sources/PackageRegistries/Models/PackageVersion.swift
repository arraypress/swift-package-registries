//
//  PackageVersion.swift
//  PackageRegistries
//
//  Created by David Sherlock on 2026.
//

/// One published version.
public struct PackageVersion: Sendable, Equatable, Codable {
    /// The version string as published.
    public let version: String
    /// When it was published, ISO 8601, where the registry says.
    public let publishedAt: String?

    public init(version: String, publishedAt: String? = nil) {
        self.version = version
        self.publishedAt = publishedAt
    }
}
