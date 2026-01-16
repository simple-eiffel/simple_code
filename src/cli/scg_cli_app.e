note
	description: "[
		Simple Code Generator CLI - Claude-in-the-Loop Code Generation.

		Commands:
			simple_codegen init --session <name> [--level system|class] [--class <CLASS_NAME>]
				Initialize a new generation session (default: system level)

			simple_codegen add-feature --session <name> --class <CLASS_NAME> --feature <name> --type <command|query>
				Generate prompt to add a feature to an existing class

			simple_codegen process --input <response.txt> --session <name>
				Process Claude's response, output next prompt

			simple_codegen validate --input <class.e>
				Validate generated Eiffel code

			simple_codegen refine --session <name> --class <CLASS_NAME> --issues "issue1;issue2"
				Generate refinement prompt for a class with issues

			simple_codegen compile --session <name> --project <path>
				Compile project and generate refinement prompt if errors

			simple_codegen generate-tests --session <name> --class <CLASS_NAME>
				Generate test class prompt (happy-path + edge-cases)

			simple_codegen assemble --session <name> --output <path>
				Assemble final project from session

			simple_codegen status --session <name>
				Show session status

			simple_codegen history --session <name> [--class <CLASS_NAME>]
				Show audit history from SQLite database

			simple_codegen reset --session <name> | --all
				Reset session files and audit history (for clean testing)

			simple_codegen research --session <name> --topic "topic" --scope <system|class|feature>
				Generate 7-step in-depth research prompt for Claude

			simple_codegen plan --session <name> --goal "goal" [--class <CLASS_NAME>]
				Generate design-build-implement-test planning prompt

			simple_codegen run-tests --session <name> --project <path>
				Run tests and generate refinement prompts for failures

			simple_codegen c-integrate --session <name> --mode <wrap|library|win32> --target "description"
				Generate C/C++ integration prompt (inline C, library wrapping, Win32 API)

		Example workflow:
			1. simple_codegen init --session library_system
			2. Copy system prompt to Claude, get response
			3. simple_codegen process --input response.txt --session library_system
			4. Repeat step 2-3 until all classes generated
			5. simple_codegen validate --input generated_class.e
			6. If issues: simple_codegen refine --session library_system --class CLASS_NAME --issues "..."
			7. Process refinement response, repeat until valid
			8. simple_codegen assemble --session library_system --output ./output
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_CLI_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run the CLI application.
		local
			l_args: ARGUMENTS_32
		do
			create l_args
			create last_error.make_empty

			if l_args.argument_count < 1 then
				print_usage
			else
				process_command (l_args)
			end
		end

feature -- Status

	is_success: BOOLEAN
			-- Did last command succeed?

	last_error: STRING_32
			-- Error message from last failed command

