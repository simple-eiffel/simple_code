# S05: CONSTRAINTS - simple_code

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23
**Library:** simple_code

## Technical Constraints

### 1. EiffelStudio Dependency
- **Constraint:** Requires EiffelStudio installation
- **Impact:** Must be present with valid license
- **Mitigation:** Auto-detect from ISE_EIFFEL

### 2. Windows Platform
- **Constraint:** Uses Windows paths and ec.exe
- **Impact:** Not portable as-is
- **Mitigation:** Could add platform abstraction

### 3. Sequential Compilation
- **Constraint:** One compilation at a time
- **Impact:** Cannot parallelize
- **Mitigation:** Multiple SC_COMPILER instances

### 4. Output Parsing
- **Constraint:** Depends on ec.exe output format
- **Impact:** May break with compiler changes
- **Mitigation:** Flexible pattern matching

### 5. Database Schema
- **Constraint:** SQLite schema for project storage
- **Impact:** Schema changes require migration
- **Mitigation:** Version tracking

## Resource Limits

| Resource | Limit | Notes |
|----------|-------|-------|
| Compilation time | No limit | Depends on project |
| Output size | Memory | Large projects OK |
| Projects | DB limit | SQLite ~281TB |

## Performance Constraints

| Operation | Expected Time |
|-----------|---------------|
| compile_check | Seconds |
| compile_test | Minutes |
| compile_release | Minutes |
| compile_run | Minutes |
