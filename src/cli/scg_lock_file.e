note
	description: "[
		Comprehensive lock file state machine for simple_codegen workflow enforcement.

		Implements the 10-phase, ~70-state pipeline:
		Phase 1: PREP (Preparation) - research, reuse, deps, scope
		Phase 2: PLAN (Planning) - arch, classes, features, contracts
		Phase 3: SPEC (Specification) - generate system_spec.json
		Phase 4: CLASS (Per-Class Generation) - contract + impl per class
		Phase 5: ASSEMBLE (Project Assembly) - structure + ECF
		Phase 6: COMPILE (Compilation) - Eiffel + C, with per-error fixing
		Phase 7: TEST (Testing) - generate, compile, run, per-failure fixing
		Phase 8: DOCS (Documentation) - README, index.html, examples
		Phase 9: GIT (Version Control) - init, ignore, add, commit
		Phase 10: GITHUB (GitHub Integration) - create, push, pages, release

		KEY RULES:
		- ONE TASK PER STATE: Lock file says exactly ONE thing to do
		- NO BATCHING: Fix error 1, then error 2 - never all at once
		- MANDATORY COMMAND: Must call simple_codegen to advance

		Lock file location: sessions/<session>/.scg_lock
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_LOCK_FILE

create
	make,
	make_from_file

feature {NONE} -- Initialization

	make (a_session_path: STRING_32)
			-- Create new lock file for session at `a_session_path'.
		require
			path_not_empty: not a_session_path.is_empty
		do
			session_path := a_session_path
			create phase_manager.make
			create state.make_from_string (phase_manager.State_idle)
			create phase.make_from_string ("IDLE")
			phase_index := 0
			create last_command.make_empty
			create last_command_time.make_empty
			create expected_next.make_empty
			create pending_class.make_empty
			create warning.make_empty
			classes_remaining := 0
			classes_total := 0
			error_index := 0
			errors_total := 0
			test_failure_index := 0
			test_failures_total := 0
			retry_count := 0
			create skip_phases.make (0)
			create compile_errors.make (0)
			create test_failures.make (0)
		ensure
			session_path_set: session_path = a_session_path
			state_is_idle: state.same_string (phase_manager.State_idle)
		end

	make_from_file (a_session_path: STRING_32)
			-- Load existing lock file from session at `a_session_path'.
		require
			path_not_empty: not a_session_path.is_empty
		do
			session_path := a_session_path
			create phase_manager.make
			create state.make_from_string (phase_manager.State_idle)
			create phase.make_from_string ("IDLE")
			phase_index := 0
			create last_command.make_empty
			create last_command_time.make_empty
			create expected_next.make_empty
			create pending_class.make_empty
			create warning.make_empty
			classes_remaining := 0
			classes_total := 0
			error_index := 0
			errors_total := 0
			test_failure_index := 0
			test_failures_total := 0
			retry_count := 0
			create skip_phases.make (0)
			create compile_errors.make (0)
			create test_failures.make (0)
			load
		ensure
			session_path_set: session_path = a_session_path
		end

feature -- Access

	session_path: STRING_32
			-- Path to session directory

	state: STRING_32
			-- Current workflow state

	phase: STRING_32
			-- Current phase name (PREP, PLAN, SPEC, CLASS, etc.)

	phase_index: INTEGER
			-- Current phase number (1-10)

	last_command: STRING_32
			-- Last simple_codegen command executed

	last_command_time: STRING_32
			-- Timestamp of last command

	expected_next: STRING_32
			-- Expected next command/action

	pending_class: STRING_32
			-- Name of class waiting to be generated (if any)

	classes_remaining: INTEGER
			-- Number of classes still to generate

	classes_total: INTEGER
			-- Total number of classes

	error_index: INTEGER
			-- Current error being fixed (1-based)

	errors_total: INTEGER
			-- Total number of compile errors

	test_failure_index: INTEGER
			-- Current test failure being fixed (1-based)

	test_failures_total: INTEGER
			-- Total number of test failures

	warning: STRING_32
			-- Warning message for Claude

	retry_count: INTEGER
			-- Number of retries on current step

	skip_phases: ARRAYED_LIST [INTEGER]
			-- Phases to skip

	compile_errors: ARRAYED_LIST [SCG_COMPILE_ERROR]
			-- List of compile errors to fix

	test_failures: ARRAYED_LIST [SCG_TEST_FAILURE]
			-- List of test failures to fix

	phase_manager: SCG_PHASE_MANAGER
			-- Phase transition logic

	current_error: detachable SCG_COMPILE_ERROR
			-- Current compile error to fix (if in error state).
		do
			if error_index >= 1 and error_index <= compile_errors.count then
				Result := compile_errors.i_th (error_index)
			end
		end

	current_failure: detachable SCG_TEST_FAILURE
			-- Current test failure to fix (if in failure state).
		do
			if test_failure_index >= 1 and test_failure_index <= test_failures.count then
				Result := test_failures.i_th (test_failure_index)
			end
		end

