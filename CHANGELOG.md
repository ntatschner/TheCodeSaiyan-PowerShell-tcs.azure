# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- PSScriptAnalyzer settings file for consistent linting
- GitHub Actions CI workflow with lint, Pester, and module validation jobs
- Classes/ directory loading in psm1 (before function dot-sourcing)
- `-Recurse` flag on Public/Private function discovery

### Fixed
- Consistent UpdateWarning boolean comparison (`-eq $true` pattern)
