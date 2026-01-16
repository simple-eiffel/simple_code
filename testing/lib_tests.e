note
	description: "Core test cases for simple_code library"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	LIB_TESTS

inherit
	TEST_SET_BASE

feature -- Test

	test_version_exists
			-- Verify version constants exist.
		local
			l_constants: SC_CONSTANTS
		do
			create l_constants
			assert ("version_major_valid", l_constants.version_major >= 0)
			assert ("version_string_not_empty", not l_constants.version_string.is_empty)
		end

	test_sc_compiler_paths
			-- Verify SC_COMPILER constructs paths correctly.
		local
			l_compiler: SC_COMPILER
			l_discard: SC_COMPILER
		do
			create l_compiler.make ("test.ecf", "test_target")

			-- Verify path construction (Windows backslash separators)
			assert ("eifgens_path", l_compiler.eifgens_path.same_string ("EIFGENs\test_target"))
			assert ("f_code_path", l_compiler.f_code_path.same_string ("EIFGENs\test_target\F_code"))
			assert ("w_code_path", l_compiler.w_code_path.same_string ("EIFGENs\test_target\W_code"))

			-- Verify fluent API (need to capture result since functions can't be used as instructions)
			l_discard := l_compiler.set_working_directory ("D:\my\project")
			l_discard := l_compiler.set_verbose (True)
			assert ("working_dir_set", l_compiler.working_directory.same_string ("D:\my\project"))
			assert ("verbose_set", l_compiler.is_verbose)
			assert ("eifgens_with_workdir", l_compiler.eifgens_path.same_string ("D:\my\project\EIFGENs\test_target"))

			-- Verify ec.exe path contains expected components
			assert ("ec_path_has_studio", l_compiler.ec_exe_path.has_substring ("studio"))
			assert ("ec_path_has_ec", l_compiler.ec_exe_path.has_substring ("ec.exe"))

			-- Verify test-related attributes are initialized
			assert ("tests_not_passed_initially", not l_compiler.tests_passed)
			assert ("test_exit_code_zero", l_compiler.last_test_exit_code = 0)
			assert ("test_output_empty", l_compiler.last_test_output.is_empty)
		end

end
