note
	description: "Test cases for SCG_PROJECT_GEN project generator"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	TEST_SCG_PROJECT_GEN

inherit
	TEST_SET_BASE
		redefine
			on_prepare,
			on_clean
		end

feature {TEST_APP} -- Setup/Teardown

	prepare
			-- Create unique test path for this test instance.
		local
			l_uuid: SIMPLE_UUID
			l_dir: SIMPLE_FILE
			l_ok: BOOLEAN
		do
			-- Generate unique path for this test run (UUID ensures no collisions)
			create l_uuid.make
			current_test_path := temp_directory + "/scg_test_gen_" + l_uuid.new_v4_string

			-- Clean up if somehow exists (shouldn't with UUID)
			if attached current_test_path as p then
				create l_dir.make (p)
				if l_dir.exists then
					l_ok := l_dir.delete_directory_recursive
				end
			end
		end

	cleanup
			-- Clean up test project directory after test.
		local
			l_dir: SIMPLE_FILE
			l_ok: BOOLEAN
		do
			if attached current_test_path as p then
				create l_dir.make (p)
				if l_dir.exists then
					l_ok := l_dir.delete_directory_recursive
				end
			end
		end

feature {NONE} -- Events

	on_prepare
			-- Called by testing framework before each test.
		do
			prepare
		end

	on_clean
			-- Called by testing framework after each test.
		do
			cleanup
		end

feature {NONE} -- Test State (unique per test instance)

	current_test_path: detachable STRING
			-- Unique path for this test's project directory

feature -- Test

	test_project_generator
			-- Test SCG_PROJECT_GEN creates complete project structure.
		local
			l_gen: SCG_PROJECT_GEN
			l_path: SIMPLE_PATH
			l_libs: ARRAYED_LIST [STRING]
			l_file: SIMPLE_FILE
			l_content: STRING_32
		do
			check attached current_test_path as l_test_path then
				-- Setup
				create l_path.make_from (l_test_path)
				create l_libs.make (2)
				l_libs.extend ("simple_file")
				l_libs.extend ("simple_json")

				-- Generate project
				create l_gen.make_with_name (l_path, test_project_name, l_libs)

				-- Verify generator state
				assert ("is_generated", l_gen.is_generated)
				assert ("is_verified", l_gen.is_verified)
				assert ("project_name_set", l_gen.project_name.same_string (test_project_name))

				-- Verify directory structure
				assert_directory_exists ("root_exists", l_test_path)
				assert_directory_exists ("src_exists", l_test_path + "/src")
				assert_directory_exists ("testing_exists", l_test_path + "/testing")
				assert_directory_exists ("docs_exists", l_test_path + "/docs")

				-- Verify ECF file
				assert_file_exists ("ecf_exists", l_test_path + "/" + test_project_name + ".ecf")
				create l_file.make (l_test_path + "/" + test_project_name + ".ecf")
				l_content := l_file.read_text
				assert ("ecf_has_project_name", l_content.has_substring (test_project_name))
				assert ("ecf_has_library_target", l_content.has_substring ("library_target"))
				assert ("ecf_has_simple_file", l_content.has_substring ("simple_file"))
				assert ("ecf_has_simple_json", l_content.has_substring ("simple_json"))
				assert ("ecf_has_scoop", l_content.has_substring ("scoop"))
				assert ("ecf_has_void_safety", l_content.has_substring ("void_safety"))
				assert ("ecf_has_test_target", l_content.has_substring (test_project_name + "_tests"))

				-- Verify main class
				assert_file_exists ("main_class_exists", l_test_path + "/src/" + test_project_name + ".e")
				create l_file.make (l_test_path + "/src/" + test_project_name + ".e")
				l_content := l_file.read_text
				assert ("main_has_class_name", l_content.has_substring (test_project_name.as_upper))
				assert ("main_has_version", l_content.has_substring ("version"))

				-- Verify test_app.e
				assert_file_exists ("test_app_exists", l_test_path + "/testing/test_app.e")
				create l_file.make (l_test_path + "/testing/test_app.e")
				l_content := l_file.read_text
				assert ("test_app_has_class", l_content.has_substring ("TEST_APP"))
				assert ("test_app_has_make", l_content.has_substring ("make"))
				assert ("test_app_has_run_test", l_content.has_substring ("run_test"))
				assert ("test_app_has_passed", l_content.has_substring ("passed"))
				assert ("test_app_has_failed", l_content.has_substring ("failed"))

				-- Verify lib_tests.e
				assert_file_exists ("lib_tests_exists", l_test_path + "/testing/lib_tests.e")
				create l_file.make (l_test_path + "/testing/lib_tests.e")
				l_content := l_file.read_text
				assert ("lib_tests_has_class", l_content.has_substring ("LIB_TESTS"))
				assert ("lib_tests_has_test_set_base", l_content.has_substring ("TEST_SET_BASE"))
				assert ("lib_tests_has_test", l_content.has_substring ("test_creation"))

				-- Verify README.md
				assert_file_exists ("readme_exists", l_test_path + "/README.md")
				create l_file.make (l_test_path + "/README.md")
				l_content := l_file.read_text
				assert ("readme_has_title", l_content.has_substring ("# " + test_project_name))

				-- Verify CHANGELOG.md
				assert_file_exists ("changelog_exists", l_test_path + "/CHANGELOG.md")
				create l_file.make (l_test_path + "/CHANGELOG.md")
				l_content := l_file.read_text
				assert ("changelog_has_header", l_content.has_substring ("Changelog"))
				assert ("changelog_has_unreleased", l_content.has_substring ("Unreleased"))

				-- Verify .gitignore
				assert_file_exists ("gitignore_exists", l_test_path + "/.gitignore")
				create l_file.make (l_test_path + "/.gitignore")
				l_content := l_file.read_text
				assert ("gitignore_has_eifgens", l_content.has_substring ("EIFGENs"))
				assert ("gitignore_has_vscode", l_content.has_substring (".vscode"))
			end
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

	temp_directory: STRING
			-- System temp directory for test isolation
		local
			l_env: EXECUTION_ENVIRONMENT
		once
			create l_env
			if attached l_env.item ("TEMP") as t then
				Result := t.to_string_8
			elseif attached l_env.item ("TMP") as t then
				Result := t.to_string_8
			else
				Result := "C:/Temp"
			end
		end

end
