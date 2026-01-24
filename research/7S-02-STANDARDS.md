# 7S-02: STANDARDS - simple_code


**Date**: 2026-01-23

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23
**Library:** simple_code

## Applicable Standards

### EiffelStudio Compiler

#### Command Line Options
- `-batch` - Non-interactive mode
- `-config <file>` - ECF configuration
- `-target <name>` - Build target
- `-freeze` - Workbench build (W_code)
- `-finalize` - Optimized build (F_code)
- `-keep` - Keep assertions in finalized
- `-c_compile` - Run C compilation
- `-clean` - Clean before build

#### Exit Codes
- 0 - Success
- Non-zero - Compilation failure

### ECF Configuration
- XML format for project configuration
- UUID for project identity
- Library and cluster definitions
- Target specifications

### Output Formats
- Error format: `Error code: VXXX`
- Warning format: `Warning code: WXXX`
- Success: "System Recompiled" or "C compilation completed"

## Build Modes

| Mode | Command | Output |
|------|---------|--------|
| check | -batch | Melt only, no C compile |
| test | -finalize -keep -c_compile | F_code with DBC |
| release | -finalize -c_compile then -finalize -keep | Lean then fat |
| freeze | -c_compile | W_code |
| run | -freeze -c_compile + execute | Build and test |
