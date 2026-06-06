# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- **Feature Tracking**: Added this `CHANGELOG.md` file to track features, fixes, and updates.

### Fixed
- **Bot Cloaking**: Fixed an issue where the background wrapper (`run-agent-headless`) combined `--headless=new` with a Linux User-Agent, which caused aggressive blocking on Reddit and Datadome. The stealth UA is now spoofed as a standard Windows machine (`Windows NT 10.0; Win64; x64`), and the `--lang=en-US,en` flag is explicitly injected to pass basic bot heuristics.