feature {NONE} -- Command Processing

	process_command (a_args: ARGUMENTS_32)
			-- Process command line arguments.
		require
			args_not_void: a_args /= Void
			has_command: a_args.argument_count >= 1
		local
			l_command: STRING_32
		do
			l_command := a_args.argument (1)

			if l_command.is_case_insensitive_equal ("init") then
				handle_init (a_args)
			elseif l_command.is_case_insensitive_equal ("add-feature") then
				handle_add_feature (a_args)
			elseif l_command.is_case_insensitive_equal ("process") then
				handle_process (a_args)
			elseif l_command.is_case_insensitive_equal ("validate") then
				handle_validate (a_args)
			elseif l_command.is_case_insensitive_equal ("refine") then
				handle_refine (a_args)
			elseif l_command.is_case_insensitive_equal ("compile") then
				handle_compile (a_args)
			elseif l_command.is_case_insensitive_equal ("generate-tests") then
				handle_generate_tests (a_args)
			elseif l_command.is_case_insensitive_equal ("assemble") then
				handle_assemble (a_args)
			elseif l_command.is_case_insensitive_equal ("status") then
				handle_status (a_args)
			elseif l_command.is_case_insensitive_equal ("history") then
				handle_history (a_args)
			elseif l_command.is_case_insensitive_equal ("reset") then
				handle_reset (a_args)
			elseif l_command.is_case_insensitive_equal ("research") then
				handle_research (a_args)
			elseif l_command.is_case_insensitive_equal ("plan") then
				handle_plan (a_args)
			elseif l_command.is_case_insensitive_equal ("run-tests") then
				handle_run_tests (a_args)
			elseif l_command.is_case_insensitive_equal ("c-integrate") then
				handle_c_integrate (a_args)
			elseif l_command.is_case_insensitive_equal ("inno-install") then
				handle_inno_install (a_args)
			elseif l_command.is_case_insensitive_equal ("git-context") then
				handle_git_context (a_args)
			elseif l_command.is_case_insensitive_equal ("--help") or l_command.is_case_insensitive_equal ("-h") then
				print_usage
			else
				print ("Unknown command: " + l_command.to_string_8 + "%N")
				print_usage
			end
		end

	handle_init (a_args: ARGUMENTS_32)
			-- Handle 'init --session <name>' command.
		local
			l_session_name: detachable STRING_32
			l_session: SCG_SESSION
		do
			l_session_name := get_option_value (a_args, "--session")

			if attached l_session_name as l_name then
				create l_session.make_new (l_name)
				if l_session.is_valid then
					is_success := True
					print ("[OK] Session initialized: " + l_name.to_string_8 + "%N")
					print ("Session path: " + l_session.session_path.to_string_8 + "%N")
					print ("%NNext step: Copy the system design prompt to Claude:%N")
					print ("  " + l_session.prompts_path.to_string_8 + "/001_system_design.txt%N")
				else
					is_success := False
					last_error := l_session.last_error
					print ("[ERROR] " + last_error.to_string_8 + "%N")
				end
			else
				print ("[ERROR] Missing --session option%N")
				print ("Usage: simple_codegen init --session <name>%N")
			end
		end

	handle_add_feature (a_args: ARGUMENTS_32)
			-- Handle 'add-feature --session <name> --class <CLASS> --feature <name> --type <command|query>' command.
		local
			l_session_name, l_class_name, l_feature_name, l_feature_type, l_description: detachable STRING_32
			l_session: SCG_SESSION
			l_builder: SCG_PROMPT_BUILDER
			l_code: detachable STRING_32
			l_prompt: STRING_32
		do
			l_session_name := get_option_value (a_args, "--session")
			l_class_name := get_option_value (a_args, "--class")
			l_feature_name := get_option_value (a_args, "--feature")
			l_feature_type := get_option_value (a_args, "--type")
			l_description := get_option_value (a_args, "--description")

			if not attached l_session_name then
				print ("[ERROR] Missing --session option%N")
				print ("Usage: simple_codegen add-feature --session <name> --class <CLASS> --feature <name> --type <command|query>%N")
			elseif not attached l_class_name then
				print ("[ERROR] Missing --class option%N")
				print ("Usage: simple_codegen add-feature --session <name> --class <CLASS> --feature <name> --type <command|query>%N")
			elseif not attached l_feature_name then
				print ("[ERROR] Missing --feature option%N")
				print ("Usage: simple_codegen add-feature --session <name> --class <CLASS> --feature <name> --type <command|query>%N")
			elseif not attached l_feature_type then
				print ("[ERROR] Missing --type option (command or query)%N")
				print ("Usage: simple_codegen add-feature --session <name> --class <CLASS> --feature <name> --type <command|query>%N")
			else
				-- Load session
				create l_session.make_from_existing (l_session_name)
				if not l_session.is_valid then
					print ("[ERROR] Invalid session: " + l_session.last_error.to_string_8 + "%N")
				else
					-- Find existing class code (if any)
					across l_session.class_specs as ic loop
						if ic.name.is_case_insensitive_equal (l_class_name) and then ic.is_generated then
							l_code := ic.generated_code
						end
					end

					-- Build feature prompt
					create l_builder.make (l_session)
					if not attached l_description then
						l_description := ""
					end
					l_prompt := l_builder.build_feature_prompt (l_class_name, l_feature_name, l_feature_type, l_description, l_code)

					-- Save to session
					l_session.save_next_prompt (l_prompt)
					print ("[OK] Feature generation prompt created%N")
					print ("  Class: " + l_class_name.to_string_8 + "%N")
					print ("  Feature: " + l_feature_name.to_string_8 + " (" + l_feature_type.to_string_8 + ")%N")
					if attached l_code then
						print ("  Mode: Modify existing class%N")
					else
						print ("  Mode: New feature (class will be created)%N")
					end
					print ("%NNext step: Copy the prompt to Claude:%N")
					print ("  " + l_session.last_prompt_path.to_string_8 + "%N")
					is_success := True
				end
			end
		end

	handle_process (a_args: ARGUMENTS_32)
			-- Handle 'process --input <file> [--output <file>]' command.
		local
			l_input, l_output: detachable STRING_32
			l_session_name: detachable STRING_32
			l_session: SCG_SESSION
			l_parser: SCG_RESPONSE_PARSER
			l_builder: SCG_PROMPT_BUILDER
			l_file: SIMPLE_FILE
			l_content: STRING_32
			l_next_prompt: STRING_32
		do
			l_input := get_option_value (a_args, "--input")
			l_output := get_option_value (a_args, "--output")
			l_session_name := get_option_value (a_args, "--session")

			if not attached l_input then
				print ("[ERROR] Missing --input option%N")
				print ("Usage: simple_codegen process --input <response.txt> [--session <name>] [--output <prompt.txt>]%N")
			elseif not attached l_session_name then
				print ("[ERROR] Missing --session option%N")
				print ("Usage: simple_codegen process --input <response.txt> --session <name> [--output <prompt.txt>]%N")
			else
				-- Load session
				create l_session.make_from_existing (l_session_name)
				if not l_session.is_valid then
					print ("[ERROR] Invalid session: " + l_session.last_error.to_string_8 + "%N")
				else
					-- Read input file
					create l_file.make (l_input.to_string_8)
					if l_file.exists then
						l_content := l_file.read_text.to_string_32

						-- Parse response
						create l_parser.make
						l_parser.parse (l_content, l_session)

						if l_parser.is_success then
							print ("[OK] Parsed response%N")
							print ("  Type: " + l_parser.response_type.to_string_8 + "%N")

							if attached l_parser.parsed_class_name as l_cn then
								print ("  Class: " + l_cn.to_string_8 + "%N")
							end

							-- Save response to session
							l_session.add_response (l_content, l_parser.response_type)

							-- Build next prompt if more work needed
							if l_session.has_pending_work then
								create l_builder.make (l_session)
								l_next_prompt := l_builder.build_next_prompt

								if attached l_output as l_out then
									create l_file.make (l_out.to_string_8)
									if l_file.write_text (l_next_prompt.to_string_8) then
										print ("[OK] Next prompt written to: " + l_out.to_string_8 + "%N")
									else
										print ("[ERROR] Failed to write prompt file%N")
									end
								else
									-- Write to session prompts directory
									l_session.save_next_prompt (l_next_prompt)
									print ("[OK] Next prompt saved to session%N")
									print ("  " + l_session.last_prompt_path.to_string_8 + "%N")
								end
							else
								print ("%N[DONE] All classes generated. Ready for assembly.%N")
								print ("Run: simple_codegen assemble --session " + l_session_name.to_string_8 + " --output <path>%N")
							end

							is_success := True
						else
							print ("[ERROR] Failed to parse response: " + l_parser.last_error.to_string_8 + "%N")
						end
					else
						print ("[ERROR] Input file not found: " + l_input.to_string_8 + "%N")
					end
				end
			end
		end

	handle_validate (a_args: ARGUMENTS_32)
			-- Handle 'validate --input <file>' command.
		local
			l_input: detachable STRING_32
			l_validator: SCG_VALIDATOR
			l_file: SIMPLE_FILE
			l_content: STRING_32
		do
			l_input := get_option_value (a_args, "--input")

			if attached l_input as l_in then
				create l_file.make (l_in.to_string_8)
				if l_file.exists then
					l_content := l_file.read_text.to_string_32

					create l_validator.make
					l_validator.validate (l_content)

					print ("Validation results for: " + l_in.to_string_8 + "%N")
					print ("========================%N")

					-- Syntax check
					if l_validator.syntax_valid then
						print ("[PASS] Syntax valid%N")
					else
						print ("[FAIL] Syntax errors:%N")
						across l_validator.syntax_errors as ic loop
							print ("  - " + ic.to_string_8 + "%N")
						end
					end

					-- Contract check
					print ("%NContract Analysis:%N")
					print ("  Features with preconditions: " + l_validator.features_with_preconditions.out + "%N")
					print ("  Features with postconditions: " + l_validator.features_with_postconditions.out + "%N")
					print ("  Has class invariant: " + l_validator.has_invariant.out + "%N")

					if l_validator.contract_warnings.count > 0 then
						print ("%NContract warnings:%N")
						across l_validator.contract_warnings as ic loop
							print ("  - " + ic.to_string_8 + "%N")
						end
					end

					-- Completeness check
					if l_validator.is_complete then
						print ("%N[PASS] Completeness check passed%N")
					else
						print ("%N[WARN] Completeness issues:%N")
						across l_validator.completeness_issues as ic loop
							print ("  - " + ic.to_string_8 + "%N")
						end
					end

					-- Overall result
					print ("%N")
					if l_validator.is_valid then
						print ("[OVERALL] VALID - Ready for use%N")
						is_success := True
					else
						print ("[OVERALL] NEEDS REFINEMENT%N")
						if l_validator.needs_refinement_prompt then
							print ("%NRefinement prompt generated.%N")
						end
					end
				else
					print ("[ERROR] File not found: " + l_in.to_string_8 + "%N")
				end
			else
				print ("[ERROR] Missing --input option%N")
				print ("Usage: simple_codegen validate --input <class.e>%N")
			end
		end

	handle_refine (a_args: ARGUMENTS_32)
			-- Handle 'refine --session <name> --class <CLASS_NAME> --issues "issue1;issue2"' command.
		local
			l_session_name, l_class_name, l_issues_str: detachable STRING_32
			l_session: SCG_SESSION
			l_builder: SCG_PROMPT_BUILDER
			l_issues: ARRAYED_LIST [STRING_32]
			l_code: detachable STRING_32
			l_prompt: STRING_32
			l_parts: LIST [STRING_32]
		do
			l_session_name := get_option_value (a_args, "--session")
			l_class_name := get_option_value (a_args, "--class")
			l_issues_str := get_option_value (a_args, "--issues")

			if not attached l_session_name then
				print ("[ERROR] Missing --session option%N")
				print ("Usage: simple_codegen refine --session <name> --class <CLASS_NAME> --issues %"issue1;issue2%"%N")
			elseif not attached l_class_name then
				print ("[ERROR] Missing --class option%N")
				print ("Usage: simple_codegen refine --session <name> --class <CLASS_NAME> --issues %"issue1;issue2%"%N")
			elseif not attached l_issues_str then
				print ("[ERROR] Missing --issues option%N")
				print ("Usage: simple_codegen refine --session <name> --class <CLASS_NAME> --issues %"issue1;issue2%"%N")
			else
				-- Load session
				create l_session.make_from_existing (l_session_name)
				if not l_session.is_valid then
					print ("[ERROR] Invalid session: " + l_session.last_error.to_string_8 + "%N")
				else
					-- Find the class code
					across l_session.class_specs as ic loop
						if ic.name.is_case_insensitive_equal (l_class_name) and then ic.is_generated then
							l_code := ic.generated_code
						end
					end

					if not attached l_code as l_c then
						print ("[ERROR] Class not found or not yet generated: " + l_class_name.to_string_8 + "%N")
					else
						-- Parse issues (semicolon separated)
						create l_issues.make (5)
						l_parts := l_issues_str.split (';')
						across l_parts as ic loop
							ic.left_adjust
							ic.right_adjust
							if not ic.is_empty then
								l_issues.extend (ic)
							end
						end

						if l_issues.is_empty then
							print ("[ERROR] No issues provided%N")
						else
							-- Build refinement prompt
							create l_builder.make (l_session)
							l_prompt := l_builder.build_refinement_prompt (l_class_name, l_issues, l_c)

							-- Save to session
							l_session.save_next_prompt (l_prompt)
							print ("[OK] Refinement prompt generated%N")
							print ("  Class: " + l_class_name.to_string_8 + "%N")
							print ("  Issues: " + l_issues.count.out + "%N")
							across l_issues as ic_issue loop
								print ("    - " + ic_issue.to_string_8 + "%N")
							end
							print ("%NNext step: Copy the prompt to Claude:%N")
							print ("  " + l_session.last_prompt_path.to_string_8 + "%N")
							is_success := True
						end
					end
				end
			end
		end

	handle_compile (a_args: ARGUMENTS_32)
			-- Handle 'compile --session <name> --project <path>' command.
			-- Runs ec.exe and generates refinement prompt if errors found.
		local
			l_session_name, l_project_path: detachable STRING_32
			l_session: SCG_SESSION
			l_process: SIMPLE_PROCESS
			l_output, l_ecf_path: STRING
			l_errors: ARRAYED_LIST [STRING_32]
			l_class_errors: HASH_TABLE [ARRAYED_LIST [STRING_32], STRING_32]
			l_builder: SCG_PROMPT_BUILDER
			l_prompt: STRING_32
			l_current_class: detachable STRING_32
			l_code: detachable STRING_32
		do
			l_session_name := get_option_value (a_args, "--session")
			l_project_path := get_option_value (a_args, "--project")

			if not attached l_session_name then
				print ("[ERROR] Missing --session option%N")
				print ("Usage: simple_codegen compile --session <name> --project <path>%N")
			elseif not attached l_project_path then
				print ("[ERROR] Missing --project option%N")
				print ("Usage: simple_codegen compile --session <name> --project <path>%N")
			else
				-- Load session
				create l_session.make_from_existing (l_session_name)
				if not l_session.is_valid then
					print ("[ERROR] Invalid session: " + l_session.last_error.to_string_8 + "%N")
				else
					-- Find ECF file
					l_ecf_path := l_project_path.to_string_8 + "/" + l_session_name.to_string_8 + ".ecf"

					-- Run compiler
					print ("[INFO] Compiling project...%N")
					create l_process.make
					l_process.run_in_directory ("ec.exe -batch -config " + l_ecf_path + " -c_compile", l_project_path.to_string_8)

					if attached l_process.last_output as l_out then
						l_output := l_out.to_string_8
						if l_output.has_substring ("System Recompiled") then
							print ("[OK] Compilation successful%N")
							is_success := True
						else
							-- Parse errors and group by class
							create l_class_errors.make (5)
							create l_errors.make (10)
							l_current_class := Void

							across l_output.split ('%N') as ic loop
								if ic.has_substring ("Class:") then
									l_current_class := extract_class_name (ic)
								elseif ic.has_substring ("Error code:") or ic.has_substring ("Line:") then
									if attached l_current_class as l_cls then
										if not l_class_errors.has (l_cls) then
											l_class_errors.put (create {ARRAYED_LIST [STRING_32]}.make (5), l_cls)
										end
										if attached l_class_errors.item (l_cls) as l_list then
											l_list.extend (ic.to_string_32)
										end
									else
										l_errors.extend (ic.to_string_32)
									end
								end
							end

							-- Generate refinement prompts for each class with errors
							if l_class_errors.count > 0 then
								print ("[FAIL] Compilation errors in " + l_class_errors.count.out + " class(es)%N")
								create l_builder.make (l_session)

								from l_class_errors.start until l_class_errors.after loop
									if attached l_class_errors.key_for_iteration as l_err_class and then
									   attached l_class_errors.item_for_iteration as l_err_list then
										print ("  - " + l_err_class.to_string_8 + ": " + l_err_list.count.out + " error(s)%N")

										-- Find class code
										l_code := Void
										across l_session.class_specs as ic_spec loop
											if ic_spec.name.is_case_insensitive_equal (l_err_class) then
												l_code := ic_spec.generated_code
											end
										end

										if attached l_code as l_c then
											l_prompt := l_builder.build_refinement_prompt (l_err_class, l_err_list, l_c)
											l_session.save_next_prompt (l_prompt)
											print ("    Refinement prompt: " + l_session.last_prompt_path.to_string_8 + "%N")
										end
									end
									l_class_errors.forth
								end
							else
								print ("[FAIL] Compilation failed (see output)%N")
								print (l_output + "%N")
							end
						end
					else
						print ("[ERROR] No compiler output - check if ec.exe is available%N")
					end
				end
			end
		end

	extract_class_name (a_line: STRING): detachable STRING_32
			-- Extract class name from compiler output line like "Class: MY_CLASS"
		local
			l_pos: INTEGER
		do
			l_pos := a_line.substring_index ("Class:", 1)
			if l_pos > 0 then
				Result := a_line.substring (l_pos + 6, a_line.count).to_string_32
				Result.left_adjust
				Result.right_adjust
			end
		end

	handle_generate_tests (a_args: ARGUMENTS_32)
			-- Handle 'generate-tests --session <name> --class <CLASS_NAME>' command.
		local
			l_session_name, l_class_name: detachable STRING_32
			l_session: SCG_SESSION
			l_builder: SCG_PROMPT_BUILDER
			l_code: detachable STRING_32
			l_prompt: STRING_32
		do
			l_session_name := get_option_value (a_args, "--session")
			l_class_name := get_option_value (a_args, "--class")

			if not attached l_session_name then
				print ("[ERROR] Missing --session option%N")
				print ("Usage: simple_codegen generate-tests --session <name> --class <CLASS_NAME>%N")
			elseif not attached l_class_name then
				print ("[ERROR] Missing --class option%N")
				print ("Usage: simple_codegen generate-tests --session <name> --class <CLASS_NAME>%N")
			else
				-- Load session
				create l_session.make_from_existing (l_session_name)
				if not l_session.is_valid then
					print ("[ERROR] Invalid session: " + l_session.last_error.to_string_8 + "%N")
				else
					-- Find the class code
					across l_session.class_specs as ic loop
						if ic.name.is_case_insensitive_equal (l_class_name) and then ic.is_generated then
							l_code := ic.generated_code
						end
					end

					if not attached l_code as l_c then
						print ("[ERROR] Class not found or not yet generated: " + l_class_name.to_string_8 + "%N")
					else
						-- Build test generation prompt
						create l_builder.make (l_session)
						l_prompt := l_builder.build_test_prompt (l_class_name, l_c)

						-- Save to session
						l_session.save_next_prompt (l_prompt)
						print ("[OK] Test generation prompt created%N")
						print ("  Target class: " + l_class_name.to_string_8 + "%N")
						print ("%NNext step: Copy the prompt to Claude:%N")
						print ("  " + l_session.last_prompt_path.to_string_8 + "%N")
						is_success := True
					end
				end
			end
		end

	handle_assemble (a_args: ARGUMENTS_32)
			-- Handle 'assemble --session <name> --output <path>' command.
		local
			l_session_name, l_output: detachable STRING_32
			l_session: SCG_SESSION
		do
			l_session_name := get_option_value (a_args, "--session")
			l_output := get_option_value (a_args, "--output")

			if not attached l_session_name then
				print ("[ERROR] Missing --session option%N")
				print ("Usage: simple_codegen assemble --session <name> --output <path>%N")
			elseif not attached l_output then
				print ("[ERROR] Missing --output option%N")
				print ("Usage: simple_codegen assemble --session <name> --output <path>%N")
			else
				create l_session.make_from_existing (l_session_name)
				if l_session.is_valid then
					l_session.assemble_project (l_output)
					if l_session.is_assembled then
						print ("[OK] Project assembled at: " + l_output.to_string_8 + "%N")
						print ("Generated files:%N")
						across l_session.generated_files as ic loop
							print ("  " + ic.to_string_8 + "%N")
						end
						is_success := True
					else
						print ("[ERROR] Assembly failed: " + l_session.last_error.to_string_8 + "%N")
					end
				else
					print ("[ERROR] Session not found: " + l_session_name.to_string_8 + "%N")
				end
			end
		end

	handle_status (a_args: ARGUMENTS_32)
			-- Handle 'status --session <name>' command.
		local
			l_session_name: detachable STRING_32
			l_session: SCG_SESSION
		do
			l_session_name := get_option_value (a_args, "--session")

			if attached l_session_name as l_name then
				create l_session.make_from_existing (l_name)
				if l_session.is_valid then
					print ("Session: " + l_name.to_string_8 + "%N")
					print ("==========%N")
					print ("State: " + l_session.state.to_string_8 + "%N")
					print ("Iteration: " + l_session.iteration.out + "%N")
					print ("%NClasses:%N")
					across l_session.class_specs as ic loop
						print ("  - " + ic.name.to_string_8)
						if ic.is_generated then
							print (" [GENERATED]")
						else
							print (" [PENDING]")
						end
						print ("%N")
					end
					print ("%NPrompts: " + l_session.prompt_count.out + "%N")
					print ("Responses: " + l_session.response_count.out + "%N")
					is_success := True
				else
					print ("[ERROR] Session not found: " + l_name.to_string_8 + "%N")
				end
			else
				print ("[ERROR] Missing --session option%N")
				print ("Usage: simple_codegen status --session <name>%N")
			end
		end

	handle_history (a_args: ARGUMENTS_32)
			-- Handle 'history --session <name> [--class <CLASS_NAME>]' command.
			-- Shows audit history from SQLite database.
		local
			l_session_name, l_class_name: detachable STRING_32
			l_audit_db: SCG_AUDIT_DB
			l_db_path: STRING
			l_history: ARRAYED_LIST [TUPLE [id: INTEGER; artifact_type: STRING_32; subtype: STRING_32; class_name: detachable STRING_32; created_at: STRING_32]]
			l_class_history: ARRAYED_LIST [TUPLE [id: INTEGER; artifact_type: STRING_32; iteration: INTEGER; created_at: STRING_32]]
			l_stats: TUPLE [prompts: INTEGER; responses: INTEGER; classes: INTEGER; refinements: INTEGER; compiles: INTEGER]
			l_sessions: ARRAYED_LIST [STRING_32]
		do
			l_session_name := get_option_value (a_args, "--session")
			l_class_name := get_option_value (a_args, "--class")

			-- Open audit database
			l_db_path := "sessions/scg_audit.db"
			create l_audit_db.make (l_db_path)

			if not l_audit_db.is_open then
				print ("[ERROR] Cannot open audit database: " + l_db_path + "%N")
			elseif not attached l_session_name then
				-- List all sessions
				print ("Audit Database Sessions%N")
				print ("=======================%N")
				l_sessions := l_audit_db.get_all_sessions
				if l_sessions.is_empty then
					print ("  (no sessions recorded)%N")
				else
					across l_sessions as ic loop
						l_stats := l_audit_db.get_session_stats (ic)
						print ("  " + ic.to_string_8 + "%N")
						print ("    prompts: " + l_stats.prompts.out)
						print (", responses: " + l_stats.responses.out)
						print (", classes: " + l_stats.classes.out)
						print (", refinements: " + l_stats.refinements.out)
						print (", compiles: " + l_stats.compiles.out + "%N")
					end
				end
				is_success := True
			elseif attached l_class_name as l_cls then
				-- Show class-specific history
				print ("Audit History: " + l_session_name.to_string_8 + " / " + l_cls.to_string_8 + "%N")
				print (create {STRING}.make_filled ('=', 50) + "%N")
				l_class_history := l_audit_db.get_class_history (l_session_name, l_cls)
				if l_class_history.is_empty then
					print ("  (no artifacts for this class)%N")
				else
					across l_class_history as ic loop
						print ("  [" + ic.id.out + "] ")
						print (ic.artifact_type.to_string_8)
						print (" (iter " + ic.iteration.out + ")")
						print (" @ " + ic.created_at.to_string_8 + "%N")
					end
					print ("%NUse artifact ID to retrieve content/code.%N")
				end
				is_success := True
			else
				-- Show session history
				print ("Audit History: " + l_session_name.to_string_8 + "%N")
				print (create {STRING}.make_filled ('=', 40) + "%N")

				-- Stats first
				l_stats := l_audit_db.get_session_stats (l_session_name)
				print ("Summary: ")
				print (l_stats.prompts.out + " prompts, ")
				print (l_stats.responses.out + " responses, ")
				print (l_stats.classes.out + " classes, ")
				print (l_stats.refinements.out + " refinements, ")
				print (l_stats.compiles.out + " compiles%N%N")

				-- Timeline
				l_history := l_audit_db.get_session_history (l_session_name)
				if l_history.is_empty then
					print ("  (no artifacts recorded)%N")
				else
					print ("Timeline:%N")
					across l_history as ic loop
						print ("  [" + ic.id.out + "] ")
						print (ic.artifact_type.to_string_8)
						if attached ic.subtype as l_sub then
							print (":" + l_sub.to_string_8)
						end
						if attached ic.class_name as l_cn then
							print (" (" + l_cn.to_string_8 + ")")
						end
						print (" @ " + ic.created_at.to_string_8 + "%N")
					end
				end
				is_success := True
			end

			if l_audit_db.is_open then
				l_audit_db.close
			end
		end

	handle_reset (a_args: ARGUMENTS_32)
			-- Handle 'reset --session <name> | --all' command.
			-- Resets session files and audit history for clean testing.
		local
			l_session_name: detachable STRING_32
			l_all: BOOLEAN
			l_audit_db: SCG_AUDIT_DB
			l_db_path: STRING
			l_session: SCG_SESSION
			l_dir: DIRECTORY
		do
			l_session_name := get_option_value (a_args, "--session")
			l_all := has_flag (a_args, "--all")

			if not l_all and not attached l_session_name then
				print ("[ERROR] Missing --session or --all option%N")
				print ("Usage: simple_codegen reset --session <name>%N")
				print ("       simple_codegen reset --all%N")
			else
				-- Open audit database
				l_db_path := "sessions/scg_audit.db"
				create l_audit_db.make (l_db_path)

				if l_all then
					-- Reset everything
					print ("[RESET] Clearing all sessions...%N")

					-- Clear audit database
					if l_audit_db.is_open then
						l_audit_db.reset_all
						l_audit_db.vacuum
						print ("  - Audit database cleared%N")
					end

					-- Remove sessions directory contents
					create l_dir.make ("sessions")
					if l_dir.exists then
						-- Note: We keep the directory but clear session subdirectories
						-- In a full implementation, iterate and delete each session folder
						print ("  - Session directories (manual cleanup may be needed)%N")
					end

					print ("[OK] All audit data reset%N")
					is_success := True

				elseif attached l_session_name as l_name then
					-- Reset specific session
					print ("[RESET] Clearing session: " + l_name.to_string_8 + "%N")

					-- Clear from audit database
					if l_audit_db.is_open then
						l_audit_db.reset_session (l_name)
						print ("  - Audit records cleared%N")
					end

					-- Reset session files
					create l_session.make_from_existing (l_name)
					if l_session.is_valid then
						l_session.reset
						print ("  - Session files cleared%N")
					else
						print ("  - Session directory not found (may already be clean)%N")
					end

					print ("[OK] Session reset: " + l_name.to_string_8 + "%N")
					is_success := True
				end

				if l_audit_db.is_open then
					l_audit_db.close
				end
			end
		end

	handle_research (a_args: ARGUMENTS_32)
			-- Handle 'research --session <name> --topic "topic" --scope <system|class|feature>' command.
			-- Generates 7-step in-depth research prompt.
		local
			l_session_name, l_topic, l_scope: detachable STRING_32
			l_session: SCG_SESSION
			l_builder: SCG_PROMPT_BUILDER
			l_prompt: STRING_32
		do
			l_session_name := get_option_value (a_args, "--session")
			l_topic := get_option_value (a_args, "--topic")
			l_scope := get_option_value (a_args, "--scope")

			if not attached l_session_name then
				print ("[ERROR] Missing --session option%N")
				print ("Usage: simple_codegen research --session <name> --topic %"topic%" --scope <system|class|feature>%N")
			elseif not attached l_topic then
				print ("[ERROR] Missing --topic option%N")
				print ("Usage: simple_codegen research --session <name> --topic %"topic%" --scope <system|class|feature>%N")
			else
				-- Default scope to system if not specified
				if not attached l_scope then
					l_scope := "system"
				end

				-- Load session
				create l_session.make_from_existing (l_session_name)
				if not l_session.is_valid then
					print ("[ERROR] Invalid session: " + l_session.last_error.to_string_8 + "%N")
				else
					-- Build research prompt
					create l_builder.make (l_session)
					l_prompt := l_builder.build_research_prompt (l_topic, l_scope)

					-- Save to session
					l_session.save_next_prompt (l_prompt)
					print ("[OK] Research prompt generated%N")
					print ("  Topic: " + l_topic.to_string_8 + "%N")
					print ("  Scope: " + l_scope.to_string_8 + "%N")
					print ("%N7-Step Research Process:%N")
					print ("  1. Understand the problem/domain%N")
					print ("  2. Research existing solutions%N")
					print ("  3. Identify requirements/constraints%N")
					print ("  4. Evaluate options/trade-offs%N")
					print ("  5. Design approach%N")
					print ("  6. Document decisions%N")
					print ("  7. Create implementation plan%N")
					print ("%NNext step: Copy the prompt to Claude:%N")
					print ("  " + l_session.last_prompt_path.to_string_8 + "%N")
					is_success := True
				end
			end
		end

	handle_plan (a_args: ARGUMENTS_32)
			-- Handle 'plan --session <name> --goal "goal" [--class <CLASS_NAME>]' command.
			-- Generates design-build-implement-test planning prompt.
		local
			l_session_name, l_goal, l_class_name: detachable STRING_32
			l_session: SCG_SESSION
			l_builder: SCG_PROMPT_BUILDER
			l_prompt: STRING_32
			l_code: detachable STRING_32
		do
			l_session_name := get_option_value (a_args, "--session")
			l_goal := get_option_value (a_args, "--goal")
			l_class_name := get_option_value (a_args, "--class")

			if not attached l_session_name then
				print ("[ERROR] Missing --session option%N")
				print ("Usage: simple_codegen plan --session <name> --goal %"goal%" [--class <CLASS_NAME>]%N")
			elseif not attached l_goal then
				print ("[ERROR] Missing --goal option%N")
				print ("Usage: simple_codegen plan --session <name> --goal %"goal%" [--class <CLASS_NAME>]%N")
			else
				-- Load session
				create l_session.make_from_existing (l_session_name)
				if not l_session.is_valid then
					print ("[ERROR] Invalid session: " + l_session.last_error.to_string_8 + "%N")
				else
					-- Find class code if specified
					if attached l_class_name as l_cn then
						across l_session.class_specs as ic loop
							if ic.name.is_case_insensitive_equal (l_cn) and then ic.is_generated then
								l_code := ic.generated_code
							end
						end
					end

					-- Build planning prompt
					create l_builder.make (l_session)
					l_prompt := l_builder.build_plan_prompt (l_goal, l_class_name, l_code)

					-- Save to session
					l_session.save_next_prompt (l_prompt)
					print ("[OK] Planning prompt generated%N")
					print ("  Goal: " + l_goal.to_string_8 + "%N")
					if attached l_class_name as l_cn then
						print ("  Class: " + l_cn.to_string_8 + "%N")
					else
						print ("  Scope: System-wide%N")
					end
					print ("%NPlanning Phases:%N")
					print ("  1. DESIGN - Architecture and contracts%N")
					print ("  2. BUILD - Implementation%N")
					print ("  3. IMPLEMENT - Integration%N")
					print ("  4. TEST - Verification%N")
					print ("%NNext step: Copy the prompt to Claude:%N")
					print ("  " + l_session.last_prompt_path.to_string_8 + "%N")
					is_success := True
				end
			end
		end

	handle_run_tests (a_args: ARGUMENTS_32)
			-- Handle 'run-tests --session <name> --project <path>' command.
			-- Runs tests and generates refinement prompts for failures.
		local
			l_session_name, l_project_path: detachable STRING_32
			l_session: SCG_SESSION
			l_process: SIMPLE_PROCESS
			l_output, l_test_exe: STRING
			l_failures: ARRAYED_LIST [TUPLE [test_name: STRING_32; class_name: STRING_32; message: STRING_32]]
			l_builder: SCG_PROMPT_BUILDER
			l_issues: ARRAYED_LIST [STRING_32]
			l_prompt: STRING_32
			l_code: detachable STRING_32
		do
			l_session_name := get_option_value (a_args, "--session")
			l_project_path := get_option_value (a_args, "--project")

			if not attached l_session_name then
				print ("[ERROR] Missing --session option%N")
				print ("Usage: simple_codegen run-tests --session <name> --project <path>%N")
			elseif not attached l_project_path then
				print ("[ERROR] Missing --project option%N")
				print ("Usage: simple_codegen run-tests --session <name> --project <path>%N")
			else
				-- Load session
				create l_session.make_from_existing (l_session_name)
				if not l_session.is_valid then
					print ("[ERROR] Invalid session: " + l_session.last_error.to_string_8 + "%N")
				else
					-- Locate test executable (W_code for development testing)
					l_test_exe := l_project_path.to_string_8 + "/EIFGENs/" + l_session_name.to_string_8 + "_tests/W_code/" + l_session_name.to_string_8 + "_tests.exe"

					print ("[INFO] Running tests...%N")
					print ("  Executable: " + l_test_exe + "%N")

					create l_process.make
					l_process.run_in_directory (l_test_exe, l_project_path.to_string_8)

					if attached l_process.last_output as l_out then
						l_output := l_out.to_string_8
						create l_failures.make (5)

						-- Parse test output for failures
						across l_output.split ('%N') as ic loop
							if ic.has_substring ("FAILED") or ic.has_substring ("Error:") or ic.has_substring ("Assertion violated") then
								-- Extract test name and failure info
								l_failures.extend ([extract_test_name (ic), extract_class_from_test (ic), ic.to_string_32])
							end
						end

						if l_failures.is_empty then
							print ("[OK] All tests passed!%N")
							is_success := True
						else
							print ("[FAIL] " + l_failures.count.out + " test(s) failed%N%N")

							-- Generate refinement prompts for each failing class
							create l_builder.make (l_session)
							across l_failures as ic loop
								print ("  - " + ic.test_name.to_string_8 + " (class: " + ic.class_name.to_string_8 + ")%N")
								print ("    " + ic.message.to_string_8 + "%N")
							end

							-- Group failures by class and generate refinement prompts
							print ("%N[INFO] Generating refinement prompts for failing classes...%N")
							across l_failures as ic loop
								create l_issues.make (1)
								l_issues.extend ("Test '" + ic.test_name + "' failed: " + ic.message)

								-- Find class code
								l_code := Void
								across l_session.class_specs as ic_spec loop
									if ic_spec.name.is_case_insensitive_equal (ic.class_name) then
										l_code := ic_spec.generated_code
									end
								end

								if attached l_code as l_c then
									l_prompt := l_builder.build_refinement_prompt (ic.class_name, l_issues, l_c)
									l_session.save_next_prompt (l_prompt)
									print ("  Refinement prompt: " + l_session.last_prompt_path.to_string_8 + "%N")
								end
							end
						end
					else
						print ("[ERROR] No test output - check if test executable exists%N")
						print ("  Expected: " + l_test_exe + "%N")
						print ("%NBuild modes:%N")
						print ("  Development (W_code): ec.exe -batch -config <ecf> -target <name>_tests%N")
						print ("  Production (F_code): ec.exe -batch -config <ecf> -target <name>_tests -finalize -keep%N")
					end
				end
			end
		end

	extract_test_name (a_line: STRING): STRING_32
			-- Extract test name from test output line.
		do
			-- Pattern: test_xxx or test_xxx_yyy
			if a_line.has_substring ("test_") then
				Result := a_line.to_string_32
				-- Simplified: return the whole line for now
			else
				Result := "unknown_test"
			end
		end

	extract_class_from_test (a_line: STRING): STRING_32
			-- Extract class name from test failure output.
		local
			l_pos: INTEGER
		do
			-- Look for patterns like "Class: MY_CLASS" or "in MY_CLASS"
			l_pos := a_line.substring_index ("Class:", 1)
			if l_pos > 0 then
				Result := a_line.substring (l_pos + 6, a_line.count).to_string_32
				Result.left_adjust
				Result.right_adjust
			else
				-- Try to extract from test name (TEST_MY_CLASS -> MY_CLASS)
				if a_line.has_substring ("TEST_") then
					l_pos := a_line.substring_index ("TEST_", 1)
					Result := a_line.substring (l_pos + 5, a_line.count).to_string_32
					Result.left_adjust
					Result.right_adjust
				else
					Result := "UNKNOWN_CLASS"
				end
			end
		end

	handle_c_integrate (a_args: ARGUMENTS_32)
			-- Handle 'c-integrate --session <name> --mode <wrap|library|win32> --target "description"' command.
			-- Generates C/C++ integration prompt.
		local
			l_session_name, l_mode, l_target: detachable STRING_32
			l_session: SCG_SESSION
			l_builder: SCG_PROMPT_BUILDER
			l_prompt: STRING_32
			l_c_helper: SCG_C_INTEGRATION
		do
			l_session_name := get_option_value (a_args, "--session")
			l_mode := get_option_value (a_args, "--mode")
			l_target := get_option_value (a_args, "--target")

			if not attached l_session_name then
				print ("[ERROR] Missing --session option%N")
				print ("Usage: simple_codegen c-integrate --session <name> --mode <wrap|library|win32> --target %"description%"%N")
			elseif not attached l_mode then
				print ("[ERROR] Missing --mode option%N")
				print ("Modes: wrap (inline C externals), library (external C library), win32 (Win32 API)%N")
				print ("Usage: simple_codegen c-integrate --session <name> --mode <wrap|library|win32> --target %"description%"%N")
			elseif not attached l_target then
				print ("[ERROR] Missing --target option%N")
				print ("Usage: simple_codegen c-integrate --session <name> --mode <wrap|library|win32> --target %"description%"%N")
			else
				-- Load session
				create l_session.make_from_existing (l_session_name)
				if not l_session.is_valid then
					print ("[ERROR] Invalid session: " + l_session.last_error.to_string_8 + "%N")
				else
					-- Create C integration helper for reference
					create l_c_helper.make

					-- Build C integration prompt
					create l_builder.make (l_session)
					l_prompt := l_builder.build_c_integration_prompt (l_mode, l_target)

					-- Save to session
					l_session.save_next_prompt (l_prompt)
					print ("[OK] C/C++ integration prompt generated%N")
					print ("  Mode: " + l_mode.to_string_8 + "%N")
					print ("  Target: " + l_target.to_string_8 + "%N")

					print ("%NC/C++ Integration Modes:%N")
					if l_mode.is_case_insensitive_equal ("wrap") then
						print ("  WRAP - Generate Eiffel wrapper with inline C externals%N")
						print ("         Following Eric Bezault pattern (all C in Eiffel)%N")
					elseif l_mode.is_case_insensitive_equal ("library") then
						print ("  LIBRARY - Integrate existing C/C++ library%N")
						print ("            Generates ECF config + wrapper classes%N")
					elseif l_mode.is_case_insensitive_equal ("win32") then
						print ("  WIN32 - Wrap Win32 API functions%N")
						print ("          Uses <windows.h> with proper type mapping%N")
					end

					print ("%NKey Principles:%N")
					print ("  1. ALL C code in inline externals - NO separate .c files%N")
					print ("  2. Use MANAGED_POINTER for memory crossing boundaries%N")
					print ("  3. Wrap C functions with Eiffel contracts%N")
					print ("  4. Handle NULL with void safety patterns%N")

					print ("%NNext step: Copy the prompt to Claude:%N")
					print ("  " + l_session.last_prompt_path.to_string_8 + "%N")
					is_success := True
				end
			end
		end

	handle_inno_install (a_args: ARGUMENTS_32)
			-- Handle 'inno-install --session <name> --app <name> --version <ver> --exe <exe>' command.
			-- Generates INNO Setup installer script.
		local
			l_session_name, l_app_name, l_version, l_exe_name: detachable STRING_32
			l_publisher, l_icon: detachable STRING_32
			l_session: SCG_SESSION
			l_builder: SCG_PROMPT_BUILDER
			l_inno: SCG_INNO_BUILDER
			l_prompt, l_script: STRING_32
		do
			l_session_name := get_option_value (a_args, "--session")
			l_app_name := get_option_value (a_args, "--app")
			l_version := get_option_value (a_args, "--version")
			l_exe_name := get_option_value (a_args, "--exe")
			l_publisher := get_option_value (a_args, "--publisher")
			l_icon := get_option_value (a_args, "--icon")

			if not attached l_session_name then
				print ("[ERROR] Missing --session%N")
			elseif not attached l_app_name then
				print ("[ERROR] Missing --app (application name)%N")
			elseif not attached l_exe_name then
				print ("[ERROR] Missing --exe (executable name)%N")
			else
				create l_session.make_from_existing (l_session_name)
				if not l_session.is_valid then
					print ("[ERROR] Invalid session: " + l_session.last_error.to_string_8 + "%N")
				else
					-- Create INNO builder and configure
					create l_inno.make
					l_inno.set_app_name (l_app_name)
					l_inno.set_exe_name (l_exe_name)

					if attached l_version as l_v then
						l_inno.set_app_version (l_v)
					else
						l_inno.set_app_version ({STRING_32} "1.0.0")
					end

					if attached l_publisher as l_p then
						l_inno.set_publisher (l_p)
					end

					if attached l_icon as l_i then
						l_inno.set_icon_file (l_i)
					end

					-- Add the main executable
					l_inno.add_exe (l_exe_name)

					-- Generate the script
					l_script := l_inno.generate_iss_script

					-- Save to session
					create l_builder.make (l_session)
					create l_prompt.make (l_script.count + 500)
					l_prompt.append ({STRING_32} "=== INNO INSTALLER SCRIPT ===%N%N")
					l_prompt.append ({STRING_32} "Generated INNO Setup script for: ")
					l_prompt.append (l_app_name)
					l_prompt.append ({STRING_32} "%N%N")
					l_prompt.append ({STRING_32} "Save this as 'setup.iss' and compile with INNO Setup Compiler:%N")
					l_prompt.append ({STRING_32} "  iscc.exe setup.iss%N%N")
					l_prompt.append ({STRING_32} "=== SCRIPT ===%N%N")
					l_prompt.append (l_script)

					l_session.save_next_prompt (l_prompt)

					print ("[OK] INNO installer script generated%N")
					print ("Application: " + l_app_name.to_string_8 + "%N")
					print ("Executable: " + l_exe_name.to_string_8 + "%N")
					print ("%NScript saved to: " + l_session.last_prompt_path.to_string_8 + "%N")
					print ("%NTo build installer:%N")
					print ("  1. Review and customize the .iss script%N")
					print ("  2. Add files to include (binaries, DLLs, resources)%N")
					print ("  3. Run: iscc.exe setup.iss%N")
					is_success := True
				end
			end
		end

	handle_git_context (a_args: ARGUMENTS_32)
			-- Handle 'git-context --session <name> [--file <file>]' command.
			-- Generates git history context for Claude prompts.
		local
			l_session_name, l_file: detachable STRING_32
			l_session: SCG_SESSION
			l_git: SCG_GIT_HELPER
			l_context: STRING_32
		do
			l_session_name := get_option_value (a_args, "--session")
			l_file := get_option_value (a_args, "--file")

			if not attached l_session_name then
				print ("[ERROR] Missing --session%N")
			else
				create l_session.make_from_existing (l_session_name)
				if not l_session.is_valid then
					print ("[ERROR] Invalid session: " + l_session.last_error.to_string_8 + "%N")
				else
					-- Create git helper for session directory
					create l_git.make (l_session.session_path)

					if not l_git.is_git_repo then
						-- Try parent directory
						create l_git.make ({STRING_32} ".")
					end

					if l_git.is_git_repo then
						-- Generate context
						if attached l_file as l_f then
							l_context := l_git.generate_file_history_context (l_f)
						else
							l_context := l_git.generate_change_context
						end

						-- Add prompt template
						create {STRING_32} l_context.make (l_context.count + 1000)
						l_context.append (l_git.generate_change_context)
						l_context.append ({STRING_32} "%N%N")
						l_context.append (l_git.git_history_prompt_template)

						l_session.save_next_prompt (l_context)

						print ("[OK] Git context generated%N")
						print ("Branch: " + l_git.current_branch.to_string_8 + "%N")
						if l_git.has_uncommitted_changes then
							print ("Status: Has uncommitted changes%N")
						else
							print ("Status: Clean%N")
						end
						print ("%NContext saved to: " + l_session.last_prompt_path.to_string_8 + "%N")
						print ("%NUse this context with Claude to:%N")
						print ("  - Analyze recent changes%N")
						print ("  - Generate appropriate commit messages%N")
						print ("  - Identify related files for updates%N")
						is_success := True
					else
						print ("[ERROR] Not a git repository%N")
					end
				end
			end
		end

