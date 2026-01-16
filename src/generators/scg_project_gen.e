note
	description: "Simple Code Generator - Project Generator"
	purpose: "[
		Generates new Eiffel project scaffolds including:
		- ECF configuration file (library or CLI app)
		- Source directory structure
		- Test scaffolding
		- README, CHANGELOG, .gitignore
		- Documentation stub
		]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_PROJECT_GEN

create
	make_with_name,
	make_cli_app

feature {NONE} -- Initialization

	make_with_name (a_path: SIMPLE_PATH; a_project_name: STRING; a_simple_libs: ARRAYED_LIST [STRING])
			-- Create a LIBRARY project named `a_project_name' at `a_path'.
		do
			project_type := Type_library
			initialize_common (a_path, a_project_name, a_simple_libs)
			generate_all
		ensure
			is_library: project_type.same_string (Type_library)
			generated: is_generated
		end

	make_cli_app (a_path: SIMPLE_PATH; a_project_name: STRING; a_simple_libs: ARRAYED_LIST [STRING])
			-- Create a CLI APPLICATION project named `a_project_name' at `a_path'.
		do
			project_type := Type_cli
			initialize_common (a_path, a_project_name, a_simple_libs)
			generate_all
		ensure
			is_cli: project_type.same_string (Type_cli)
			generated: is_generated
		end

	initialize_common (a_path: SIMPLE_PATH; a_project_name: STRING; a_simple_libs: ARRAYED_LIST [STRING])
			-- Initialize common attributes.
		do
			project_name := a_project_name
			project_path := a_path
			simple_libs := a_simple_libs
			create verification_error.make_empty
			create project_uuid.make
		end

	generate_all
			-- Generate all project files.
		do
			generate_directory_structure
			generate_ecf
			generate_main_class
			generate_test_app
			generate_lib_tests
			generate_readme
			generate_changelog
			generate_gitignore
			generate_docs_index

			is_generated := True

			-- Verify the generated project compiles
			verify_compilation
		end

feature -- Status

	is_generated: BOOLEAN
			-- Was project successfully generated?

	is_verified: BOOLEAN
			-- Did generated project pass compilation verification?

	verification_error: detachable STRING
			-- Error message if compilation verification failed

	is_library: BOOLEAN
			-- Is this a library project?
		do
			Result := project_type.same_string (Type_library)
		end

	is_cli_app: BOOLEAN
			-- Is this a CLI application project?
		do
			Result := project_type.same_string (Type_cli)
		end

feature -- Access

	project_name: STRING
			-- Name of the generated project

	project_path: SIMPLE_PATH
			-- Root path where project is generated

	project_uuid: SIMPLE_UUID
			-- UUID for the project ECF

	simple_libs: ARRAYED_LIST [STRING]
			-- List of simple_* libraries to include

	project_type: STRING
			-- Type of project: library or cli

feature -- Type Constants

	Type_library: STRING = "library"
	Type_cli: STRING = "cli"

feature {NONE} -- Generation

	generate_directory_structure
			-- Create the directory structure: src/, testing/, docs/, bin/
		local
			l_root, l_src, l_testing, l_docs, l_bin: SIMPLE_FILE
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

			create l_bin.make ((create {SIMPLE_PATH}.make_from (project_path.to_string)).add ("bin").to_string)
			l_ok := l_bin.create_directory
		end

	generate_ecf
			-- Generate the ECF configuration file based on project type.
		local
			l_file: SIMPLE_FILE
			l_content: STRING
			l_libs: STRING
			l_ok: BOOLEAN
			i: INTEGER
		do
			-- Build simple_* library references
			create l_libs.make_empty
			from i := 1 until i > simple_libs.count loop
				l_libs.append ("%T%T<library name=%"" + simple_libs.i_th (i) + "%" location=%"$SIMPLE_EIFFEL/" + simple_libs.i_th (i) + "/" + simple_libs.i_th (i) + ".ecf%"/>%N")
				i := i + 1
			end

			-- Select template based on project type
			if is_cli_app then
				l_content := ecf_cli_template.twin
			else
				l_content := ecf_library_template.twin
			end

			l_content.replace_substring_all ("${PROJECT_NAME}", project_name)
			l_content.replace_substring_all ("${PROJECT_UUID}", project_uuid.new_v4_string)
			l_content.replace_substring_all ("${SIMPLE_LIBS}", l_libs)
			l_content.replace_substring_all ("${CLASS_NAME}", class_name_from_project)

			create l_file.make ((create {SIMPLE_PATH}.make_from (project_path.to_string)).add (project_name + ".ecf").to_string)
			l_ok := l_file.write_text (l_content)
		end

	generate_main_class
			-- Generate the main class in src/.
		local
			l_file: SIMPLE_FILE
			l_content: STRING
			l_ok: BOOLEAN
		do
			if is_cli_app then
				l_content := main_class_cli_template.twin
			else
				l_content := main_class_library_template.twin
			end

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
			l_content.replace_substring_all ("${CLASS_NAME}", class_name_from_project)

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
			l_content.replace_substring_all ("${CLASS_NAME}", class_name_from_project)

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

	generate_docs_index
			-- Generate docs/index.html.
		local
			l_file: SIMPLE_FILE
			l_content: STRING
			l_ok: BOOLEAN
		do
			l_content := docs_index_template.twin
			l_content.replace_substring_all ("${PROJECT_NAME}", project_name)
			l_content.replace_substring_all ("${CLASS_NAME}", class_name_from_project)

			create l_file.make ((create {SIMPLE_PATH}.make_from (project_path.to_string)).add ("docs").add ("index.html").to_string)
			l_ok := l_file.write_text (l_content)
		end

	verify_compilation
			-- Verify generated project compiles using SC_COMPILER.
		local
			l_compiler: SC_COMPILER
			l_ecf: STRING
			l_workdir: STRING
			l_discard: SC_COMPILER
		do
			l_ecf := project_name + ".ecf"
			l_workdir := project_path.to_string.to_string_8

			-- Verify main target compiles (melt check)
			create l_compiler.make (l_ecf, project_name)
			l_discard := l_compiler.set_working_directory (l_workdir)
			l_compiler.compile_check

			if l_compiler.is_compiled then
				-- Verify test target compiles (melt check)
				create l_compiler.make (l_ecf, project_name + "_tests")
				l_discard := l_compiler.set_working_directory (l_workdir)
				l_compiler.compile_check

				if l_compiler.is_compiled then
					is_verified := True
				else
					is_verified := False
					verification_error := "Test target compilation failed: " + l_compiler.last_error
				end
			else
				is_verified := False
				verification_error := "Main target compilation failed: " + l_compiler.last_error
			end
		end

