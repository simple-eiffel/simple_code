# 7S-04: SIMPLE-STAR - simple_code

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23
**Library:** simple_code

## Ecosystem Integration

### Dependencies on Other simple_* Libraries
- **simple_process** - Execute ec.exe
- **simple_file** - File operations
- **simple_env** - Environment variable access
- **simple_uuid** - Project UUIDs
- **simple_date_time** - Timestamps
- **simple_sql** - Project repository storage
- **simple_files** - Directory listing

### Libraries That May Depend on simple_code
- **simple_ci** - Compilation execution
- **simple_oracle** - Project tracking
- **simple_release** - Release builds

### Integration Patterns

#### Basic Compilation
```eiffel
create compiler.make ("project.ecf", "project_tests")
compiler.compile_test
if compiler.is_compiled then
    print (compiler.exe_path)
end
```

#### With Configuration
```eiffel
create compiler.make ("lib.ecf", "lib_tests")
compiler.set_working_directory ("/path/to/project")
       .set_verbose (True)
       .compile_run

if compiler.tests_passed then
    print ("All tests passed")
end
```

## Namespace Conventions
- Compiler: SC_COMPILER
- Project: SC_PROJECT
- Results: SC_COMPILE_RESULT, SC_COMPILE_ERROR
- Generators: SCG_* prefix
- CLI: SCG_CLI_* prefix
