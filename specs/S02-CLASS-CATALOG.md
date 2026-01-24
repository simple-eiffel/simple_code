# S02: CLASS CATALOG - simple_code

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23
**Library:** simple_code

## Class Hierarchy

```
SC_COMPILER (main compiler wrapper)
    |
    +-- produces --> SC_COMPILE_RESULT
                         |
                         +-- contains --> SC_COMPILE_ERROR

SC_PROJECT (project entity)
    |
    +-- managed by --> SC_PROJECT_MANAGER
    |
    +-- stored in --> SC_PROJECT_REPOSITORY

SCG_PROJECT_GEN (project generator)
    |
    +-- creates --> SC_PROJECT
```

## Core Class Descriptions

### SC_COMPILER
**Purpose:** EiffelStudio compiler wrapper
**Role:** Execute compilations, parse results
**Key Features:**
- `compile_check` - Melt only
- `compile_test` - Finalize with DBC
- `compile_release` - Production build
- `compile_freeze` - W_code build
- `compile_run` - Build and test
- `is_compiled`, `tests_passed` - Status
- `last_output`, `last_error` - Results
- Fluent configuration API

### SC_PROJECT
**Purpose:** Project entity for persistence
**Role:** Hold project metadata
**Key Features:**
- `uuid`, `name`, `path` - Identity
- `libraries` - Dependencies
- `is_generated`, `is_verified` - Status
- `created_at`, `updated_at` - Timestamps
- `is_deleted` - Soft delete

### SC_COMPILE_RESULT
**Purpose:** Structured compilation result
**Role:** Parse and hold compiler output
**Key Features:**
- Error list
- Warning list
- Exit code
- Raw output

### SC_OUTPUT_PARSER
**Purpose:** Parse compiler output
**Role:** Extract errors/warnings from text
**Key Features:**
- `parse` - Parse output string
- Error pattern matching
- Warning detection

### SCG_PROJECT_GEN
**Purpose:** Generate new Eiffel projects
**Role:** Scaffold project structure
**Key Features:**
- ECF generation
- Source file creation
- Test setup
- Verification compilation