feature {NONE} -- Helpers

	class_name_from_project: STRING
			-- Convert project_name to CLASS_NAME (uppercase).
		do
			Result := project_name.as_upper
		end

feature {NONE} -- ECF Templates

	ecf_library_template: STRING = "[
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
		<library name="base" location="$ISE_LIBRARY/library/base/base.ecf"/>
		<library name="time" location="$ISE_LIBRARY/library/time/time.ecf"/>
${SIMPLE_LIBS}		<cluster name="src" location="./src/" recursive="true">
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
		<library name="testing" location="$ISE_LIBRARY/library/testing/testing.ecf"/>
		<cluster name="testing" location="./testing/" recursive="true"/>
	</target>
</system>
]"

	ecf_cli_template: STRING = "[
<?xml version="1.0" encoding="ISO-8859-1"?>
<system xmlns="http://www.eiffel.com/developers/xml/configuration-1-23-0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.eiffel.com/developers/xml/configuration-1-23-0 http://www.eiffel.com/developers/xml/configuration-1-23-0.xsd" name="${PROJECT_NAME}" uuid="${PROJECT_UUID}">
	<description>${PROJECT_NAME} CLI application</description>
	<target name="${PROJECT_NAME}">
		<root class="${CLASS_NAME}" feature="make"/>
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
		<library name="base" location="$ISE_LIBRARY/library/base/base.ecf"/>
		<library name="time" location="$ISE_LIBRARY/library/time/time.ecf"/>
${SIMPLE_LIBS}		<cluster name="src" location="./src/" recursive="true">
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
		<library name="testing" location="$ISE_LIBRARY/library/testing/testing.ecf"/>
		<cluster name="testing" location="./testing/" recursive="true"/>
	</target>
</system>
]"

feature {NONE} -- Class Templates

	main_class_library_template: STRING = "[
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

	main_class_cli_template: STRING = "[
note
	description: "${CLASS_NAME} - Main CLI application for ${PROJECT_NAME}"
	author: ""
	date: "$Date$"
	revision: "$Revision$"

class
	${CLASS_NAME}

inherit
	ARGUMENTS

create
	make

feature {NONE} -- Initialization

	make
			-- Entry point.
		do
			if argument_count < 1 or else argument (1).same_string ("--help") then
				show_help
			elseif argument (1).same_string ("--version") then
				show_version
			else
				run
			end
		end

feature -- Execution

	run
			-- Main execution logic.
		do
			print ("${PROJECT_NAME} running...%N")
			-- TODO: Implement main logic
		end

feature -- Help

	show_help
			-- Display help message.
		do
			print ("${PROJECT_NAME} - TODO: Add description%N%N")
			print ("USAGE:%N")
			print ("  ${PROJECT_NAME} [options]%N%N")
			print ("OPTIONS:%N")
			print ("  --help     Show this help message%N")
			print ("  --version  Show version information%N")
		end

	show_version
			-- Display version.
		do
			print ("${PROJECT_NAME} version 0.0.1%N")
		end

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
			run_test (agent lib_tests.test_creation, "test_creation")
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

	test_creation
			-- Test that main class can be created.
		local
			l_obj: ${CLASS_NAME}
		do
			create l_obj
			assert ("created", l_obj /= Void)
		end

end
]"

feature {NONE} -- Documentation Templates

	readme_template: STRING = "[
# ${PROJECT_NAME}

An Eiffel project in the simple_* ecosystem.

## Installation

Add to your ECF:

```xml
<library name="${PROJECT_NAME}" location="path/to/${PROJECT_NAME}.ecf"/>
```

## Usage

```eiffel
local
    l_obj: ${CLASS_NAME}
do
    create l_obj
end
```

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
.eiffel_lsp/

# IDE
.vscode/
*.swp
*~

# OS
.DS_Store
Thumbs.db
]"

	docs_index_template: STRING = "[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${PROJECT_NAME} Documentation</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        h1 { color: #333; }
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
        pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>${PROJECT_NAME}</h1>
    <p>An Eiffel project in the simple_* ecosystem.</p>

    <h2>Overview</h2>
    <p>TODO: Add project overview</p>

    <h2>API Reference</h2>
    <h3>${CLASS_NAME}</h3>
    <p>Main class. TODO: Document features.</p>

    <h2>Examples</h2>
    <pre><code>local
    l_obj: ${CLASS_NAME}
do
    create l_obj
end</code></pre>
</body>
</html>
]"

end