feature -- Status Report

	lock_file_path: STRING_32
			-- Full path to lock file
		do
			Result := session_path + "/.scg_lock"
		end

	exists: BOOLEAN
			-- Does the lock file exist?
		local
			l_file: SIMPLE_FILE
		do
			create l_file.make (lock_file_path.to_string_8)
			Result := l_file.exists
		end

	is_complete: BOOLEAN
			-- Is the pipeline complete?
		do
			Result := state.same_string (phase_manager.State_complete)
		end

	is_idle: BOOLEAN
			-- Is the pipeline idle (not started)?
		do
			Result := state.same_string (phase_manager.State_idle)
		end

	is_in_prep_phase: BOOLEAN
			-- Are we in the PREP phase?
		do
			Result := phase_index = phase_manager.Phase_prep
		end

	is_in_plan_phase: BOOLEAN
			-- Are we in the PLAN phase?
		do
			Result := phase_index = phase_manager.Phase_plan
		end

	is_in_spec_phase: BOOLEAN
			-- Are we in the SPEC phase?
		do
			Result := phase_index = phase_manager.Phase_spec
		end

	is_in_class_phase: BOOLEAN
			-- Are we in the CLASS phase?
		do
			Result := phase_index = phase_manager.Phase_class
		end

	is_in_assemble_phase: BOOLEAN
			-- Are we in the ASSEMBLE phase?
		do
			Result := phase_index = phase_manager.Phase_assemble
		end

	is_in_compile_phase: BOOLEAN
			-- Are we in the COMPILE phase?
		do
			Result := phase_index = phase_manager.Phase_compile
		end

	is_in_test_phase: BOOLEAN
			-- Are we in the TEST phase?
		do
			Result := phase_index = phase_manager.Phase_test
		end

	is_in_docs_phase: BOOLEAN
			-- Are we in the DOCS phase?
		do
			Result := phase_index = phase_manager.Phase_docs
		end

	is_in_git_phase: BOOLEAN
			-- Are we in the GIT phase?
		do
			Result := phase_index = phase_manager.Phase_git
		end

	is_in_github_phase: BOOLEAN
			-- Are we in the GITHUB phase?
		do
			Result := phase_index = phase_manager.Phase_github
		end

	is_awaiting_response: BOOLEAN
			-- Is the workflow waiting for a response to be processed?
		do
			Result := state.same_string (phase_manager.State_spec_generate) or
			          state.starts_with (phase_manager.State_class_contract_prefix) or
			          state.starts_with (phase_manager.State_class_impl_prefix)
		end

	can_generate_class (a_class_name: STRING_32): BOOLEAN
			-- Can Claude generate the specified class?
		do
			Result := is_in_class_phase and pending_class.same_string (a_class_name)
		end

	can_assemble: BOOLEAN
			-- Can the project be assembled?
		do
			Result := is_in_assemble_phase
		end

feature -- Phase Skip Configuration

	set_skip_prep
			-- Mark PREP phase to be skipped.
		do
			phase_manager.skip_prep
			if not skip_phases.has (phase_manager.Phase_prep) then
				skip_phases.extend (phase_manager.Phase_prep)
			end
		end

	set_skip_plan
			-- Mark PLAN phase to be skipped.
		do
			phase_manager.skip_plan
			if not skip_phases.has (phase_manager.Phase_plan) then
				skip_phases.extend (phase_manager.Phase_plan)
			end
		end

	set_skip_docs
			-- Mark DOCS phase to be skipped.
		do
			phase_manager.skip_docs
			if not skip_phases.has (phase_manager.Phase_docs) then
				skip_phases.extend (phase_manager.Phase_docs)
			end
		end

	set_skip_git
			-- Mark GIT phase to be skipped.
		do
			phase_manager.skip_git
			if not skip_phases.has (phase_manager.Phase_git) then
				skip_phases.extend (phase_manager.Phase_git)
			end
		end

	set_skip_github
			-- Mark GITHUB phase to be skipped.
		do
			phase_manager.skip_github
			if not skip_phases.has (phase_manager.Phase_github) then
				skip_phases.extend (phase_manager.Phase_github)
			end
		end

feature -- State Transitions - Initialization

	transition_to_initial
			-- Transition to initial state based on skip configuration.
		do
			state := phase_manager.initial_state.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "init"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

feature -- State Transitions - PREP Phase

	transition_prep_research_done
			-- Transition after research is complete.
		require
			in_correct_state: state.same_string (phase_manager.State_prep_research)
		do
			state := phase_manager.next_prep_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "prep --research-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

	transition_prep_reuse_done
			-- Transition after reuse analysis is complete.
		require
			in_correct_state: state.same_string (phase_manager.State_prep_reuse)
		do
			state := phase_manager.next_prep_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "prep --reuse-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

	transition_prep_deps_done
			-- Transition after dependency identification is complete.
		require
			in_correct_state: state.same_string (phase_manager.State_prep_deps)
		do
			state := phase_manager.next_prep_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "prep --deps-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

	transition_prep_scope_done
			-- Transition after scope definition is complete.
		require
			in_correct_state: state.same_string (phase_manager.State_prep_scope)
		do
			state := phase_manager.next_prep_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "prep --scope-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

feature -- State Transitions - PLAN Phase

	transition_plan_arch_done
			-- Transition after architecture design is complete.
		require
			in_correct_state: state.same_string (phase_manager.State_plan_arch)
		do
			state := phase_manager.next_plan_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "plan --arch-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

	transition_plan_classes_done
			-- Transition after class list is defined.
		require
			in_correct_state: state.same_string (phase_manager.State_plan_classes)
		do
			state := phase_manager.next_plan_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "plan --classes-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

	transition_plan_features_done
			-- Transition after feature signatures are designed.
		require
			in_correct_state: state.same_string (phase_manager.State_plan_features)
		do
			state := phase_manager.next_plan_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "plan --features-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

	transition_plan_contracts_done
			-- Transition after contract strategy is planned.
		require
			in_correct_state: state.same_string (phase_manager.State_plan_contracts)
		do
			state := phase_manager.next_plan_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "plan --contracts-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

