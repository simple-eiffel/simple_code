# 7S-06: SIZING - simple_code


**Date**: 2026-01-23

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23
**Library:** simple_code

## Implementation Size Estimate

### Core Classes (Active)
| Class | Lines | Complexity |
|-------|-------|------------|
| SC_COMPILER | 532 | High - Main compiler |
| SC_PROJECT | 351 | Medium - Project entity |
| SC_PROJECT_MANAGER | ~200 | Medium - CRUD operations |
| SC_PROJECT_REPOSITORY | ~250 | Medium - Database |
| SC_COMPILE_RESULT | ~150 | Low - Result data |
| SC_COMPILE_ERROR | ~100 | Low - Error data |
| SC_OUTPUT_PARSER | ~200 | Medium - Parse output |
| SC_CONSTANTS | ~50 | Low - Constants |

### Generator Classes (SCG_*)
| Class | Lines | Purpose |
|-------|-------|---------|
| SCG_PROJECT_GEN | ~400 | Project scaffolding |
| SCG_CLI_APP | ~300 | CLI interface |
| SCG_SESSION | ~200 | Session management |
| Many more... | ~5000+ | Various generators |

### Total Active Code
- Core: ~1,800 lines
- Generators: ~5,000+ lines
- Archived: ~3,000 lines (in _archived folders)

## Effort Assessment

| Phase | Effort |
|-------|--------|
| Core Compiler | COMPLETE |
| Project Management | COMPLETE |
| Generators | COMPLETE |
| CLI | COMPLETE |
| Documentation | IN PROGRESS |

## Complexity Drivers

1. **Multiple compilation modes**
2. **Output parsing**
3. **Project generation**
4. **Database integration**
5. **Session management**
