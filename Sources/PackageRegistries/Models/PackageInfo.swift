//
//  PackageInfo.swift
//  PackageRegistries
//
//  Created by David Sherlock on 2026.
//
//  Four registries, four schemas, one answer. The fields are the ones an
//  agent or a human actually asks for — latest version, license, how
//  popular — and a field a registry does not offer stays nil rather than
//  being scraped from somewhere less honest.
//

/// What a registry knows about a package, normalised.
public struct PackageInfo: Sendable, Equatable, Codable {
    /// The package's name as the registry spells it.
    public let name: String
    /// Where this answer came from.
    public let registry: Registry
    /// The latest version.
    public let version: String
    /// The registry's one-line description.
    public let description: String?
    /// SPDX-ish license text, as the registry reports it.
    public let license: String?
    /// The project's home page.
    public let homepage: String?
    /// Download count, where the registry offers one — see `downloadsPeriod`.
    public let downloads: Int?
    /// What `downloads` counts: "week" (npm), "all time" (crates).
    public let downloadsPeriod: String?
    /// Direct runtime dependencies of the latest version, where cheap.
    public let dependencies: Int?
    /// How many versions have ever been published, where the info call carries it.
    public let versionsCount: Int?

    public init(name: String, registry: Registry, version: String,
                description: String? = nil, license: String? = nil, homepage: String? = nil,
                downloads: Int? = nil, downloadsPeriod: String? = nil,
                dependencies: Int? = nil, versionsCount: Int? = nil) {
        self.name = name
        self.registry = registry
        self.version = version
        self.description = description
        self.license = license
        self.homepage = homepage
        self.downloads = downloads
        self.downloadsPeriod = downloadsPeriod
        self.dependencies = dependencies
        self.versionsCount = versionsCount
    }
}