feature -- State Transitions - SPEC Phase

	transition_to_spec
			-- Transition to awaiting spec response (after spec command).
		do
			state := phase_manager.State_spec_generate.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "spec"
			last_command_time := current_timestamp
			expected_next := {STRING_32} "process --input <your_system_spec.json> --session <name>"
			pending_class.wipe_out
			warning := {STRING_32} "Generate system_spec.json ONLY. Then call: simple_codegen process --input response.txt --session <name>"
			save
		end

feature -- State Transitions - CLASS Phase

	transition_to_class_contract (a_class_name: STRING_32; a_class_index, a_total: INTEGER)
			-- Transition to awaiting contract for class at index `a_class_index'.
		require
			class_name_not_empty: not a_class_name.is_empty
			index_valid: a_class_index >= 1 and a_class_index <= a_total
		do
			state := phase_manager.class_contract_state (a_class_index).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "process"
			last_command_time := current_timestamp
			pending_class := a_class_name.twin
			classes_remaining := a_total - a_class_index + 1
			classes_total := a_total
			expected_next := {STRING_32} "process --input <" + a_class_name + "_contracts.e> --session <name>"
			warning := {STRING_32} "Write CONTRACTS ONLY for " + a_class_name + " (require/ensure/invariant). NO implementation. Then call: simple_codegen process --input response.txt --session <name>"
			save
		end

	transition_to_class_impl (a_class_name: STRING_32; a_class_index, a_total: INTEGER)
			-- Transition to awaiting implementation for class at index `a_class_index'.
		require
			class_name_not_empty: not a_class_name.is_empty
			index_valid: a_class_index >= 1 and a_class_index <= a_total
		do
			state := phase_manager.class_impl_state (a_class_index).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "process"
			last_command_time := current_timestamp
			pending_class := a_class_name.twin
			classes_remaining := a_total - a_class_index + 1
			classes_total := a_total
			expected_next := {STRING_32} "process --input <" + a_class_name + ".e> --session <name>"
			warning := {STRING_32} "Write IMPLEMENTATION for " + a_class_name + " with the contracts you defined. Then call: simple_codegen process --input response.txt --session <name>"
			save
		end

	transition_to_next_class_or_assemble (a_has_more_classes: BOOLEAN; a_next_class: detachable STRING_32; a_class_index, a_total: INTEGER)
			-- Transition to next class contract or assembly phase.
		do
			if a_has_more_classes and attached a_next_class as nc then
				transition_to_class_contract (nc, a_class_index, a_total)
			else
				-- All classes done, move to ASSEMBLE
				transition_to_assemble_structure
			end
		end

feature -- State Transitions - ASSEMBLE Phase

	transition_to_assemble_structure
			-- Transition to assembly structure creation.
		do
			state := phase_manager.State_assemble_structure.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "process"
			last_command_time := current_timestamp
			pending_class.wipe_out
			classes_remaining := 0
			expected_next := {STRING_32} "assemble --session <name> --output <path>"
			warning := {STRING_32} "All classes generated. Call: simple_codegen assemble --session <name> --output <path>"
			save
		end

	transition_to_assemble_ecf
			-- Transition to ECF configuration.
		require
			in_correct_state: state.same_string (phase_manager.State_assemble_structure)
		do
			state := phase_manager.State_assemble_ecf.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "assemble"
			last_command_time := current_timestamp
			expected_next := {STRING_32} "assemble --ecf-done --session <name>"
			warning := {STRING_32} "Directory structure created. Configure ECF with dependencies. Then call: simple_codegen assemble --ecf-done --session <name>"
			save
		end

