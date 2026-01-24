# S07: SPEC SUMMARY - simple_code

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23
**Library:** simple_code

## Executive Summary

simple_code provides comprehensive Eiffel project management and compilation tools, including a compiler wrapper, project entity management, code generation, and CLI tooling for the simple_* ecosystem.

## Key Design Decisions

### 1. Fluent Configuration
SC_COMPILER uses fluent API for chainable configuration.

### 2. Multiple Build Modes
Supports check, test, release, freeze, and run modes for different use cases.

### 3. Structured Results
Parses compiler output into structured SC_COMPILE_RESULT with errors/warnings.

### 4. Project Persistence
SC_PROJECT entities stored in SQLite via SC_PROJECT_REPOSITORY.

### 5. Soft Delete
Projects use soft delete with timestamps instead of hard delete.

## Class Summary

| Category | Classes | Purpose |
|----------|---------|---------|
| Core | SC_COMPILER, SC_PROJECT, etc. | Compilation and projects |
| CLI | SCG_CLI_APP, SCG_SESSION | Command-line tools |
| Generators | SCG_PROJECT_GEN | Project scaffolding |
| KB | SCG_KB | Code patterns |

## Feature Summary

- **Compilation:** 5 modes + raw access
- **Configuration:** Working dir, verbose, ISE paths
- **Status:** Success/failure, errors, output
- **Paths:** EIFGENs, F_code, W_code, executable
- **Projects:** CRUD, verification, soft delete

## Contract Coverage

- Constructor validates ECF path and target
- Compilation ensures result available
- Fluent methods ensure result is Current
- Invariants maintain consistency
- Project lifecycle tracked via status flags
