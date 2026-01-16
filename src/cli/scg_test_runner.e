note
	description: "[
		EiffelStudio Test Runner Integration for simple_codegen CLI.

		Provides comprehensive test execution and result parsing:
		- Compile test target
		- Run EQA tests
		- Parse test results
		- Generate refinement prompts for failures
		- Track test history across sessions

		Supports F_code with -keep for contract-laden test execution.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_TEST_RUNNER

create
	make

feature {NONE} -- Initialization

	make (a_project_path: STRING_32)
			-- Initialize with project path.
		require
			path_not_empty: not a_project_path.is_empty
		do
			project_path := a_project_path
			create last_error.make_empty
			create test_results.make (20)
			create process.make
			create compiler.make
			build_mode := Build_mode_workbench
		ensure
			path_set: project_path = a_project_path
		end

feature -- Access

	project_path: STRING_32
			-- Path to project root

	ecf_path: detachable STRING_32
			-- Path to ECF file

	test_target: detachable STRING_32
			-- Test target name in ECF

	last_error: STRING_32
			-- Last error message

	test_results: ARRAYED_LIST [SCG_TEST_RESULT]
			-- Results from last test run

	process: SIMPLE_PROCESS
			-- Process executor

	compiler: SC_COMPILER
			-- Eiffel compiler wrapper

	build_mode: INTEGER
			-- Current build mode (workbench, finalized, finalized_keep)

feature -- Build Mode Constants

	Build_mode_workbench: INTEGER = 1
			-- W_code (development with assertions)

	Build_mode_finalized: INTEGER = 2
			-- F_code (optimized, no assertions)

	Build_mode_finalized_keep: INTEGER = 3
			-- F_code with -keep (optimized but assertions enabled)

feature -- Configuration

	set_ecf_path (a_path: STRING_32)
			-- Set ECF file path.
		require
			path_not_empty: not a_path.is_empty
		do
			ecf_path := a_path
		ensure
			ecf_set: ecf_path = a_path
		end

	set_test_target (a_target: STRING_32)
			-- Set test target name.
		require
			target_not_empty: not a_target.is_empty
		do
			test_target := a_target
		ensure
			target_set: test_target = a_target
		end

	set_build_mode (a_mode: INTEGER)
			-- Set build mode.
		require
			valid_mode: a_mode >= Build_mode_workbench and a_mode <= Build_mode_finalized_keep
		do
			build_mode := a_mode
		ensure
			mode_set: build_mode = a_mode
		end

	set_workbench_mode
			-- Use W_code (development).
		do
			build_mode := Build_mode_workbench
		ensure
			mode_set: build_mode = Build_mode_workbench
		end

	set_finalized_mode
			-- Use F_code (production).
		do
			build_mode := Build_mode_finalized
		ensure
			mode_set: build_mode = Build_mode_finalized
		end

	set_finalized_keep_mode
			-- Use F_code with -keep (testing with assertions).
		do
			build_mode := Build_mode_finalized_keep
		ensure
			mode_set: build_mode = Build_mode_finalized_keep
		end

feature -- Compilation

	compile_tests: BOOLEAN
			-- Compile the test target.
		require
			ecf_set: attached ecf_path
			target_set: attached test_target
		local
			l_result: SC_COMPILE_RESULT
		do
			if attached ecf_path as l_ecf and attached test_target as l_target then
				compiler.set_ecf (l_ecf.to_string_8)
				compiler.set_target (l_target.to_string_8)

				inspect build_mode
				when Build_mode_workbench then
					compiler.set_workbench
				when Build_mode_finalized then
					compiler.set_finalize
				when Build_mode_finalized_keep then
					compiler.set_finalize
					compiler.set_keep_assertions
				end

				l_result := compiler.compile
				Result := l_result.success

				if not Result then
					last_error := create {STRING_32}.make_from_string_general (l_result.error_message)
				end
			end
		end

	executable_path: STRING_32
			-- Path to compiled test executable.
		require
			ecf_set: attached ecf_path
			target_set: attached test_target
		local
			l_code_dir: STRING
		do
			create Result.make (200)
			Result.append (project_path)
			Result.append ({STRING_32} "/EIFGENs/")
			if attached test_target as l_target then
				Result.append (l_target)
			end
			Result.append ({STRING_32} "/")

			inspect build_mode
			when Build_mode_workbench then
				l_code_dir := "W_code"
			else
				l_code_dir := "F_code"
			end
			Result.append_string_general (l_code_dir)
			Result.append ({STRING_32} "/")

			-- Executable name (usually same as target or project name)
			if attached test_target as l_target then
				Result.append (l_target)
				Result.append ({STRING_32} ".exe")
			end
		end

