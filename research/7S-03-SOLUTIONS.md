# 7S-03: SOLUTIONS - simple_code


**Date**: 2026-01-23

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23
**Library:** simple_code

## Existing Solutions Comparison

### 1. EiffelStudio GUI
- **Pros:** Full IDE, visual feedback
- **Cons:** Not automatable, requires UI

### 2. ec.exe command line
- **Pros:** Automatable, standard tool
- **Cons:** No structured output, complex options

### 3. Shell scripts (ec.sh)
- **Pros:** Simple automation
- **Cons:** Limited error handling, no integration

### 4. simple_code (chosen solution)
- **Pros:** Structured API, output parsing, project management
- **Cons:** Additional layer of abstraction

### 5. Makefiles
- **Pros:** Standard build tool
- **Cons:** Not Eiffel-aware, no smart rebuilds

## Why simple_code?

1. **Programmatic API** - Call from Eiffel code
2. **Structured results** - Parsed errors and warnings
3. **Multiple modes** - check, test, release, freeze, run
4. **Project management** - Create, track, verify projects
5. **Integration** - Works with simple_* ecosystem
6. **Fluent API** - Chainable configuration
