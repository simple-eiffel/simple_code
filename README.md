<p align="center">
  <img src="https://raw.githubusercontent.com/simple-eiffel/.github/main/profile/assets/logo.png" alt="simple_ library logo" width="400">
</p>

# simple_code

**[Documentation](https://simple-eiffel.github.io/simple_code/)** | **[GitHub](https://github.com/simple-eiffel/simple_code)**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Eiffel](https://img.shields.io/badge/Eiffel-25.02-blue.svg)](https://www.eiffel.org/)
[![Design by Contract](https://img.shields.io/badge/DbC-enforced-orange.svg)]()
[![Built with simple_codegen](https://img.shields.io/badge/Built_with-simple__codegen-blueviolet.svg)](https://github.com/simple-eiffel/simple_code)

Claude-in-the-loop code generation CLI for Eiffel projects.

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem.

## Status

**Development** - Lock-file controlled pipeline for AI-assisted code generation

## Overview

simple_codegen is a CLI tool that guides Claude (AI) through a strict, lock-file controlled pipeline for generating Eiffel code. Each step requires explicit permission via the lock file, preventing the AI from skipping steps or batching operations.

## Features

- **Lock-File Pipeline** - Every action requires lock file permission
- **Session Management** - Track progress across multiple sessions
- **Spec-Driven Generation** - Generate from JSON specification files
- **TOON Prompts** - AI-readable prompts for consistent code generation
- **Compile Integration** - Run ec.exe and parse error output
- **Test Runner** - Execute tests and track failures individually
- **Reuse Discovery** - Find existing simple_* code for reuse
- **Security Analysis** - Scan generated code for vulnerabilities

## Installation

1. Set the ecosystem environment variable:
```bash
export SIMPLE_EIFFEL=D:\prod
```

2. Build the CLI:
```bash
cd $SIMPLE_EIFFEL/simple_code
/d/prod/ec.sh test -config simple_code.ecf -target simple_codegen
```

3. The executable will be at:
```
EIFGENs/simple_codegen/F_code/simple_code.exe
```

## Quick Start

```bash
# Initialize a new session
simple_codegen init --session my_project

# Generate specification
simple_codegen process --session my_project

# Generate classes (one at a time via lock file)
simple_codegen process --session my_project

# Compile and fix errors (one at a time)
simple_codegen compile --session my_project --project /path/to/project

# Run tests
simple_codegen run-tests --session my_project --project /path/to/project
```

## Lock File States

The lock file controls exactly ONE task at a time:

| Phase | States |
|-------|--------|
| SPEC | `SPEC_GENERATE` |
| CLASS | `CLASS_CONTRACT_i`, `CLASS_IMPL_i` |
| COMPILE | `COMPILE_EIFFEL`, `COMPILE_ERROR_i`, `COMPILE_C` |
| TEST | `TEST_RUN`, `TEST_FAILURE_i` |

## Dependencies

- simple_file
- simple_json
- simple_process
- simple_sql
- simple_eiffel_parser
- simple_vision (for TOON prompts)

## License

MIT License - Copyright (c) 2024-2025, Larry Rix