feature -- State Transitions - COMPILE Phase

	transition_to_compile_eiffel
			-- Transition to Eiffel compilation.
		do
			state := phase_manager.State_compile_eiffel.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "assemble --ecf-done"
			last_command_time := current_timestamp
			error_index := 0
			errors_total := 0
			compile_errors.wipe_out
			expected_next := {STRING_32} "compile --session <name> --project <path>"
			warning := {STRING_32} "Assembly complete. Compile the project: simple_codegen compile --session <name> --project <path>"
			save
		end

	transition_to_compile_error (a_errors: ARRAYED_LIST [SCG_COMPILE_ERROR])
			-- Transition to fixing first compile error.
		require
			has_errors: not a_errors.is_empty
		do
			compile_errors := a_errors
			errors_total := a_errors.count
			error_index := 1
			state := phase_manager.compile_error_state (1).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "compile"
			last_command_time := current_timestamp
			if attached current_error as ce then
				expected_next := {STRING_32} "compile --fix --session <name>"
				warning := {STRING_32} "Fix ERROR 1 of " + errors_total.out + ": " + ce.to_display_string + ". Do NOT fix any other errors. Then call: simple_codegen compile --fix --session <name>"
			end
			save
		end

	transition_to_next_error_or_c_compile
			-- Transition to next error or C compilation.
		do
			if error_index < errors_total then
				error_index := error_index + 1
				state := phase_manager.compile_error_state (error_index).to_string_32
				update_phase_from_state
				last_command := {STRING_32} "compile --fix"
				last_command_time := current_timestamp
				if attached current_error as ce then
					expected_next := {STRING_32} "compile --fix --session <name>"
					warning := {STRING_32} "Fix ERROR " + error_index.out + " of " + errors_total.out + ": " + ce.to_display_string + ". Do NOT fix any other errors. Then call: simple_codegen compile --fix --session <name>"
				end
				save
			else
				-- All Eiffel errors fixed, try C compile
				transition_to_compile_c
			end
		end

	transition_to_compile_c
			-- Transition to C compilation.
		do
			state := phase_manager.State_compile_c.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "compile --fix"
			last_command_time := current_timestamp
			error_index := 0
			errors_total := 0
			compile_errors.wipe_out
			expected_next := {STRING_32} "compile --c-compile --session <name>"
			warning := {STRING_32} "Eiffel compilation successful. Run C backend: simple_codegen compile --c-compile --session <name>"
			save
		end

	transition_to_c_compile_error (a_errors: ARRAYED_LIST [SCG_COMPILE_ERROR])
			-- Transition to fixing first C compile error.
		require
			has_errors: not a_errors.is_empty
		do
			compile_errors := a_errors
			errors_total := a_errors.count
			error_index := 1
			state := phase_manager.compile_c_error_state (1).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "compile --c-compile"
			last_command_time := current_timestamp
			if attached current_error as ce then
				expected_next := {STRING_32} "compile --fix --session <name>"
				warning := {STRING_32} "Fix C ERROR 1 of " + errors_total.out + ": " + ce.to_display_string + ". Do NOT fix any other errors. Then call: simple_codegen compile --fix --session <name>"
			end
			save
		end

	transition_to_next_c_error_or_success
			-- Transition to next C error or compilation success.
		do
			if error_index < errors_total then
				error_index := error_index + 1
				state := phase_manager.compile_c_error_state (error_index).to_string_32
				update_phase_from_state
				last_command := {STRING_32} "compile --fix"
				last_command_time := current_timestamp
				if attached current_error as ce then
					expected_next := {STRING_32} "compile --fix --session <name>"
					warning := {STRING_32} "Fix C ERROR " + error_index.out + " of " + errors_total.out + ": " + ce.to_display_string + ". Do NOT fix any other errors. Then call: simple_codegen compile --fix --session <name>"
				end
				save
			else
				transition_to_compile_success
			end
		end

	transition_to_compile_success
			-- Transition to compilation success.
		do
			state := phase_manager.State_compile_success.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "compile --done"
			last_command_time := current_timestamp
			error_index := 0
			errors_total := 0
			compile_errors.wipe_out
			expected_next := {STRING_32} "run-tests --session <name> --project <path>"
			warning := {STRING_32} "Compilation successful. Run tests: simple_codegen run-tests --session <name> --project <path>"
			save
		end

feature -- State Transitions - TEST Phase

	transition_to_test_generate
			-- Transition to test generation.
		do
			state := phase_manager.State_test_generate.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "compile --done"
			last_command_time := current_timestamp
			test_failure_index := 0
			test_failures_total := 0
			test_failures.wipe_out
			expected_next := {STRING_32} "generate-tests --session <name> --class <CLASS>"
			warning := {STRING_32} "Generate test class. Call: simple_codegen generate-tests --session <name> --class <CLASS>"
			save
		end

	transition_to_test_compile
			-- Transition to test compilation.
		do
			state := phase_manager.State_test_compile.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "generate-tests"
			last_command_time := current_timestamp
			expected_next := {STRING_32} "run-tests --compile --session <name>"
			warning := {STRING_32} "Test class generated. Compile tests: simple_codegen run-tests --compile --session <name>"
			save
		end

	transition_to_test_run
			-- Transition to test execution.
		do
			state := phase_manager.State_test_run.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "run-tests --compile"
			last_command_time := current_timestamp
			expected_next := {STRING_32} "run-tests --session <name> --project <path>"
			warning := {STRING_32} "Tests compiled. Run tests: simple_codegen run-tests --session <name> --project <path>"
			save
		end

	transition_to_test_failure (a_failures: ARRAYED_LIST [SCG_TEST_FAILURE])
			-- Transition to fixing first test failure.
		require
			has_failures: not a_failures.is_empty
		do
			test_failures := a_failures
			test_failures_total := a_failures.count
			test_failure_index := 1
			state := phase_manager.test_failure_state (1).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "run-tests"
			last_command_time := current_timestamp
			if attached current_failure as cf then
				expected_next := {STRING_32} "run-tests --fix --session <name>"
				warning := {STRING_32} "Fix FAILURE 1 of " + test_failures_total.out + ": " + cf.to_display_string + ". Do NOT fix any other failures. Then call: simple_codegen run-tests --fix --session <name>"
			end
			save
		end

	transition_to_next_failure_or_rerun
			-- Transition to next failure or test rerun.
		do
			if test_failure_index < test_failures_total then
				test_failure_index := test_failure_index + 1
				state := phase_manager.test_failure_state (test_failure_index).to_string_32
				update_phase_from_state
				last_command := {STRING_32} "run-tests --fix"
				last_command_time := current_timestamp
				if attached current_failure as cf then
					expected_next := {STRING_32} "run-tests --fix --session <name>"
					warning := {STRING_32} "Fix FAILURE " + test_failure_index.out + " of " + test_failures_total.out + ": " + cf.to_display_string + ". Do NOT fix any other failures. Then call: simple_codegen run-tests --fix --session <name>"
				end
				save
			else
				transition_to_test_rerun
			end
		end

	transition_to_test_rerun
			-- Transition to test rerun.
		do
			state := phase_manager.State_test_rerun.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "run-tests --fix"
			last_command_time := current_timestamp
			test_failure_index := 0
			test_failures_total := 0
			test_failures.wipe_out
			expected_next := {STRING_32} "run-tests --rerun --session <name>"
			warning := {STRING_32} "All failures fixed. Re-run tests: simple_codegen run-tests --rerun --session <name>"
			save
		end

	transition_to_test_success
			-- Transition to test success.
		do
			state := phase_manager.State_test_success.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "run-tests --done"
			last_command_time := current_timestamp
			test_failure_index := 0
			test_failures_total := 0
			test_failures.wipe_out
			-- Move to next phase based on skip config
			expected_next := phase_manager.state_after_test_success
			update_expected_and_warning
			save
		end

