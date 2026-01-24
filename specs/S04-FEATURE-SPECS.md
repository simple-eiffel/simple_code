# S04: FEATURE SPECS - simple_code

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23
**Library:** simple_code

## Feature Specifications

### SC_COMPILER - Compilation

| Feature | Signature | Description |
|---------|-----------|-------------|
| compile_check | | Melt only, quick check |
| compile_test | | Finalize with DBC |
| compile_release | | Lean then fat build |
| compile_freeze | | W_code build |
| compile_run | | Build and execute |
| compile_raw | (args: STRING) | Raw ec.exe call |

### SC_COMPILER - Configuration

| Feature | Signature | Description |
|---------|-----------|-------------|
| set_working_directory | (path: STRING): like Current | Set work dir |
| set_verbose | (v: BOOLEAN): like Current | Toggle verbose |
| set_ise_eiffel | (path: STRING): like Current | Set ISE path |
| set_ise_platform | (plat: STRING): like Current | Set platform |

### SC_COMPILER - Status

| Feature | Signature | Description |
|---------|-----------|-------------|
| is_compiled | : BOOLEAN | Compilation succeeded? |
| is_verbose | : BOOLEAN | Verbose mode? |
| tests_passed | : BOOLEAN | Tests passed? |
| last_output | : STRING | Full output |
| last_error | : STRING | Error message |
| last_exit_code | : INTEGER | Exit code |
| last_result | : detachable SC_COMPILE_RESULT | Parsed result |

### SC_COMPILER - Paths

| Feature | Signature | Description |
|---------|-----------|-------------|
| eifgens_path | : STRING | EIFGENs directory |
| f_code_path | : STRING | F_code path |
| w_code_path | : STRING | W_code path |
| exe_path | : STRING | Built executable |
| ec_exe_path | : STRING | Compiler path |

### SC_PROJECT - Identity

| Feature | Signature | Description |
|---------|-----------|-------------|
| id | : INTEGER_64 | Database ID |
| uuid | : STRING | Project UUID |
| name | : STRING | Project name |
| path | : STRING | Project path |

### SC_PROJECT - Status

| Feature | Signature | Description |
|---------|-----------|-------------|
| is_generated | : BOOLEAN | Generated? |
| is_verified | : BOOLEAN | Verified? |
| is_new | : BOOLEAN | Not yet saved? |
| is_persisted | : BOOLEAN | Saved? |
| is_deleted | : BOOLEAN | Soft deleted? |

### SC_PROJECT - Modification

| Feature | Signature | Description |
|---------|-----------|-------------|
| set_id | (id: INTEGER_64) | Set DB ID |
| set_generated | (v: BOOLEAN) | Set generated |
| set_verified | (v: BOOLEAN; err: STRING) | Set verified |
| mark_deleted | | Soft delete |
| touch | | Update timestamp |
