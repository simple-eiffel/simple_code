note
	description: "[
		Centralized phase transition logic for the comprehensive lock-file pipeline.

		Manages 10 phases with ~70 states:
		Phase 1: PREP (Preparation) - 4 states
		Phase 2: PLAN (Planning) - 4 states
		Phase 3: SPEC (Specification) - 1 state
		Phase 4: CLASS (Per-Class Generation) - 2 states per class
		Phase 5: ASSEMBLE (Project Assembly) - 2 states
		Phase 6: COMPILE (Compilation) - dynamic states for errors
		Phase 7: TEST (Testing) - dynamic states for failures
		Phase 8: DOCS (Documentation) - 3 states
		Phase 9: GIT (Version Control) - 4 states
		Phase 10: GITHUB (GitHub Integration) - 4 states
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_PHASE_MANAGER

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize phase manager.
		do
			create skip_phases.make (0)
		end

feature -- Phase Constants

	Phase_prep: INTEGER = 1
	Phase_plan: INTEGER = 2
	Phase_spec: INTEGER = 3
	Phase_class: INTEGER = 4
	Phase_assemble: INTEGER = 5
	Phase_compile: INTEGER = 6
	Phase_test: INTEGER = 7
	Phase_docs: INTEGER = 8
	Phase_git: INTEGER = 9
	Phase_github: INTEGER = 10

feature -- State Constants - PREP Phase

	State_prep_research: STRING = "PREP_RESEARCH"
	State_prep_reuse: STRING = "PREP_REUSE"
	State_prep_deps: STRING = "PREP_DEPS"
	State_prep_scope: STRING = "PREP_SCOPE"

feature -- State Constants - PLAN Phase

	State_plan_arch: STRING = "PLAN_ARCH"
	State_plan_classes: STRING = "PLAN_CLASSES"
	State_plan_features: STRING = "PLAN_FEATURES"
	State_plan_contracts: STRING = "PLAN_CONTRACTS"

feature -- State Constants - SPEC Phase

	State_spec_generate: STRING = "SPEC_GENERATE"

feature -- State Constants - CLASS Phase (dynamic)

	State_class_contract_prefix: STRING = "CLASS_CONTRACT_"
	State_class_impl_prefix: STRING = "CLASS_IMPL_"

feature -- State Constants - ASSEMBLE Phase

	State_assemble_structure: STRING = "ASSEMBLE_STRUCTURE"
	State_assemble_ecf: STRING = "ASSEMBLE_ECF"

feature -- State Constants - COMPILE Phase (dynamic)

	State_compile_eiffel: STRING = "COMPILE_EIFFEL"
	State_compile_error_prefix: STRING = "COMPILE_ERROR_"
	State_compile_c: STRING = "COMPILE_C"
	State_compile_c_error_prefix: STRING = "COMPILE_C_ERROR_"
	State_compile_success: STRING = "COMPILE_SUCCESS"

feature -- State Constants - TEST Phase (dynamic)

	State_test_generate: STRING = "TEST_GENERATE"
	State_test_compile: STRING = "TEST_COMPILE"
	State_test_run: STRING = "TEST_RUN"
	State_test_failure_prefix: STRING = "TEST_FAILURE_"
	State_test_rerun: STRING = "TEST_RERUN"
	State_test_success: STRING = "TEST_SUCCESS"

feature -- State Constants - DOCS Phase

	State_docs_readme: STRING = "DOCS_README"
	State_docs_index: STRING = "DOCS_INDEX"
	State_docs_examples: STRING = "DOCS_EXAMPLES"

feature -- State Constants - GIT Phase

	State_git_init: STRING = "GIT_INIT"
	State_git_ignore: STRING = "GIT_IGNORE"
	State_git_add: STRING = "GIT_ADD"
	State_git_commit: STRING = "GIT_COMMIT"

feature -- State Constants - GITHUB Phase

	State_github_create: STRING = "GITHUB_CREATE"
	State_github_push: STRING = "GITHUB_PUSH"
	State_github_pages: STRING = "GITHUB_PAGES"
	State_github_release: STRING = "GITHUB_RELEASE"