feature -- State Transitions - DOCS Phase

	transition_to_docs_readme
			-- Transition to README writing.
		do
			state := phase_manager.State_docs_readme.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "run-tests --done"
			last_command_time := current_timestamp
			expected_next := {STRING_32} "docs --readme-done --session <name>"
			warning := {STRING_32} "Tests pass. Write README.md. Then call: simple_codegen docs --readme-done --session <name>"
			save
		end

	transition_docs_readme_done
			-- Transition after README is written.
		require
			in_correct_state: state.same_string (phase_manager.State_docs_readme)
		do
			state := phase_manager.next_docs_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "docs --readme-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

	transition_docs_index_done
			-- Transition after index.html is written.
		require
			in_correct_state: state.same_string (phase_manager.State_docs_index)
		do
			state := phase_manager.next_docs_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "docs --index-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

	transition_docs_examples_done
			-- Transition after examples are added.
		require
			in_correct_state: state.same_string (phase_manager.State_docs_examples)
		do
			state := phase_manager.next_docs_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "docs --examples-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

feature -- State Transitions - GIT Phase

	transition_to_git_init
			-- Transition to git init.
		do
			state := phase_manager.State_git_init.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "docs --examples-done"
			last_command_time := current_timestamp
			expected_next := {STRING_32} "git --init-done --session <name> --project <path>"
			warning := {STRING_32} "Documentation complete. Initialize git repository. Then call: simple_codegen git --init-done --session <name> --project <path>"
			save
		end

	transition_git_init_done
			-- Transition after git init is done.
		require
			in_correct_state: state.same_string (phase_manager.State_git_init)
		do
			state := phase_manager.next_git_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "git --init-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

	transition_git_ignore_done
			-- Transition after .gitignore is created.
		require
			in_correct_state: state.same_string (phase_manager.State_git_ignore)
		do
			state := phase_manager.next_git_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "git --ignore-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

	transition_git_add_done
			-- Transition after files are staged.
		require
			in_correct_state: state.same_string (phase_manager.State_git_add)
		do
			state := phase_manager.next_git_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "git --add-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

	transition_git_commit_done
			-- Transition after initial commit is made.
		require
			in_correct_state: state.same_string (phase_manager.State_git_commit)
		do
			state := phase_manager.next_git_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "git --commit-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

feature -- State Transitions - GITHUB Phase

	transition_to_github_create
			-- Transition to GitHub repo creation.
		do
			state := phase_manager.State_github_create.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "git --commit-done"
			last_command_time := current_timestamp
			expected_next := {STRING_32} "github --create-done --session <name>"
			warning := {STRING_32} "Git initialized. Create GitHub repository. Then call: simple_codegen github --create-done --session <name>"
			save
		end

	transition_github_create_done
			-- Transition after GitHub repo is created.
		require
			in_correct_state: state.same_string (phase_manager.State_github_create)
		do
			state := phase_manager.next_github_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "github --create-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

	transition_github_push_done
			-- Transition after push to remote.
		require
			in_correct_state: state.same_string (phase_manager.State_github_push)
		do
			state := phase_manager.next_github_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "github --push-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

	transition_github_pages_done
			-- Transition after GitHub Pages is enabled.
		require
			in_correct_state: state.same_string (phase_manager.State_github_pages)
		do
			state := phase_manager.next_github_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "github --pages-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

	transition_github_release_done
			-- Transition after release is created.
		require
			in_correct_state: state.same_string (phase_manager.State_github_release)
		do
			state := phase_manager.next_github_state (state.to_string_8).to_string_32
			update_phase_from_state
			last_command := {STRING_32} "github --release-done"
			last_command_time := current_timestamp
			update_expected_and_warning
			save
		end

feature -- State Transitions - Terminal

	transition_to_complete
			-- Transition to complete (pipeline finished).
		do
			state := phase_manager.State_complete.to_string_32
			phase := {STRING_32} "COMPLETE"
			phase_index := 11
			last_command := {STRING_32} "complete"
			last_command_time := current_timestamp
			expected_next := {STRING_32} "(workflow complete)"
			pending_class.wipe_out
			classes_remaining := 0
			warning := {STRING_32} "Workflow complete. Project is ready for use."
			save
		end

