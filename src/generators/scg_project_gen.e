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
	make_with_externals,
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

	make_with_externals (a_path: SIMPLE_PATH; a_project_name: STRING; a_simple_libs: ARRAYED_LIST [STRING]; a_external_deps: ARRAYED_LIST [TUPLE [name: STRING_8; include_path: STRING_8; library_path: STRING_8]])
			-- Create a LIBRARY project named `a_project_name' at `a_path' with external C dependencies.
		do
			project_type := Type_library
			initialize_common (a_path, a_project_name, a_simple_libs)
			external_deps := a_external_deps
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
			create external_deps.make (0)
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

	external_deps: ARRAYED_LIST [TUPLE [name: STRING_8; include_path: STRING_8; library_path: STRING_8]]
			-- External C library dependencies (include paths and library paths for ECF)

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
			l_externals: STRING
			l_ok: BOOLEAN
			i: INTEGER
		do
			-- Build simple_* library references
			create l_libs.make_empty
			from i := 1 until i > simple_libs.count loop
				l_libs.append ("%T%T<library name=%"" + simple_libs.i_th (i) + "%" location=%"D:\prod\" + simple_libs.i_th (i) + "\" + simple_libs.i_th (i) + ".ecf%"/>%N")
				i := i + 1
			end

			-- Build external C library references
			create l_externals.make_empty
			across external_deps as dep loop
				if not dep.include_path.is_empty then
					l_externals.append ("%T%T<external_include location=%"" + dep.include_path + "%"/>%N")
				end
				if not dep.library_path.is_empty then
					l_externals.append ("%T%T<external_library location=%"" + dep.library_path + "%"/>%N")
				end
			end

			-- Select template based on project type
			if is_cli_app then
				l_content := ecf_cli_template.twin
			else
				l_content := ecf_library_template.twin
			end

			l_content.replace_substring_all ("${PROJECT_NAME}", project_name)
			l_content.replace_substring_all ("${PROJECT_UUID}", project_uuid.new_v4_string)
			l_content.replace_substring_all ("${EXTERNAL_DEPS}", l_externals)
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
${EXTERNAL_DEPS}		<library name="base" location="$ISE_LIBRARY/library/base/base.ecf"/>
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
		<library name="simple_testing" location="D:\prod\simple_testing\simple_testing.ecf"/>
		<cluster name="tests" location="./testing/" recursive="true"/>
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
${EXTERNAL_DEPS}		<library name="base" location="$ISE_LIBRARY/library/base/base.ecf"/>
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
		<library name="simple_testing" location="D:\prod\simple_testing\simple_testing.ecf"/>
		<cluster name="tests" location="./testing/" recursive="true"/>
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
	TEST_SET_BASE

feature -- Tests

	test_creation
			-- Test that main class can be created.
		local
			l_obj: ${CLASS_NAME}
		do
			create l_obj.make
			assert ("created", l_obj /= Void)
		end

end
]"

feature {NONE} -- Documentation Templates

	readme_template: STRING = "[
<p align="center">
  <img src="https://raw.githubusercontent.com/simple-eiffel/claude_eiffel_op_docs/main/artwork/LOGO.png" alt="simple_ library logo" width="400">
</p>

# ${PROJECT_NAME}