feature -- State Constants - Terminal

	State_complete: STRING = "COMPLETE"
	State_idle: STRING = "IDLE"
	State_error_recovery: STRING = "ERROR_RECOVERY"
			-- Tool crash/error state - requires investigation before continuing

feature -- Access

	skip_phases: ARRAYED_LIST [INTEGER]
			-- Phases to skip (set via --skip-* flags)

feature -- Phase Skip Configuration

	skip_prep
			-- Mark PREP phase to be skipped.
		do
			if not skip_phases.has (Phase_prep) then
				skip_phases.extend (Phase_prep)
			end
		ensure
			skipped: skip_phases.has (Phase_prep)
		end

	skip_plan
			-- Mark PLAN phase to be skipped.
		do
			if not skip_phases.has (Phase_plan) then
				skip_phases.extend (Phase_plan)
			end
		ensure
			skipped: skip_phases.has (Phase_plan)
		end

	skip_docs
			-- Mark DOCS phase to be skipped.
		do
			if not skip_phases.has (Phase_docs) then
				skip_phases.extend (Phase_docs)
			end
		ensure
			skipped: skip_phases.has (Phase_docs)
		end

	skip_git
			-- Mark GIT phase to be skipped.
		do
			if not skip_phases.has (Phase_git) then
				skip_phases.extend (Phase_git)
			end
		ensure
			skipped: skip_phases.has (Phase_git)
		end

	skip_github
			-- Mark GITHUB phase to be skipped.
		do
			if not skip_phases.has (Phase_github) then
				skip_phases.extend (Phase_github)
			end
		ensure
			skipped: skip_phases.has (Phase_github)
		end

	is_phase_skipped (a_phase: INTEGER): BOOLEAN
			-- Is phase `a_phase' marked to be skipped?
		do
			Result := skip_phases.has (a_phase)
		end

feature -- State Queries

	phase_for_state (a_state: STRING): INTEGER
			-- Determine which phase a state belongs to.
		require
			state_not_empty: not a_state.is_empty
		do
			if a_state.starts_with ("PREP_") then
				Result := Phase_prep
			elseif a_state.starts_with ("PLAN_") then
				Result := Phase_plan
			elseif a_state.starts_with ("SPEC_") then
				Result := Phase_spec
			elseif a_state.starts_with ("CLASS_") then
				Result := Phase_class
			elseif a_state.starts_with ("ASSEMBLE_") then
				Result := Phase_assemble
			elseif a_state.starts_with ("COMPILE_") then
				Result := Phase_compile
			elseif a_state.starts_with ("TEST_") then
				Result := Phase_test
			elseif a_state.starts_with ("DOCS_") then
				Result := Phase_docs
			elseif a_state.starts_with ("GIT_") then
				Result := Phase_git
			elseif a_state.starts_with ("GITHUB_") then
				Result := Phase_github
			elseif a_state.same_string (State_complete) then
				Result := 11 -- Beyond all phases
			elseif a_state.same_string (State_error_recovery) then
				Result := 0 -- Error state - no phase until resolved
			else
				Result := 0 -- Unknown/IDLE
			end
		end

	phase_name (a_phase: INTEGER): STRING
			-- Human-readable name for phase.
		do
			inspect a_phase
			when 1 then Result := "PREP"
			when 2 then Result := "PLAN"
			when 3 then Result := "SPEC"
			when 4 then Result := "CLASS"
			when 5 then Result := "ASSEMBLE"
			when 6 then Result := "COMPILE"
			when 7 then Result := "TEST"
			when 8 then Result := "DOCS"
			when 9 then Result := "GIT"
			when 10 then Result := "GITHUB"
			when 11 then Result := "COMPLETE"
			else Result := "UNKNOWN"
			end
		end

	is_error_state (a_state: STRING): BOOLEAN
			-- Is this a compile error state?
		do
			Result := a_state.starts_with (State_compile_error_prefix) or
			          a_state.starts_with (State_compile_c_error_prefix)
		end

	is_failure_state (a_state: STRING): BOOLEAN
			-- Is this a test failure state?
		do
			Result := a_state.starts_with (State_test_failure_prefix)
		end

	is_error_recovery_state (a_state: STRING): BOOLEAN
			-- Is this the error recovery state (tool crash/error)?
		do
			Result := a_state.same_string (State_error_recovery)
		end

	extract_error_index (a_state: STRING): INTEGER
			-- Extract error index from error state (e.g., "COMPILE_ERROR_3" -> 3).
		require
			is_error_state: is_error_state (a_state)
		local
			l_prefix_len: INTEGER
			l_num_str: STRING
		do
			if a_state.starts_with (State_compile_error_prefix) then
				l_prefix_len := State_compile_error_prefix.count
			else
				l_prefix_len := State_compile_c_error_prefix.count
			end
			l_num_str := a_state.substring (l_prefix_len + 1, a_state.count)
			if l_num_str.is_integer then
				Result := l_num_str.to_integer
			end
		end

	extract_failure_index (a_state: STRING): INTEGER
			-- Extract failure index from failure state (e.g., "TEST_FAILURE_2" -> 2).
		require
			is_failure_state: is_failure_state (a_state)
		local
			l_prefix_len: INTEGER
			l_num_str: STRING
		do
			l_prefix_len := State_test_failure_prefix.count
			l_num_str := a_state.substring (l_prefix_len + 1, a_state.count)
			if l_num_str.is_integer then
				Result := l_num_str.to_integer
			end
		end

	extract_class_index (a_state: STRING): INTEGER
			-- Extract class index from class state (e.g., "CLASS_CONTRACT_2" -> 2).
		require
			is_class_state: a_state.starts_with (State_class_contract_prefix) or
			                a_state.starts_with (State_class_impl_prefix)
		local
			l_prefix_len: INTEGER
			l_num_str: STRING
		do
			if a_state.starts_with (State_class_contract_prefix) then
				l_prefix_len := State_class_contract_prefix.count
			else
				l_prefix_len := State_class_impl_prefix.count
			end
			l_num_str := a_state.substring (l_prefix_len + 1, a_state.count)
			if l_num_str.is_integer then
				Result := l_num_str.to_integer
			end
		end

feature -- Transition Logic

	initial_state: STRING
			-- Get initial state based on skip configuration.
		do
			if is_phase_skipped (Phase_prep) then
				if is_phase_skipped (Phase_plan) then
					Result := State_spec_generate
				else
					Result := State_plan_arch
				end
			else
				Result := State_prep_research
			end
		end

	next_prep_state (a_current: STRING): STRING
			-- Get next state within PREP phase.
		require
			in_prep_phase: a_current.starts_with ("PREP_")
		do
			if a_current.same_string (State_prep_research) then
				Result := State_prep_reuse
			elseif a_current.same_string (State_prep_reuse) then
				Result := State_prep_deps
			elseif a_current.same_string (State_prep_deps) then
				Result := State_prep_scope
			elseif a_current.same_string (State_prep_scope) then
				-- End of PREP, move to next phase
				if is_phase_skipped (Phase_plan) then
					Result := State_spec_generate
				else
					Result := State_plan_arch
				end
			else
				Result := State_prep_research
			end
		end

	next_plan_state (a_current: STRING): STRING
			-- Get next state within PLAN phase.
		require
			in_plan_phase: a_current.starts_with ("PLAN_")
		do
			if a_current.same_string (State_plan_arch) then
				Result := State_plan_classes
			elseif a_current.same_string (State_plan_classes) then
				Result := State_plan_features
			elseif a_current.same_string (State_plan_features) then
				Result := State_plan_contracts
			elseif a_current.same_string (State_plan_contracts) then
				-- End of PLAN, move to SPEC
				Result := State_spec_generate
			else
				Result := State_plan_arch
			end
		end

	next_assemble_state (a_current: STRING): STRING
			-- Get next state within ASSEMBLE phase.
		require
			in_assemble_phase: a_current.starts_with ("ASSEMBLE_")
		do
			if a_current.same_string (State_assemble_structure) then
				Result := State_assemble_ecf
			elseif a_current.same_string (State_assemble_ecf) then
				-- End of ASSEMBLE, move to COMPILE
				Result := State_compile_eiffel
			else
				Result := State_assemble_structure
			end
		end

	next_docs_state (a_current: STRING): STRING
			-- Get next state within DOCS phase.
		require
			in_docs_phase: a_current.starts_with ("DOCS_")
		do
			if a_current.same_string (State_docs_readme) then
				Result := State_docs_index
			elseif a_current.same_string (State_docs_index) then
				Result := State_docs_examples
			elseif a_current.same_string (State_docs_examples) then
				-- End of DOCS, move to GIT or skip
				if is_phase_skipped (Phase_git) then
					if is_phase_skipped (Phase_github) then
						Result := State_complete
					else
						Result := State_github_create
					end
				else
					Result := State_git_init
				end
			else
				Result := State_docs_readme
			end
		end

	next_git_state (a_current: STRING): STRING
			-- Get next state within GIT phase.
		require
			in_git_phase: a_current.starts_with ("GIT_")
		do
			if a_current.same_string (State_git_init) then
				Result := State_git_ignore
			elseif a_current.same_string (State_git_ignore) then
				Result := State_git_add
			elseif a_current.same_string (State_git_add) then
				Result := State_git_commit
			elseif a_current.same_string (State_git_commit) then
				-- End of GIT, move to GITHUB or complete
				if is_phase_skipped (Phase_github) then
					Result := State_complete
				else
					Result := State_github_create
				end
			else
				Result := State_git_init
			end
		end

	next_github_state (a_current: STRING): STRING
			-- Get next state within GITHUB phase.
		require
			in_github_phase: a_current.starts_with ("GITHUB_")
		do
			if a_current.same_string (State_github_create) then
				Result := State_github_push
			elseif a_current.same_string (State_github_push) then
				Result := State_github_pages
			elseif a_current.same_string (State_github_pages) then
				Result := State_github_release
			elseif a_current.same_string (State_github_release) then
				Result := State_complete
			else
				Result := State_github_create
			end
		end

	class_contract_state (a_index: INTEGER): STRING
			-- Generate CLASS_CONTRACT_n state.
		require
			positive_index: a_index >= 1
		do
			Result := State_class_contract_prefix + a_index.out
		end

	class_impl_state (a_index: INTEGER): STRING
			-- Generate CLASS_IMPL_n state.
		require
			positive_index: a_index >= 1
		do
			Result := State_class_impl_prefix + a_index.out
		end

	compile_error_state (a_index: INTEGER): STRING
			-- Generate COMPILE_ERROR_n state.
		require
			positive_index: a_index >= 1
		do
			Result := State_compile_error_prefix + a_index.out
		end

	compile_c_error_state (a_index: INTEGER): STRING
			-- Generate COMPILE_C_ERROR_n state.
		require
			positive_index: a_index >= 1
		do
			Result := State_compile_c_error_prefix + a_index.out
		end

	test_failure_state (a_index: INTEGER): STRING
			-- Generate TEST_FAILURE_n state.
		require
			positive_index: a_index >= 1
		do
			Result := State_test_failure_prefix + a_index.out
		end

feature -- State After Phases

	state_after_test_success: STRING
			-- State after tests pass.
		do
			if is_phase_skipped (Phase_docs) then
				if is_phase_skipped (Phase_git) then
					if is_phase_skipped (Phase_github) then
						Result := State_complete
					else
						Result := State_github_create
					end
				else
					Result := State_git_init
				end
			else
				Result := State_docs_readme
			end
		end

	state_after_compile_success: STRING
			-- State after compilation succeeds.
		do
			Result := State_test_generate
		end

invariant
	skip_phases_exists: skip_phases /= Void

end