feature -- Admin Operations

	force_state (a_state: STRING)
			-- Admin override: force lock file to specific state.
		require
			state_not_empty: not a_state.is_empty
		do
			state := a_state.to_string_32
			update_phase_from_state
			last_command := {STRING_32} "lock --skip-to " + a_state
			last_command_time := current_timestamp
			update_expected_and_warning
			retry_count := 0
			save
		end

	retry_current
			-- Increment retry count and re-save.
		do
			retry_count := retry_count + 1
			save
		end

	reset
			-- Reset lock file to initial state.
		do
			state := phase_manager.State_idle.to_string_32
			phase := {STRING_32} "IDLE"
			phase_index := 0
			last_command.wipe_out
			last_command_time.wipe_out
			expected_next.wipe_out
			pending_class.wipe_out
			warning.wipe_out
			classes_remaining := 0
			classes_total := 0
			error_index := 0
			errors_total := 0
			test_failure_index := 0
			test_failures_total := 0
			retry_count := 0
			compile_errors.wipe_out
			test_failures.wipe_out
			save
		end

feature -- Error Recovery

	transition_to_error (a_error_message: STRING)
			-- Transition to error recovery state after tool crash or unexpected error.
			-- This prevents Claude from continuing when something went wrong.
		require
			message_not_empty: not a_error_message.is_empty
		do
			state := phase_manager.State_error_recovery.to_string_32
			phase := {STRING_32} "ERROR"
			phase_index := 0
			last_command_time := current_timestamp
			expected_next := {STRING_32} "simple_codegen lock --retry --session <name>"
			warning := {STRING_32} "TOOL ERROR: " + a_error_message.to_string_32 +
				". STOP and investigate. Do NOT continue. " +
				"Fix the issue, then: simple_codegen lock --retry --session <name>"
			save
		ensure
			in_error_state: state.same_string (phase_manager.State_error_recovery)
		end

	is_in_error_recovery: BOOLEAN
			-- Is the workflow in error recovery state?
		do
			Result := state.same_string (phase_manager.State_error_recovery)
		end

	recover_from_error
			-- Transition out of error recovery back to previous state.
			-- Called after error has been investigated and fixed.
		require
			in_error_state: is_in_error_recovery
		do
			-- Reload from disk to get previous state
			load
			-- If still in error recovery, reset to initial
			if is_in_error_recovery then
				transition_to_initial
			end
		end

feature -- Output

	to_display_string: STRING_32
			-- Formatted string for display to Claude
		do
			create Result.make (1000)
			Result.append ({STRING_32} "=== SIMPLE_CODEGEN LOCK FILE ===%N")
			Result.append ({STRING_32} "Phase: " + phase + " (" + phase_index.out + "/10)%N")
			Result.append ({STRING_32} "State: " + state + "%N")
			Result.append ({STRING_32} "Last command: " + last_command + "%N")
			Result.append ({STRING_32} "Time: " + last_command_time + "%N")
			if not pending_class.is_empty then
				Result.append ({STRING_32} "Pending class: " + pending_class + "%N")
			end
			if classes_total > 0 then
				Result.append ({STRING_32} "Classes: " + (classes_total - classes_remaining + 1).out + "/" + classes_total.out + "%N")
			end
			if errors_total > 0 then
				Result.append ({STRING_32} "Error: " + error_index.out + "/" + errors_total.out + "%N")
			end
			if test_failures_total > 0 then
				Result.append ({STRING_32} "Failure: " + test_failure_index.out + "/" + test_failures_total.out + "%N")
			end
			if retry_count > 0 then
				Result.append ({STRING_32} "Retries: " + retry_count.out + "%N")
			end
			Result.append ({STRING_32} "Expected next: " + expected_next + "%N")
			Result.append ({STRING_32} "%N*** WARNING ***%N")
			Result.append (warning)
			Result.append ({STRING_32} "%N================================%N")
		end

