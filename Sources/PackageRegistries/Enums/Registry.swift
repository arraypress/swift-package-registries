//
//  Registry.swift
//  PackageRegistries
//
//  Created by David Sherlock on 2026.
//

/// The four registries this library speaks to — the keyless ones.
public enum Registry: String, CaseIterable, Sendable, Codable {
    /// registry.npmjs.org — JavaScript.
    case npm
    /// pypi.org — Python.
    case pypi
    /// crates.io — Rust.
    case crates
    /// formulae.brew.sh — Homebrew formulae.
    case brew

    /// The name people know it by.
    public var displayName: String {
        switch self {
        case .npm: return "npm"
        case .pypi: return "PyPI"
        case .crates: return "crates.io"
        case .brew: return "Homebrew"
        }
    }

    /// The command that installs `name` from here.
    public func installLine(for name: String) -> String {
        switch self {
        case .npm: return "npm install \(name)"
        case .pypi: return "pip install \(name)"
        case .crates: return "cargo add \(name)"
        case .brew: return "brew install \(name)"
        }
    }
}