**[Documentation](https://simple-eiffel.github.io/${PROJECT_NAME}/)** | **[GitHub](https://github.com/simple-eiffel/${PROJECT_NAME})**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Eiffel](https://img.shields.io/badge/Eiffel-25.02-blue.svg)](https://www.eiffel.org/)
[![Design by Contract](https://img.shields.io/badge/DbC-enforced-orange.svg)]()

<!-- TODO: Add one-line description of what this library does -->

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem.

## Status

**Development** - Initial release

## Overview

<!-- TODO: Describe what this library does and why it's useful -->

## Features

<!-- TODO: List key features as bullet points -->
- **Design by Contract** - Full preconditions, postconditions, invariants
- **Void Safe** - Fully void-safe implementation
- **SCOOP Compatible** - Ready for concurrent use

## Installation

1. Set the ecosystem environment variable (one-time setup for all simple_* libraries):
```bash
export SIMPLE_EIFFEL=D:\prod
```

2. Add to your ECF:
```xml
<library name="${PROJECT_NAME}" location="$SIMPLE_EIFFEL/${PROJECT_NAME}/${PROJECT_NAME}.ecf"/>
```

## Quick Start

```eiffel
local
    l_obj: ${CLASS_NAME}
do
    create l_obj.make
    -- TODO: Add usage example
end
```

## API Reference

<!-- TODO: Document main features -->

| Feature | Description |
|---------|-------------|
| `make` | Create instance |

## Dependencies

- EiffelBase only (or list other simple_* dependencies)

## License

MIT License - Copyright (c) 2024-2025, Larry Rix

---

<sub>Generated by [simple_codegen](https://github.com/simple-eiffel/simple_code) - AI-assisted Eiffel code generation</sub>
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
    <title>${PROJECT_NAME} - Eiffel Library Documentation</title>
    <style>
        :root { --primary: #2563eb; --secondary: #1e40af; --bg: #f8fafc; --text: #1e293b; }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; }
        header { background: linear-gradient(135deg, var(--primary), var(--secondary)); color: white; padding: 3rem 2rem; text-align: center; }
        header h1 { font-size: 2.5rem; margin-bottom: 0.5rem; }
        .tagline { opacity: 0.9; font-size: 1.2rem; margin-bottom: 1rem; }
        .badges { display: flex; gap: 0.5rem; justify-content: center; flex-wrap: wrap; }
        .badge { padding: 0.25rem 0.75rem; border-radius: 1rem; font-size: 0.8rem; font-weight: 500; }
        .badge-version { background: #22c55e; }
        .badge-license { background: #eab308; color: #1e293b; }
        nav { background: white; border-bottom: 1px solid #e2e8f0; padding: 1rem; position: sticky; top: 0; z-index: 100; }
        nav ul { list-style: none; display: flex; gap: 2rem; justify-content: center; flex-wrap: wrap; }
        nav a { color: var(--text); text-decoration: none; font-weight: 500; }
        nav a:hover { color: var(--primary); }
        main { max-width: 900px; margin: 0 auto; padding: 2rem; }
        section { background: white; border-radius: 0.5rem; padding: 2rem; margin-bottom: 2rem; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        h2 { color: var(--primary); margin-bottom: 1rem; padding-bottom: 0.5rem; border-bottom: 2px solid #e2e8f0; }
        h3 { margin: 1.5rem 0 0.75rem; }
        pre { background: #1e293b; color: #e2e8f0; padding: 1rem; border-radius: 0.5rem; overflow-x: auto; margin: 1rem 0; }
        code { font-family: 'Fira Code', 'Consolas', monospace; font-size: 0.9rem; }
        .inline-code { background: #e2e8f0; padding: 0.125rem 0.375rem; border-radius: 0.25rem; color: var(--text); }
        table { width: 100%; border-collapse: collapse; margin: 1rem 0; }
        th, td { padding: 0.75rem; text-align: left; border-bottom: 1px solid #e2e8f0; }
        th { background: #f1f5f9; font-weight: 600; }
        .feature-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 1rem; margin-top: 1rem; }
        .feature-card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 0.5rem; padding: 1rem; }
        .feature-card h4 { color: var(--primary); margin-bottom: 0.5rem; }
        footer { text-align: center; padding: 2rem; color: #64748b; border-top: 1px solid #e2e8f0; }
        .keyword { color: #c084fc; }
        .type { color: #22d3ee; }
        .string { color: #4ade80; }
        .comment { color: #64748b; }
    </style>
</head>
<body>
    <header>
        <h1>${PROJECT_NAME}</h1>
        <p class="tagline"><!-- TODO: Add tagline --></p>
        <div class="badges">
            <span class="badge badge-version">v0.0.1</span>
            <span class="badge badge-license">MIT</span>
        </div>
    </header>

    <nav>
        <ul>
            <li><a href="#overview">Overview</a></li>
            <li><a href="#quick-start">Quick Start</a></li>
            <li><a href="#features">Features</a></li>
            <li><a href="#api">API Reference</a></li>
            <li><a href="https://github.com/simple-eiffel/${PROJECT_NAME}">GitHub</a></li>
        </ul>
    </nav>

    <main>
        <section id="overview">
            <h2>Overview</h2>
            <p>
                <strong>${PROJECT_NAME}</strong> is part of the <strong>simple_*</strong> ecosystem
                of focused, single-purpose Eiffel libraries with full Design by Contract support.
            </p>
            <!-- TODO: Add detailed description -->
        </section>

        <section id="quick-start">
            <h2>Quick Start</h2>
            <h3>Installation</h3>
            <p>Set environment variable and add to your ECF:</p>
<pre><code><span class="comment">-- Set SIMPLE_EIFFEL=D:\prod</span>
&lt;library name="${PROJECT_NAME}" location="$SIMPLE_EIFFEL/${PROJECT_NAME}/${PROJECT_NAME}.ecf"/&gt;</code></pre>

            <h3>Basic Usage</h3>
<pre><code><span class="keyword">local</span>
    l_obj: <span class="type">${CLASS_NAME}</span>
<span class="keyword">do</span>
    <span class="keyword">create</span> l_obj.make
    <span class="comment">-- TODO: Add example</span>
<span class="keyword">end</span></code></pre>
        </section>

        <section id="features">
            <h2>Features</h2>
            <div class="feature-grid">
                <div class="feature-card">
                    <h4>Design by Contract</h4>
                    <p>Full preconditions, postconditions, and class invariants.</p>
                </div>
                <div class="feature-card">
                    <h4>Void Safety</h4>
                    <p>Fully void-safe implementation with proper attached/detachable handling.</p>
                </div>
                <div class="feature-card">
                    <h4>SCOOP Compatible</h4>
                    <p>Ready for concurrent programming with SCOOP.</p>
                </div>
                <!-- TODO: Add more feature cards -->
            </div>
        </section>

        <section id="api">
            <h2>API Reference</h2>
            <h3>${CLASS_NAME}</h3>
            <table>
                <thead>
                    <tr><th>Feature</th><th>Description</th></tr>
                </thead>
                <tbody>
                    <tr><td><code class="inline-code">make</code></td><td>Create instance</td></tr>
                    <!-- TODO: Add more features -->
                </tbody>
            </table>
        </section>

        <section id="testing">
            <h2>Testing</h2>
            <p>Run the test suite:</p>
<pre><code>cd ${PROJECT_NAME}
ec.exe -batch -config ${PROJECT_NAME}.ecf -target ${PROJECT_NAME}_tests -c_compile
./EIFGENs/${PROJECT_NAME}_tests/F_code/${PROJECT_NAME}.exe</code></pre>
        </section>
    </main>

    <footer>
        <p><strong>${PROJECT_NAME}</strong> is part of the <a href="https://github.com/simple-eiffel">simple_*</a> ecosystem</p>
        <p>Copyright &copy; 2024-2025 Larry Rix. MIT License.</p>
        <p style="margin-top: 1rem; font-size: 0.85rem; opacity: 0.7;">Generated by <a href="https://github.com/simple-eiffel/simple_code">simple_codegen</a> - AI-assisted Eiffel code generation</p>
    </footer>
</body>
</html>
]"

end