feature -- Persistence

	save
			-- Save lock file to disk.
		local
			l_json: SIMPLE_JSON_OBJECT
			l_arr: SIMPLE_JSON_ARRAY
			l_file: SIMPLE_FILE
			i: INTEGER
		do
			create l_json.make
			l_json.put_string (state, "state").do_nothing
			l_json.put_string (phase, "phase").do_nothing
			l_json.put_integer (phase_index, "phase_index").do_nothing
			l_json.put_string (last_command, "last_command").do_nothing
			l_json.put_string (last_command_time, "last_command_time").do_nothing
			l_json.put_string (expected_next, "expected_next").do_nothing
			l_json.put_string (pending_class, "pending_class").do_nothing
			l_json.put_integer (classes_remaining, "classes_remaining").do_nothing
			l_json.put_integer (classes_total, "classes_total").do_nothing
			l_json.put_integer (error_index, "error_index").do_nothing
			l_json.put_integer (errors_total, "errors_total").do_nothing
			l_json.put_integer (test_failure_index, "test_failure_index").do_nothing
			l_json.put_integer (test_failures_total, "test_failures_total").do_nothing
			l_json.put_string (warning, "warning").do_nothing
			l_json.put_integer (retry_count, "retry_count").do_nothing

			-- Save skip_phases array
			create l_arr.make
			from i := 1 until i > skip_phases.count loop
				l_arr.add_integer (skip_phases.i_th (i)).do_nothing
				i := i + 1
			end
			l_json.put_array (l_arr, "skip_phases").do_nothing

			-- Save current error if any
			if attached current_error as ce then
				l_json.put_object (ce.to_json, "current_error").do_nothing
			end

			-- Save current failure if any
			if attached current_failure as cf then
				l_json.put_object (cf.to_json, "current_failure").do_nothing
			end

			create l_file.make (lock_file_path.to_string_8)
			l_file.write_text (l_json.to_json_string.to_string_8).do_nothing
		end

	load
			-- Load lock file from disk.
		local
			l_file: SIMPLE_FILE
			l_parser: SIMPLE_JSON
			l_content: STRING_8
			l_arr: SIMPLE_JSON_ARRAY
			i: INTEGER
		do
			create l_file.make (lock_file_path.to_string_8)
			if l_file.exists then
				l_content := l_file.read_text
				if not l_content.is_empty then
					create l_parser
					if attached l_parser.parse (l_content.to_string_32) as val and then val.is_object then
						if attached val.as_object as obj then
							if attached obj.string_item ("state") as s then
								state := s.to_string_32
							end
							if attached obj.string_item ("phase") as s then
								phase := s.to_string_32
							end
							phase_index := obj.integer_item ("phase_index").to_integer_32
							if attached obj.string_item ("last_command") as s then
								last_command := s.to_string_32
							end
							if attached obj.string_item ("last_command_time") as s then
								last_command_time := s.to_string_32
							end
							if attached obj.string_item ("expected_next") as s then
								expected_next := s.to_string_32
							end
							if attached obj.string_item ("pending_class") as s then
								pending_class := s.to_string_32
							end
							classes_remaining := obj.integer_item ("classes_remaining").to_integer_32
							classes_total := obj.integer_item ("classes_total").to_integer_32
							error_index := obj.integer_item ("error_index").to_integer_32
							errors_total := obj.integer_item ("errors_total").to_integer_32
							test_failure_index := obj.integer_item ("test_failure_index").to_integer_32
							test_failures_total := obj.integer_item ("test_failures_total").to_integer_32
							if attached obj.string_item ("warning") as s then
								warning := s.to_string_32
							end
							retry_count := obj.integer_item ("retry_count").to_integer_32

							-- Load skip_phases
							if obj.has_key ("skip_phases") then
								if attached obj.item ("skip_phases") as sp_val then
									if sp_val.is_array then
										l_arr := sp_val.as_array
										from i := 1 until i > l_arr.count loop
											if l_arr.item (i).is_integer then
												skip_phases.extend (l_arr.item (i).as_integer.to_integer_32)
												-- Also update phase_manager
												inspect l_arr.item (i).as_integer.to_integer_32
												when 1 then phase_manager.skip_prep
												when 2 then phase_manager.skip_plan
												when 8 then phase_manager.skip_docs
												when 9 then phase_manager.skip_git
												when 10 then phase_manager.skip_github
												else
													-- Unknown phase, ignore
												end
											end
											i := i + 1
										end
									end
								end
							end

							-- Load current_error
							if obj.has_key ("current_error") then
								if attached obj.item ("current_error") as err_val then
									if err_val.is_object then
										compile_errors.wipe_out
										compile_errors.extend (create {SCG_COMPILE_ERROR}.make_from_json (err_val.as_object))
									end
								end
							end

							-- Load current_failure
							if obj.has_key ("current_failure") then
								if attached obj.item ("current_failure") as fail_val then
									if fail_val.is_object then
										test_failures.wipe_out
										test_failures.extend (create {SCG_TEST_FAILURE}.make_from_json (fail_val.as_object))
									end
								end
							end
						end
					end
				end
			end
		end

	delete
			-- Delete lock file from disk.
		local
			l_file: SIMPLE_FILE
		do
			create l_file.make (lock_file_path.to_string_8)
			if l_file.exists then
				l_file.delete.do_nothing
			end
		end

