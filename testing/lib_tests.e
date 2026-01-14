note
	description: "Test cases for simple_code"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	LIB_TESTS

inherit
	TEST_SET_BASE
		redefine
			on_prepare,
			on_clean
		end

feature {NONE} -- Events

	on_prepare
			-- Ensure test project directory does not exist before test.
		local
			l_dir: SIMPLE_FILE
			l_ok: BOOLEAN
		do
			create l_dir.make (test_project_path)
			if l_dir.exists then
				l_ok := l_dir.delete_directory_recursive
			end
		end

	on_clean
			-- Clean up test project directory after test.
		local
			l_dir: SIMPLE_FILE
			l_ok: BOOLEAN
		do
			create l_dir.make (test_project_path)
			if l_dir.exists then
				l_ok := l_dir.delete_directory_recursive
			end
		end

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

			-- Verify path construction
			assert ("eifgens_path", l_compiler.eifgens_path.same_string ("EIFGENs/test_target"))
			assert ("f_code_path", l_compiler.f_code_path.same_string ("EIFGENs/test_target/F_code"))
			assert ("w_code_path", l_compiler.w_code_path.same_string ("EIFGENs/test_target/W_code"))

			-- Verify fluent API (need to capture result since functions can't be used as instructions)
			l_discard := l_compiler.set_working_directory ("/my/project")
			l_discard := l_compiler.set_verbose (True)
			assert ("working_dir_set", l_compiler.working_directory.same_string ("/my/project"))
			assert ("verbose_set", l_compiler.is_verbose)
			assert ("eifgens_with_workdir", l_compiler.eifgens_path.same_string ("/my/project/EIFGENs/test_target"))

			-- Verify ec.exe path contains expected components
			assert ("ec_path_has_studio", l_compiler.ec_exe_path.has_substring ("studio"))
			assert ("ec_path_has_ec", l_compiler.ec_exe_path.has_substring ("ec.exe"))
		end

	test_project_generator
			-- Test SCG_PROJECT_GEN creates complete project structure.
		local
			l_gen: SCG_PROJECT_GEN
			l_path: SIMPLE_PATH
			l_libs: ARRAYED_LIST [STRING]
			l_file: SIMPLE_FILE
			l_content: STRING_32
		do
			-- Setup
			create l_path.make_from (test_project_path)
			create l_libs.make (2)
			l_libs.extend ("simple_file")
			l_libs.extend ("simple_json")

			-- Generate project
			create l_gen.make_with_name (l_path, test_project_name, l_libs)

			-- Verify generator state
			assert ("is_generated", l_gen.is_generated)
			assert ("project_name_set", l_gen.project_name.same_string (test_project_name))

			-- Verify directory structure
			assert_directory_exists ("root_exists", test_project_path)
			assert_directory_exists ("src_exists", test_project_path + "/src")
			assert_directory_exists ("testing_exists", test_project_path + "/testing")
			assert_directory_exists ("docs_exists", test_project_path + "/docs")

			-- Verify ECF file
			assert_file_exists ("ecf_exists", test_project_path + "/" + test_project_name + ".ecf")
			create l_file.make (test_project_path + "/" + test_project_name + ".ecf")
			l_content := l_file.read_text
			assert ("ecf_has_project_name", l_content.has_substring (test_project_name))
			assert ("ecf_has_library_target", l_content.has_substring ("library_target"))
			assert ("ecf_has_simple_file", l_content.has_substring ("simple_file"))
			assert ("ecf_has_simple_json", l_content.has_substring ("simple_json"))
			assert ("ecf_has_scoop", l_content.has_substring ("scoop"))
			assert ("ecf_has_void_safety", l_content.has_substring ("void_safety"))
			assert ("ecf_has_test_target", l_content.has_substring (test_project_name + "_tests"))

			-- Verify main class
			assert_file_exists ("main_class_exists", test_project_path + "/src/" + test_project_name + ".e")
			create l_file.make (test_project_path + "/src/" + test_project_name + ".e")
			l_content := l_file.read_text
			assert ("main_has_class_name", l_content.has_substring (test_project_name.as_upper))
			assert ("main_has_version", l_content.has_substring ("version"))

			-- Verify test_app.e
			assert_file_exists ("test_app_exists", test_project_path + "/testing/test_app.e")
			create l_file.make (test_project_path + "/testing/test_app.e")
			l_content := l_file.read_text
			assert ("test_app_has_class", l_content.has_substring ("TEST_APP"))
			assert ("test_app_has_make", l_content.has_substring ("make"))
			assert ("test_app_has_run_test", l_content.has_substring ("run_test"))
			assert ("test_app_has_passed", l_content.has_substring ("passed"))
			assert ("test_app_has_failed", l_content.has_substring ("failed"))

			-- Verify lib_tests.e
			assert_file_exists ("lib_tests_exists", test_project_path + "/testing/lib_tests.e")
			create l_file.make (test_project_path + "/testing/lib_tests.e")
			l_content := l_file.read_text
			assert ("lib_tests_has_class", l_content.has_substring ("LIB_TESTS"))
			assert ("lib_tests_has_eqa", l_content.has_substring ("EQA_TEST_SET"))
			assert ("lib_tests_has_test", l_content.has_substring ("test_dummy"))

			-- Verify README.md
			assert_file_exists ("readme_exists", test_project_path + "/README.md")
			create l_file.make (test_project_path + "/README.md")
			l_content := l_file.read_text
			assert ("readme_has_title", l_content.has_substring ("# " + test_project_name))

			-- Verify CHANGELOG.md
			assert_file_exists ("changelog_exists", test_project_path + "/CHANGELOG.md")
			create l_file.make (test_project_path + "/CHANGELOG.md")
			l_content := l_file.read_text
			assert ("changelog_has_header", l_content.has_substring ("Changelog"))
			assert ("changelog_has_unreleased", l_content.has_substring ("Unreleased"))

			-- Verify .gitignore
			assert_file_exists ("gitignore_exists", test_project_path + "/.gitignore")
			create l_file.make (test_project_path + "/.gitignore")
			l_content := l_file.read_text
			assert ("gitignore_has_eifgens", l_content.has_substring ("EIFGENs"))
			assert ("gitignore_has_exe", l_content.has_substring ("*.exe"))
		end

feature {NONE} -- Test Helpers

	assert_file_exists (a_tag: STRING; a_path: STRING)
			-- Assert that file at `a_path' exists.
		local
			l_file: SIMPLE_FILE
		do
			create l_file.make (a_path)
			assert (a_tag, l_file.is_file)
		end

	assert_directory_exists (a_tag: STRING; a_path: STRING)
			-- Assert that directory at `a_path' exists.
		local
			l_file: SIMPLE_FILE
		do
			create l_file.make (a_path)
			assert (a_tag, l_file.is_directory)
		end

feature {NONE} -- Test Constants

	test_project_name: STRING = "test_generated_project"
			-- Name of test project to generate

	test_project_path: STRING
			-- Path where test project will be generated
		once
			Result := "D:/prod/simple_code/testing/temp_test_project"
		end

end
