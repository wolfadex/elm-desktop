# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

None

## [0.3.0] - 2021-05-0?

### Added

- `Desktop.Server.Effect.getEnvVariable : String -> Maybe String`
- `Desktop.Server.Effect.getCwd : String`
- `Desktop.Server.Effect.setCwd : String -> Result String String`
- `Desktop.Server.Effect.getOs : Os` and it's related `Os` type
- `Desktop.Server.Effect.readFile` and related types `File`, `Path`, `Encoding`, `Flag`

## [0.2.0] - 2021-05-03

### Changed

- Dev builds now use Node instead of Deno

## [0.1.0] - 2021-05-02

### Added

- Initial release: can build a basic desktop app
- Can run commands and get back stdout, stderr, and the exit code