feature {NONE} -- Implementation

	update_phase_from_state
			-- Update phase and phase_index based on current state.
		local
			l_phase_num: INTEGER
		do
			l_phase_num := phase_manager.phase_for_state (state.to_string_8)
			phase_index := l_phase_num
			phase := phase_manager.phase_name (l_phase_num).to_string_32
		end

	update_expected_and_warning
			-- Update expected_next and warning based on current state.
		do
			-- PREP states
			if state.same_string (phase_manager.State_prep_research) then
				expected_next := {STRING_32} "prep --research-done --session <name>"
				warning := {STRING_32} "Research domain, existing solutions, prior art. Document findings. Then call: simple_codegen prep --research-done --session <name>"
			elseif state.same_string (phase_manager.State_prep_reuse) then
				expected_next := {STRING_32} "prep --reuse-done --session <name>"
				warning := {STRING_32} "Analyze simple_* ecosystem for reusable code. Document what to reuse. Then call: simple_codegen prep --reuse-done --session <name>"
			elseif state.same_string (phase_manager.State_prep_deps) then
				expected_next := {STRING_32} "prep --deps-done --session <name>"
				warning := {STRING_32} "Identify external dependencies (C libs, APIs, etc). Document requirements. Then call: simple_codegen prep --deps-done --session <name>"
			elseif state.same_string (phase_manager.State_prep_scope) then
				expected_next := {STRING_32} "prep --scope-done --session <name>"
				warning := {STRING_32} "Define scope, constraints, boundaries. Document what's in/out of scope. Then call: simple_codegen prep --scope-done --session <name>"

			-- PLAN states
			elseif state.same_string (phase_manager.State_plan_arch) then
				expected_next := {STRING_32} "plan --arch-done --session <name>"
				warning := {STRING_32} "Design high-level architecture. Document class relationships. Then call: simple_codegen plan --arch-done --session <name>"
			elseif state.same_string (phase_manager.State_plan_classes) then
				expected_next := {STRING_32} "plan --classes-done --session <name>"
				warning := {STRING_32} "Define class list with responsibilities. Document each class purpose. Then call: simple_codegen plan --classes-done --session <name>"
			elseif state.same_string (phase_manager.State_plan_features) then
				expected_next := {STRING_32} "plan --features-done --session <name>"
				warning := {STRING_32} "Design feature signatures for each class. Document queries/commands. Then call: simple_codegen plan --features-done --session <name>"
			elseif state.same_string (phase_manager.State_plan_contracts) then
				expected_next := {STRING_32} "plan --contracts-done --session <name>"
				warning := {STRING_32} "Plan contract strategy (pre/post/invariant). Document key contracts. Then call: simple_codegen plan --contracts-done --session <name>"

			-- SPEC state
			elseif state.same_string (phase_manager.State_spec_generate) then
				expected_next := {STRING_32} "process --input <system_spec.json> --session <name>"
				warning := {STRING_32} "Generate system_spec.json ONLY. Then call: simple_codegen process --input response.txt --session <name>"

			-- DOCS states
			elseif state.same_string (phase_manager.State_docs_readme) then
				expected_next := {STRING_32} "docs --readme-done --session <name>"
				warning := {STRING_32} "Write README.md with usage, installation, examples. Then call: simple_codegen docs --readme-done --session <name>"
			elseif state.same_string (phase_manager.State_docs_index) then
				expected_next := {STRING_32} "docs --index-done --session <name>"
				warning := {STRING_32} "Create docs/index.html for GitHub Pages. Then call: simple_codegen docs --index-done --session <name>"
			elseif state.same_string (phase_manager.State_docs_examples) then
				expected_next := {STRING_32} "docs --examples-done --session <name>"
				warning := {STRING_32} "Add code examples to documentation. Then call: simple_codegen docs --examples-done --session <name>"

			-- GIT states
			elseif state.same_string (phase_manager.State_git_init) then
				expected_next := {STRING_32} "git --init-done --session <name> --project <path>"
				warning := {STRING_32} "Initialize git repository (git init). Then call: simple_codegen git --init-done --session <name> --project <path>"
			elseif state.same_string (phase_manager.State_git_ignore) then
				expected_next := {STRING_32} "git --ignore-done --session <name>"
				warning := {STRING_32} "Create .gitignore (EIFGENs, *.obj, etc). Then call: simple_codegen git --ignore-done --session <name>"
			elseif state.same_string (phase_manager.State_git_add) then
				expected_next := {STRING_32} "git --add-done --session <name>"
				warning := {STRING_32} "Stage files (git add .). Then call: simple_codegen git --add-done --session <name>"
			elseif state.same_string (phase_manager.State_git_commit) then
				expected_next := {STRING_32} "git --commit-done --session <name>"
				warning := {STRING_32} "Create initial commit (git commit -m ...). Then call: simple_codegen git --commit-done --session <name>"

			-- GITHUB states
			elseif state.same_string (phase_manager.State_github_create) then
				expected_next := {STRING_32} "github --create-done --session <name>"
				warning := {STRING_32} "Create GitHub repository (gh repo create). Then call: simple_codegen github --create-done --session <name>"
			elseif state.same_string (phase_manager.State_github_push) then
				expected_next := {STRING_32} "github --push-done --session <name>"
				warning := {STRING_32} "Push to remote (git push -u origin main). Then call: simple_codegen github --push-done --session <name>"
			elseif state.same_string (phase_manager.State_github_pages) then
				expected_next := {STRING_32} "github --pages-done --session <name>"
				warning := {STRING_32} "Enable GitHub Pages for docs. Then call: simple_codegen github --pages-done --session <name>"
			elseif state.same_string (phase_manager.State_github_release) then
				expected_next := {STRING_32} "github --release-done --session <name>"
				warning := {STRING_32} "Create initial release (gh release create). Then call: simple_codegen github --release-done --session <name>"

			-- COMPLETE state
			elseif state.same_string (phase_manager.State_complete) then
				expected_next := {STRING_32} "(workflow complete)"
				warning := {STRING_32} "Workflow complete. Project is ready for use."

			-- ERROR_RECOVERY state
			elseif state.same_string (phase_manager.State_error_recovery) then
				expected_next := {STRING_32} "simple_codegen lock --retry --session <name>"
				warning := {STRING_32} "TOOL ERROR occurred. STOP and investigate. " +
					"Check debug_trace.log for details. Do NOT continue until fixed. " +
					"After fixing: simple_codegen lock --retry --session <name>"

			else
				-- Default/unknown state
				expected_next := {STRING_32} "(check lock file)"
				warning := {STRING_32} "Unknown state. Check lock file or reset session."
			end
		end

	current_timestamp: STRING_32
			-- Current timestamp in ISO format
		local
			l_datetime: SIMPLE_DATE_TIME
		do
			create l_datetime.make_now
			Result := l_datetime.to_iso8601.to_string_32
		end

invariant
	session_path_not_empty: not session_path.is_empty
	state_not_empty: not state.is_empty
	phase_not_empty: not phase.is_empty
	phase_manager_exists: phase_manager /= Void
	skip_phases_exists: skip_phases /= Void
	compile_errors_exists: compile_errors /= Void
	test_failures_exists: test_failures /= Void

end