feature -- Test Execution

	run_all_tests: BOOLEAN
			-- Run all tests and collect results.
		local
			l_exe: STRING_32
		do
			test_results.wipe_out
			l_exe := executable_path

			-- Run the test executable
			process.run_in_directory (l_exe.to_string_8, project_path.to_string_8)

			if process.last_exit_code = 0 then
				Result := True
				if attached process.last_output as l_out then
					parse_test_output (l_out.to_string_8)
				end
			else
				-- Tests may have failed but still produce output
				if attached process.last_output as l_out then
					parse_test_output (l_out.to_string_8)
				end
				Result := all_tests_passed
				if not Result then
					last_error := {STRING_32} "Some tests failed"
				end
			end
		end

	run_test_class (a_class_name: STRING_32): BOOLEAN
			-- Run tests for a specific test class.
		require
			class_not_empty: not a_class_name.is_empty
		local
			l_exe: STRING_32
			l_cmd: STRING
		do
			test_results.wipe_out
			l_exe := executable_path

			-- EQA test runner typically supports class filtering
			create l_cmd.make (200)
			l_cmd.append (l_exe.to_string_8)
			l_cmd.append (" -class ")
			l_cmd.append (a_class_name.to_string_8)

			process.run_in_directory (l_cmd, project_path.to_string_8)
			if attached process.last_output as l_out then
				parse_test_output (l_out.to_string_8)
			end
			Result := all_tests_passed
		end

	run_single_test (a_class_name, a_test_name: STRING_32): BOOLEAN
			-- Run a single test.
		require
			class_not_empty: not a_class_name.is_empty
			test_not_empty: not a_test_name.is_empty
		local
			l_exe: STRING_32
			l_cmd: STRING
		do
			test_results.wipe_out
			l_exe := executable_path

			create l_cmd.make (200)
			l_cmd.append (l_exe.to_string_8)
			l_cmd.append (" -class ")
			l_cmd.append (a_class_name.to_string_8)
			l_cmd.append (" -test ")
			l_cmd.append (a_test_name.to_string_8)

			process.run_in_directory (l_cmd, project_path.to_string_8)
			if attached process.last_output as l_out then
				parse_test_output (l_out.to_string_8)
			end
			Result := all_tests_passed
		end

feature -- Results

	all_tests_passed: BOOLEAN
			-- Did all tests pass?
		do
			Result := across test_results as ic all ic.passed end
		end

	passed_count: INTEGER
			-- Number of passed tests.
		do
			across test_results as ic loop
				if ic.passed then
					Result := Result + 1
				end
			end
		end

	failed_count: INTEGER
			-- Number of failed tests.
		do
			across test_results as ic loop
				if not ic.passed then
					Result := Result + 1
				end
			end
		end

	failed_tests: ARRAYED_LIST [SCG_TEST_RESULT]
			-- List of failed test results.
		do
			create Result.make (failed_count)
			across test_results as ic loop
				if not ic.passed then
					Result.extend (ic)
				end
			end
		end

	results_summary: STRING_32
			-- Summary of test results.
		do
			create Result.make (500)
			Result.append ({STRING_32} "=== TEST RESULTS ===%N")
			Result.append ({STRING_32} "Total: ")
			Result.append_integer (test_results.count)
			Result.append ({STRING_32} "  Passed: ")
			Result.append_integer (passed_count)
			Result.append ({STRING_32} "  Failed: ")
			Result.append_integer (failed_count)
			Result.append ({STRING_32} "%N%N")

			if failed_count > 0 then
				Result.append ({STRING_32} "FAILURES:%N")
				across failed_tests as ic loop
					Result.append ({STRING_32} "  ")
					Result.append (ic.class_name)
					Result.append ({STRING_32} ".")
					Result.append (ic.test_name)
					Result.append ({STRING_32} ": ")
					Result.append (ic.message)
					Result.append ({STRING_32} "%N")
				end
			end
		end