feature {NONE} -- Helpers

	get_option_value (a_args: ARGUMENTS_32; a_option: STRING): detachable STRING_32
			-- Get value following option flag (e.g., --session value).
		local
			i: INTEGER
		do
			from
				i := 1
			until
				i > a_args.argument_count or attached Result
			loop
				if a_args.argument (i).is_case_insensitive_equal (a_option) then
					if i < a_args.argument_count then
						Result := a_args.argument (i + 1)
					end
				end
				i := i + 1
			end
		end

	has_flag (a_args: ARGUMENTS_32; a_flag: STRING): BOOLEAN
			-- Does command line contain flag (e.g., --all)?
		local
			i: INTEGER
		do
			from
				i := 1
			until
				i > a_args.argument_count or Result
			loop
				if a_args.argument (i).is_case_insensitive_equal (a_flag) then
					Result := True
				end
				i := i + 1
			end
		end

	print_usage
			-- Print usage information.
		do
			print ("Simple Code Generator CLI - Claude-in-the-Loop Code Generation%N")
			print ("================================================================%N%N")
			print ("Commands:%N")
			print ("  init --session <name> [--level system|class] [--class <CLASS_NAME>]%N")
			print ("      Initialize a new generation session (default: system level)%N%N")
			print ("  add-feature --session <name> --class <CLASS> --feature <name> --type <command|query>%N")
			print ("      Generate prompt to add a feature to an existing class%N%N")
			print ("  process --input <response.txt> --session <name> [--output <prompt.txt>]%N")
			print ("      Process Claude's response, output next prompt%N%N")
			print ("  validate --input <class.e>%N")
			print ("      Validate generated Eiffel code%N%N")
			print ("  refine --session <name> --class <CLASS_NAME> --issues %"issue1;issue2%"%N")
			print ("      Generate refinement prompt for a class with issues%N%N")
			print ("  compile --session <name> --project <path>%N")
			print ("      Compile project, auto-generate refinement prompts on errors%N%N")
			print ("  generate-tests --session <name> --class <CLASS_NAME>%N")
			print ("      Generate test class prompt (happy-path + edge-cases)%N%N")
			print ("  assemble --session <name> --output <path>%N")
			print ("      Assemble final project from session%N%N")
			print ("  status --session <name>%N")
			print ("      Show session status%N%N")
			print ("  history [--session <name>] [--class <CLASS_NAME>]%N")
			print ("      Show audit history from SQLite database%N")
			print ("      No args: list all sessions. With --session: session timeline.%N")
			print ("      With --class: class-specific history.%N%N")
			print ("  reset --session <name> | --all%N")
			print ("      Reset session files and audit history for clean testing%N%N")
			print ("  research --session <name> --topic %"topic%" --scope <system|class|feature>%N")
			print ("      Generate 7-step in-depth research prompt for Claude%N%N")
			print ("  plan --session <name> --goal %"goal%" [--class <CLASS_NAME>]%N")
			print ("      Generate design-build-implement-test planning prompt%N%N")
			print ("  run-tests --session <name> --project <path>%N")
			print ("      Run tests and generate refinement prompts for failures%N%N")
			print ("  c-integrate --session <name> --mode <wrap|library|win32> --target %"description%"%N")
			print ("      Generate C/C++ integration prompt (inline C, library, Win32 API)%N%N")
			print ("  inno-install --session <name> --app <name> --exe <exe.exe> [--version <ver>] [--publisher <pub>] [--icon <ico>]%N")
			print ("      Generate INNO Setup installer script%N%N")
			print ("  git-context --session <name> [--file <file>]%N")
			print ("      Generate git history context for Claude prompts%N%N")
			print ("Build modes (for compile/run-tests):%N")
			print ("  Development:  W_code (workbench, fast compile, slow run)%N")
			print ("  Testing:      F_code with -keep (finalized with assertions)%N")
			print ("  Production:   F_code without -keep (finalized, no assertions)%N%N")
			print ("Example workflow:%N")
			print ("  1. simple_codegen init --session library_system%N")
			print ("  2. Copy 001_system_design.txt prompt to Claude%N")
			print ("  3. Save Claude's response to response.txt%N")
			print ("  4. simple_codegen process --input response.txt --session library_system%N")
			print ("  5. Repeat steps 2-4 for each generated prompt%N")
			print ("  6. simple_codegen validate --input generated_class.e%N")
			print ("  7. If issues: simple_codegen refine --session library_system --class CLASS --issues %"...%"%N")
			print ("  8. Process refinement response, repeat until valid%N")
			print ("  9. simple_codegen assemble --session library_system --output ./library_system%N")
		end

invariant
	last_error_exists: last_error /= Void

end
