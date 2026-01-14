note
	description: "Simple Code Generator - Project Generator"
	purpose: "[
		Generates new simple_* style Eiffel project scaffolds including:
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
	make

feature {NONE} -- Initialization

	make
			-- Run the project generator.
		do
			parse_arguments
			if show_help then
				print_help
			elseif show_version then
				print_version
			elseif has_error then
				print_error
			else
				generate_project
			end
		end

feature {NONE} -- Argument Parsing

	parse_arguments
			-- Parse command line arguments.
		local
			i: INTEGER
		do
			create project_name.make_empty
			create target_directory.make_empty
			create error_message.make_empty
			show_help := False
			show_version := False
			has_error := False

			from
				i := 1
			until
				i > argument_count
			loop
				if attached argument (i) as arg then
					if arg.same_string ("--help") or arg.same_string ("-h") then
						show_help := True
					elseif arg.same_string ("--version") or arg.same_string ("-v") then
						show_version := True
					elseif arg.same_string ("--name") or arg.same_string ("-n") then
						i := i + 1
						if i <= argument_count and then attached argument (i) as name_arg then
							project_name := name_arg
						else
							has_error := True
							error_message := "--name requires a project name"
						end
					elseif arg.same_string ("--dir") or arg.same_string ("-d") then
						i := i + 1
						if i <= argument_count and then attached argument (i) as dir_arg then
							target_directory := dir_arg
						else
							has_error := True
							error_message := "--dir requires a directory path"
						end
					elseif not arg.starts_with ("-") and project_name.is_empty then
						project_name := arg
					else
						has_error := True
						error_message := "Unknown argument: " + arg
					end
				end
				i := i + 1
			end

			-- Validate required arguments
			if not show_help and not show_version and not has_error then
				if project_name.is_empty then
					has_error := True
					error_message := "Project name is required"
				end
			end
		end

feature {NONE} -- Commands

	print_help
			-- Print usage information.
		do
			print ("Simple Code Generator - Project Generator%N")
			print ("==========================================%N%N")
			print ("Usage: scg_project [OPTIONS] <project_name>%N%N")
			print ("Options:%N")
			print ("  -n, --name NAME    Project name (required)%N")
			print ("  -d, --dir PATH     Target directory (default: current)%N")
			print ("  -h, --help         Show this help message%N")
			print ("  -v, --version      Show version information%N%N")
			print ("Examples:%N")
			print ("  scg_project simple_foo%N")
			print ("  scg_project --name simple_bar --dir /d/prod%N%N")
			print ("Generated structure:%N")
			print ("  <project_name>/%N")
			print ("    +-- src/%N")
			print ("    |   +-- <project_name>.e%N")
			print ("    +-- testing/%N")
			print ("    |   +-- test_app.e%N")
			print ("    |   +-- lib_tests.e%N")
			print ("    +-- docs/%N")
			print ("    +-- <project_name>.ecf%N")
			print ("    +-- README.md%N")
			print ("    +-- CHANGELOG.md%N")
			print ("    +-- .gitignore%N")
		end

	print_version
			-- Print version information.
		do
			print ("scg_project version " + version_string + "%N")
		end

	print_error
			-- Print error message.
		do
			print ("Error: " + error_message + "%N")
			print ("Use --help for usage information.%N")
		end

	generate_project
			-- Generate the project structure.
		do
			print ("Generating project: " + project_name + "%N")
			if not target_directory.is_empty then
				print ("Target directory: " + target_directory + "%N")
			end
			print ("%N[Project generation not yet implemented]%N")
			-- TODO: Implement project generation
			-- 1. Create directory structure
			-- 2. Generate ECF file
			-- 3. Generate main class
			-- 4. Generate test scaffolding
			-- 5. Generate README, CHANGELOG, .gitignore
		end

feature {NONE} -- Implementation

	project_name: STRING
			-- Name of the project to generate

	target_directory: STRING
			-- Directory where project will be created

	show_help: BOOLEAN
			-- Should help be displayed?

	show_version: BOOLEAN
			-- Should version be displayed?

	has_error: BOOLEAN
			-- Was there a parsing error?

	error_message: STRING
			-- Error message if has_error

	version_string: STRING = "0.1.0"
			-- Generator version

feature {NONE} -- Arguments

	argument_count: INTEGER
			-- Number of command line arguments
		do
			Result := {EXECUTION_ENVIRONMENT}.arguments.argument_count
		end

	argument (i: INTEGER): detachable STRING
			-- Command line argument at position `i`
		require
			valid_index: i >= 1 and i <= argument_count
		local
			l_arg: detachable IMMUTABLE_STRING_32
		do
			l_arg := {EXECUTION_ENVIRONMENT}.arguments.argument (i)
			if attached l_arg as a then
				Result := a.to_string_8
			end
		end

end