feature -- Refinement Generation

	generate_refinement_prompt: STRING_32
			-- Generate refinement prompt for failed tests.
		require
			has_failures: failed_count > 0
		local
			l_failed: like failed_tests
		do
			l_failed := failed_tests
			create Result.make (2000)

			Result.append ({STRING_32} "=== TEST FAILURES REQUIRING FIX ===%N%N")
			Result.append ({STRING_32} "The following tests failed and need to be fixed:%N%N")

			across l_failed as ic loop
				Result.append ({STRING_32} "TEST: ")
				Result.append (ic.class_name)
				Result.append ({STRING_32} ".")
				Result.append (ic.test_name)
				Result.append ({STRING_32} "%N")
				Result.append ({STRING_32} "FAILURE: ")
				Result.append (ic.message)
				Result.append ({STRING_32} "%N")
				if not ic.stack_trace.is_empty then
					Result.append ({STRING_32} "STACK:%N")
					Result.append (ic.stack_trace)
					Result.append ({STRING_32} "%N")
				end
				Result.append ({STRING_32} "%N")
			end

			Result.append ({STRING_32} "=== REQUIRED ACTION ===%N")
			Result.append ({STRING_32} "1. Analyze each failure%N")
			Result.append ({STRING_32} "2. Identify the root cause (code bug vs test bug)%N")
			Result.append ({STRING_32} "3. Fix the implementation or test as needed%N")
			Result.append ({STRING_32} "4. Ensure contracts are not violated%N%N")

			Result.append ({STRING_32} "=== OUTPUT FORMAT ===%N")
			Result.append ({STRING_32} "```json%N")
			Result.append ({STRING_32} "{%N")
			Result.append ({STRING_32} "  %"type%": %"test_fix%",%N")
			Result.append ({STRING_32} "  %"fixes%": [%N")
			Result.append ({STRING_32} "    {%N")
			Result.append ({STRING_32} "      %"test%": %"TEST_CLASS.test_name%",%N")
			Result.append ({STRING_32} "      %"diagnosis%": %"what was wrong%",%N")
			Result.append ({STRING_32} "      %"fix_type%": %"implementation|test%",%N")
			Result.append ({STRING_32} "      %"class_to_fix%": %"CLASS_NAME%",%N")
			Result.append ({STRING_32} "      %"code%": %"fixed code here%"%N")
			Result.append ({STRING_32} "    }%N")
			Result.append ({STRING_32} "  ]%N")
			Result.append ({STRING_32} "}%N")
			Result.append ({STRING_32} "```%N")
		end

feature {NONE} -- Implementation

	parse_test_output (a_output: STRING)
			-- Parse test output and populate results.
		local
			l_lines: LIST [STRING]
			l_line: STRING
			l_in_failure: BOOLEAN
		do
			test_results.wipe_out
			l_lines := a_output.split ('%N')

			across l_lines as ic loop
				l_line := ic
				l_line.left_adjust
				l_line.right_adjust

				-- Look for test result patterns
				-- EQA typically outputs: [PASS] CLASS_NAME.test_name or [FAIL] CLASS_NAME.test_name: message
				if l_line.has_substring ("[PASS]") or l_line.has_substring ("PASSED") then
					l_in_failure := False
					parse_test_line (l_line, True)
				elseif l_line.has_substring ("[FAIL]") or l_line.has_substring ("FAILED") then
					l_in_failure := True
					parse_test_line (l_line, False)
				elseif l_in_failure and not l_line.is_empty then
					-- Collect stack trace for failed test
					if test_results.count > 0 then
						test_results.last.append_to_stack_trace (l_line)
					end
				end
			end
		end

	parse_test_line (a_line: STRING; a_passed: BOOLEAN)
			-- Parse a single test result line.
		local
			l_result: SCG_TEST_RESULT
			l_class, l_test, l_message: STRING_32
			l_dot_pos, l_colon_pos: INTEGER
			l_content: STRING
		do
			-- Extract content after [PASS] or [FAIL]
			l_content := a_line.twin
			l_content.replace_substring_all ("[PASS]", "")
			l_content.replace_substring_all ("[FAIL]", "")
			l_content.replace_substring_all ("PASSED", "")
			l_content.replace_substring_all ("FAILED", "")
			l_content.left_adjust

			-- Parse CLASS_NAME.test_name: message
			l_dot_pos := l_content.index_of ('.', 1)
			l_colon_pos := l_content.index_of (':', 1)

			if l_dot_pos > 0 then
				l_class := create {STRING_32}.make_from_string_general (l_content.substring (1, l_dot_pos - 1))
				if l_colon_pos > l_dot_pos then
					l_test := create {STRING_32}.make_from_string_general (l_content.substring (l_dot_pos + 1, l_colon_pos - 1))
					l_message := create {STRING_32}.make_from_string_general (l_content.substring (l_colon_pos + 1, l_content.count))
					l_message.left_adjust
				else
					l_test := create {STRING_32}.make_from_string_general (l_content.substring (l_dot_pos + 1, l_content.count))
					create l_message.make_empty
				end
			else
				create l_class.make_from_string_general (l_content)
				create l_test.make_from_string ("unknown")
				create l_message.make_empty
			end

			l_test.right_adjust
			l_class.right_adjust

			create l_result.make (l_class, l_test, a_passed, l_message)
			test_results.extend (l_result)
		end

invariant
	project_path_exists: project_path /= Void
	test_results_exists: test_results /= Void
	process_exists: process /= Void
	compiler_exists: compiler /= Void
	valid_build_mode: build_mode >= Build_mode_workbench and build_mode <= Build_mode_finalized_keep

end
