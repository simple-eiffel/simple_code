note
	description: "Simple Code Generator - Project Generator"
	purpose: "[
		Generates new Eiffel project scaffolds including:
		- ECF configuration file
		- Source directory structure
		- Test scaffolding
		- README and CHANGELOG
		]"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_PROJECT_GEN

create
	make_with_name

feature {NONE} -- Initialization

	make_with_name (a_path: SIMPLE_PATH; a_project_name: STRING; a_simple_libs: ARRAYED_LIST [STRING])
			-- `make_with_name' of `a_project_name' in `a_path', and populate the ECF with `a_simple_libs'.
		note
			design: "[
				The `make_with_name' feature comment tells some of the story.
				The rest of the story is that a newly generated project will
				always follow the simple_* testing pattern with a TEST_APP as
				a test-runner and a LIB_TESTS with at least one dummy test for
				the test-runner to run. This is very mechanical, so not real
				AI-help is required beyond the mechanics of this class. However,
				it should do as the primary class note describes (e.g. gen the
				ECF, and the src and test subclusters and scaffolding, as well
				as the initial README and CHANGELOG files). This class and make
				should also generate the appropriate .gitignore.
				]"
		do
			project_name := a_project_name
			project_path := a_path
			simple_libs := a_simple_libs

			create project_uuid.make

			generate_directory_structure
			generate_ecf
			generate_main_class
			generate_test_app
			generate_lib_tests
			generate_readme
			generate_changelog
			generate_gitignore

			is_generated := True
		ensure
			generated: is_generated
		end

feature -- Status

	is_generated: BOOLEAN
			-- Was project successfully generated?

feature -- Access

	project_name: STRING
			-- Name of the generated project

	project_path: SIMPLE_PATH
			-- Root path where project is generated

	project_uuid: SIMPLE_UUID
			-- UUID for the project ECF

	simple_libs: ARRAYED_LIST [STRING]
			-- List of simple_* libraries to include

feature {NONE} -- Generation

	generate_directory_structure
			-- Create the directory structure: src/, testing/, docs/
		local
			l_root, l_src, l_testing, l_docs: SIMPLE_FILE
			l_ok: BOOLEAN
		do
			create l_root.make (project_path.to_string)
			l_ok := l_root.create_directory_recursive

			create l_src.make ((create {SIMPLE_PATH}.make_from (project_path.to_string)).add ("src").to_string)
			l_ok := l_src.create_directory

			create l_testing.make ((create {SIMPLE_PATH}.make_from (project_path.to_string)).add ("testing").to_string)
			l_ok := l_testing.create_directory

			create l_docs.make ((create {SIMPLE_PATH}.make_from (project_path.to_string)).add ("docs").to_string)
			l_ok := l_docs.create_directory
		end

	generate_ecf
			-- Generate the ECF configuration file.
		local
			l_file: SIMPLE_FILE
			l_content: STRING
			l_libs: STRING
			l_ok: BOOLEAN
			i: INTEGER
		do
			create l_libs.make_empty
			from i := 1 until i > simple_libs.count loop
				l_libs.append ("%T%T<library name=%"" + simple_libs.i_th (i) + "%" location=%"$SIMPLE_EIFFEL\" + simple_libs.i_th (i) + "\" + simple_libs.i_th (i) + ".ecf%"/>%N")
				i := i + 1
			end

			l_content := ecf_template.twin
			l_content.replace_substring_all ("${PROJECT_NAME}", project_name)
			l_content.replace_substring_all ("${PROJECT_UUID}", project_uuid.new_v4_string)
			l_content.replace_substring_all ("${SIMPLE_LIBS}", l_libs)
			l_content.replace_substring_all ("${CLASS_NAME}", class_name_from_project)

			create l_file.make ((create {SIMPLE_PATH}.make_from (project_path.to_string)).add (project_name + ".ecf").to_string)
			l_ok := l_file.write_text (l_content)
		end

	generate_main_class
			-- Generate the main facade class in src/.
		local
			l_file: SIMPLE_FILE
			l_content: STRING
			l_ok: BOOLEAN
		do
			l_content := main_class_template.twin
			l_content.replace_substring_all ("${CLASS_NAME}", class_name_from_project)
			l_content.replace_substring_all ("${PROJECT_NAME}", project_name)

			create l_file.make ((create {SIMPLE_PATH}.make_from (project_path.to_string)).add ("src").add (project_name + ".e").to_string)
			l_ok := l_file.write_text (l_content)
		end

	generate_test_app
			-- Generate TEST_APP in testing/.
		local
			l_file: SIMPLE_FILE
			l_content: STRING
			l_ok: BOOLEAN
		do
			l_content := test_app_template.twin
			l_content.replace_substring_all ("${PROJECT_NAME}", project_name)
			l_content.replace_substring_all ("${PROJECT_NAME_UPPER}", project_name.as_upper)

			create l_file.make ((create {SIMPLE_PATH}.make_from (project_path.to_string)).add ("testing").add ("test_app.e").to_string)
			l_ok := l_file.write_text (l_content)
		end

	generate_lib_tests
			-- Generate LIB_TESTS in testing/.
		local
			l_file: SIMPLE_FILE
			l_content: STRING
			l_ok: BOOLEAN
		do
			l_content := lib_tests_template.twin
			l_content.replace_substring_all ("${PROJECT_NAME}", project_name)

			create l_file.make ((create {SIMPLE_PATH}.make_from (project_path.to_string)).add ("testing").add ("lib_tests.e").to_string)
			l_ok := l_file.write_text (l_content)
		end

	generate_readme
			-- Generate README.md.
		local
			l_file: SIMPLE_FILE
			l_content: STRING
			l_ok: BOOLEAN
		do
			l_content := readme_template.twin
			l_content.replace_substring_all ("${PROJECT_NAME}", project_name)

			create l_file.make ((create {SIMPLE_PATH}.make_from (project_path.to_string)).add ("README.md").to_string)
			l_ok := l_file.write_text (l_content)
		end

	generate_changelog
			-- Generate CHANGELOG.md.
		local
			l_file: SIMPLE_FILE
			l_content: STRING
			l_ok: BOOLEAN
		do
			l_content := changelog_template.twin
			l_content.replace_substring_all ("${PROJECT_NAME}", project_name)

			create l_file.make ((create {SIMPLE_PATH}.make_from (project_path.to_string)).add ("CHANGELOG.md").to_string)
			l_ok := l_file.write_text (l_content)
		end

	generate_gitignore
			-- Generate .gitignore.
		local
			l_file: SIMPLE_FILE
			l_ok: BOOLEAN
		do
			create l_file.make ((create {SIMPLE_PATH}.make_from (project_path.to_string)).add (".gitignore").to_string)
			l_ok := l_file.write_text (gitignore_template)
		end

