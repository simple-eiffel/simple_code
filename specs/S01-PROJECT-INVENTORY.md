# S01: PROJECT INVENTORY - simple_code

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23
**Library:** simple_code

## Project Structure

```
simple_code/
    src/
        sc_compiler.e           -- Main compiler wrapper
        sc_project.e            -- Project entity
        sc_project_manager.e    -- Project CRUD
        sc_project_repository.e -- Database storage
        sc_compile_result.e     -- Compilation result
        sc_compile_error.e      -- Error representation
        sc_output_parser.e      -- Parse compiler output
        sc_constants.e          -- Constants
        cli/                    -- CLI tools
            scg_cli_app.e
            scg_session.e
            scg_validator.e
            scg_test_runner.e
            scg_prompt_builder.e
            ... (many more)
        generators/             -- Code generators
            scg_project_gen.e
            scg_toon_prompt.e
            _archived_ai_client/ -- Archived AI code
        kb/                     -- Knowledge base
            scg_kb.e
    testing/
        test_app.e
        lib_tests.e
        test_sc_project.e
        test_scg_project_gen.e
    output/                     -- Generated outputs
    sessions/                   -- Session data
    research/                   -- 7S documents
    specs/                      -- Specification docs
    simple_code.ecf
```

## File Inventory (Core)

| File | Type | Lines | Purpose |
|------|------|-------|---------|
| sc_compiler.e | Source | 532 | Compiler wrapper |
| sc_project.e | Source | 351 | Project entity |
| sc_compile_result.e | Source | ~150 | Result data |
| sc_output_parser.e | Source | ~200 | Output parsing |
| scg_project_gen.e | Source | ~400 | Project generation |
| scg_cli_app.e | Source | ~300 | CLI interface |

## External Dependencies

| Dependency | Type | Purpose |
|------------|------|---------|
| simple_process | Library | Execute ec.exe |
| simple_file | Library | File operations |
| simple_env | Library | Environment vars |
| simple_uuid | Library | Project UUIDs |
| simple_sql | Library | Project storage |
| EiffelStudio | Runtime | ec.exe compiler |
