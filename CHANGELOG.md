# Changelog

All notable changes to simple_code will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed (process output)
- Compiler and test output is taken from `last_output_bytes` (simple_process
  1.1.0) instead of `to_string_8` of the decoded text, which failed on any
  character above U+00FF.


### Added
- Project skeleton created
- Comprehensive EiffelStudio Tool Development guide (docs/EIFFELSTUDIO_TOOL_DEVELOPMENT.md)
- Initial project structure following simple_* conventions

## [0.0.1] - 2026-01-14

### Added
- Initial project creation
- Documentation foundation for EiffelStudio IDE integration
