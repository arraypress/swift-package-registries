# swift-package-registries

Four package registries — npm, PyPI, crates.io, Homebrew — behind one `PackageInfo`. The keyless ones: these are the registries' own JSON APIs, no tokens, no scraping.

```swift
import PackageRegistries

let registries = Registries()

// One registry's answer.
let info = try await registries.info("serde", in: .crates)
info.version        // "1.0.229"
info.license        // "MIT OR Apache-2.0"
info.downloads      // 1_331_262_583 (all time)

// All four at once — who has this name, and what is it there?
let results = await registries.lookup("left-pad")
```

## The model

`PackageInfo` is the answer normalised: name, registry, latest version, description, license, homepage, downloads, dependency count, versions count. A field a registry does not offer stays `nil` rather than being scraped from somewhere less honest — Homebrew has no download counts in its formula API, so Homebrew's answer has none.

`lookup` asks all four in parallel and returns a result **per registry** — a 404 on PyPI is an answer worth showing ("not on PyPI"), not a failure that should hide npm's hit.

`versions(_:in:)` is the release history, newest first, dated where the registry says: npm's `time` map, PyPI's upload times, crates.io's `created_at`. Homebrew keeps one stable version per formula, so that call honestly returns one.

## The seam

The whole network is one function type:

```swift
public typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
```

Tests inject a transport that answers from recorded fixtures — real captures of left-pad, requests, serde and jq — so the suite runs with zero network. Every request carries a repo-URL `User-Agent`, which crates.io politely requires.

## Registry notes

- **npm** — `info` is the small `/latest` document plus a best-effort weekly download count from the separate downloads API; the full every-version-ever document is only fetched for `versions`. Scoped names (`@types/node`) are encoded correctly.
- **PyPI** — one call carries everything. The license field is the messy one: old packages hold entire license *texts* there, new ones an SPDX expression in `license_expression` — the expression wins when present.
- **crates.io** — crate plus all versions in one response; the license lives on the version, not the crate.
- **Homebrew** — the static `formulae.brew.sh` API the brew client itself reads.

Measured from a warm CLI on top of this library: npm ~75 ms, PyPI ~155 ms, Homebrew ~700 ms, crates.io ~900 ms; all four in parallel bound by the slowest.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/arraypress/swift-package-registries.git", from: "0.1.0")
]
```

## Requirements

- macOS 13+ / iOS 16+
- Swift 6

## License

MIT — see [LICENSE](LICENSE).
