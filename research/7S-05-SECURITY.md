# 7S-05: SECURITY - simple_code


**Date**: 2026-01-23

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23
**Library:** simple_code

## Security Considerations

### 1. Command Execution
- **Risk:** Executes ec.exe with constructed paths
- **Mitigation:** Paths are quoted, no shell injection
- **Mitigation:** Only executes known compiler

### 2. File System Access
- **Risk:** Writes to EIFGENs directories
- **Mitigation:** Standard compiler behavior
- **Mitigation:** Working directory controlled by caller

### 3. Environment Variables
- **Risk:** Reads ISE_EIFFEL, ISE_PLATFORM
- **Mitigation:** Standard Eiffel environment
- **Mitigation:** Provides sensible defaults

### 4. Project Database
- **Risk:** SQLite database for project storage
- **Mitigation:** Local file, user-controlled location

### 5. Code Generation
- **Risk:** Generates Eiffel source files
- **Mitigation:** Caller controls output location
- **Mitigation:** Generated code is reviewed

## Attack Vectors

| Vector | Likelihood | Impact | Mitigation |
|--------|------------|--------|------------|
| Path injection | Low | Medium | Quoted paths |
| Malicious ECF | Low | Medium | User-provided |
| Env var tampering | Low | Low | Validated |

## Recommendations

1. Validate ECF paths before compilation
2. Use known good EiffelStudio installation
3. Review generated code before use
4. Protect project database file
