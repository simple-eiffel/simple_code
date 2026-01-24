# S03: CONTRACTS - simple_code

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23
**Library:** simple_code

## Design by Contract Summary

### SC_COMPILER Contracts

#### make
```eiffel
require
    ecf_not_empty: not a_ecf_path.is_empty
    ecf_is_ecf_file: a_ecf_path.ends_with (".ecf")
    target_not_empty: not a_target.is_empty
ensure
    ecf_set: ecf_path.same_string (a_ecf_path)
    target_set: target.same_string (a_target)
    no_compilation_yet: last_result = Void
    initially_not_compiled: not is_compiled
    no_errors_yet: last_error.is_empty
    exit_code_zero: last_exit_code = 0
```

#### compile_* postconditions
```eiffel
ensure
    result_available: attached last_result
```

#### set_working_directory
```eiffel
ensure
    directory_set: working_directory.same_string (a_path)
    result_is_current: Result = Current
```

### SC_PROJECT Contracts

#### make_from_generator
```eiffel
require
    generator_completed: a_generator.is_generated
ensure
    is_new: is_new
    uuid_set: not uuid.is_empty
    name_set: name.same_string (a_generator.project_name)
```

#### set_id
```eiffel
require
    was_new: is_new
    valid_id: a_id > 0
ensure
    id_set: id = a_id
    now_persisted: is_persisted
```

### Class Invariants

#### SC_COMPILER
```eiffel
invariant
    ecf_path_valid: not ecf_path.is_empty and ecf_path.ends_with (".ecf")
    target_not_empty: not target.is_empty
    result_exit_code_consistent: attached last_result as r implies r.exit_code = last_exit_code
    failure_implies_error: (attached last_result and not is_compiled) implies not last_error.is_empty
    success_implies_no_error: is_compiled implies last_error.is_empty
```

#### SC_PROJECT
```eiffel
invariant
    uuid_not_empty: not uuid.is_empty
    name_not_empty: not name.is_empty
    path_not_empty: not path.is_empty
    id_non_negative: id >= 0
    deleted_implies_timestamp: is_deleted implies attached deleted_at
```