feature {NONE} -- Helpers

	class_name_from_project: STRING
			-- Convert project_name to CLASS_NAME (uppercase, underscores).
		do
			Result := project_name.as_upper
		end

feature {NONE} -- Templates

	ecf_template: STRING = "[
<?xml version="1.0" encoding="ISO-8859-1"?>
<system xmlns="http://www.eiffel.com/developers/xml/configuration-1-23-0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.eiffel.com/developers/xml/configuration-1-23-0 http://www.eiffel.com/developers/xml/configuration-1-23-0.xsd" name="${PROJECT_NAME}" uuid="${PROJECT_UUID}" library_target="${PROJECT_NAME}">
	<description>${PROJECT_NAME} library</description>
	<target name="${PROJECT_NAME}">
		<root all_classes="true"/>
		<version major="0" minor="0" release="1" build="1"/>
		<option warning="warning" manifest_array_type="mismatch_warning">
			<assertions precondition="true" postcondition="true" check="true" invariant="true" loop="true" supplier_precondition="true"/>
		</option>
		<setting name="console_application" value="true"/>
		<setting name="dead_code_removal" value="feature"/>
		<capability>
			<concurrency support="scoop"/>
			<void_safety support="all"/>
		</capability>
		<library name="base" location="$ISE_LIBRARY\library\base\base.ecf"/>
${SIMPLE_LIBS}		<cluster name="src" location=".\src\" recursive="true">
			<file_rule>
				<exclude>/.git$</exclude>
				<exclude>/.svn$</exclude>
				<exclude>/EIFGENs$</exclude>
			</file_rule>
		</cluster>
	</target>
	<target name="${PROJECT_NAME}_tests" extends="${PROJECT_NAME}">
		<description>Test target for ${PROJECT_NAME}</description>
		<root class="TEST_APP" feature="make"/>
		<library name="testing" location="$ISE_LIBRARY\library\testing\testing.ecf"/>
		<cluster name="test_classes" location=".\testing\" recursive="true"/>
	</target>
</system>
]"

	main_class_template: STRING = "[
note
	description: "${CLASS_NAME} - Main facade class for ${PROJECT_NAME}"
	author: ""
	date: "$Date$"
	revision: "$Revision$"

class
	${CLASS_NAME}

feature -- Access

	version: STRING = "0.0.1"
			-- Library version

end
]"

	test_app_template: STRING = "[
note
	description: "Test runner application for ${PROJECT_NAME}"
	author: ""
	date: "$Date$"
	revision: "$Revision$"

class
	TEST_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run the tests.
		do
			print ("Running ${PROJECT_NAME_UPPER} tests...%N%N")
			passed := 0
			failed := 0

			run_lib_tests

			print ("%N========================%N")
			print ("Results: " + passed.out + " passed, " + failed.out + " failed%N")

			if failed > 0 then
				print ("TESTS FAILED%N")
			else
				print ("ALL TESTS PASSED%N")
			end
		end

feature {NONE} -- Test Runners

	run_lib_tests
			-- Run LIB_TESTS test cases.
		do
			create lib_tests
			run_test (agent lib_tests.test_dummy, "test_dummy")
		end

feature {NONE} -- Implementation

	lib_tests: LIB_TESTS

	passed: INTEGER
	failed: INTEGER

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run a single test and update counters.
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				a_test.call (Void)
				print ("  PASS: " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			print ("  FAIL: " + a_name + "%N")
			failed := failed + 1
			l_retried := True
			retry
		end

end
]"

	lib_tests_template: STRING = "[
note
	description: "Test cases for ${PROJECT_NAME}"
	author: ""
	date: "$Date$"
	revision: "$Revision$"

class
	LIB_TESTS

inherit
	EQA_TEST_SET

feature -- Tests

	test_dummy
			-- Placeholder test - replace with real tests.
		do
			assert ("dummy_passes", True)
		end

end
]"

	readme_template: STRING = "[
# ${PROJECT_NAME}

## Description

TODO: Add project description

## Installation

TODO: Add installation instructions

## Usage

TODO: Add usage examples

## License

MIT License
]"

	changelog_template: STRING = "[
# Changelog

All notable changes to ${PROJECT_NAME} will be documented in this file.

## [Unreleased]

### Added
- Initial project structure

## [0.0.1] - YYYY-MM-DD

### Added
- Initial release
]"

	gitignore_template: STRING = "[
# Eiffel build artifacts
EIFGENs/
Documentation/

# Compiled files
*.melted
*.o
*.obj
*.exe
*.dll
*.so
*.dylib

# Backup files
*.swp
*.bak
*~

# IDE files
.vscode/
.idea/

# OS files
.DS_Store
Thumbs.db
]"

end
