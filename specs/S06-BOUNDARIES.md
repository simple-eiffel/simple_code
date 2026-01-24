# S06: BOUNDARIES - simple_code

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23
**Library:** simple_code

## API Boundaries

### Public Interface

#### SC_COMPILER
- Constructor and configuration methods
- Compilation methods
- Status queries
- Path queries

#### SC_PROJECT
- Factory methods (make_from_*, make_new)
- Identity properties
- Status properties
- Modification methods

#### SC_COMPILE_RESULT
- Error/warning access
- Output access
- Exit code

### Internal Interface (NONE)

- `run_ec_with_args` - Execute compiler
- `run_finish_freezing` - C compilation
- `verify_binary` - Check for exe
- `find_exe_in` - Locate executable
- `reset_state` - Clear state

## Integration Points

| Component | Interface | Direction |
|-----------|-----------|-----------|
| ec.exe | Process exec | Outbound |
| finish_freezing | Process exec | Outbound |
| EIFGENs | File system | Both |
| SQLite | Database | Both |
| Caller code | Public API | Inbound |

## Module Organization

```
simple_code
    |
    +-- Core (SC_*)
    |       Compiler, Project, Results
    |
    +-- CLI (SCG_CLI_*)
    |       Command-line interface
    |
    +-- Generators (SCG_*)
    |       Project scaffolding
    |
    +-- Knowledge Base (scg_kb)
            Code patterns
```
