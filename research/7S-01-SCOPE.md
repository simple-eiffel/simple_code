# 7S-01: SCOPE - simple_code

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23
**Library:** simple_code

## Problem Domain

Eiffel project management and compilation tools. Provides programmatic access to EiffelStudio compiler, project generation, and code management for the simple_* ecosystem.

## Target Users

- Developers building Eiffel projects programmatically
- Automation tools for project scaffolding
- CLI applications for code generation
- Build systems and CI/CD pipelines
- AI-assisted code generation tools

## Boundaries

### In Scope
- EiffelStudio compiler wrapper (ec.exe)
- Compilation modes (check, test, release, freeze, run)
- Output parsing (errors, warnings)
- Project entity management
- Project repository (database storage)
- Project generation scaffolding
- Code validation and verification
- Inline C builder for native code
- Test runner integration
- Security analysis
- Reuse discovery

### Out of Scope
- GUI IDE functionality
- Syntax highlighting
- Code completion
- Debugger integration
- Profiler integration
- Direct source editing

## Dependencies

- EiffelStudio 25.02+ (ec.exe, finish_freezing.exe)
- simple_process (command execution)
- simple_file (file operations)
- simple_env (environment variables)
- simple_uuid (project identifiers)
- simple_date_time (timestamps)
- simple_sql (project repository)
