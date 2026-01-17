note
	description: "[
		Session state management for Claude-in-the-Loop code generation.

		Manages session directory structure:
			sessions/<name>/
				session.json          -- Session state
				spec.json             -- System specification
				prompts/
					001_system_design.txt
					002_class_<name>.txt
					...
				responses/
					001_system_design.json
					002_class_<name>.e
					...
				output/
					<project>.ecf
					src/
						<class>.e
						...
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_SESSION

create
	make_new,
	make_from_existing

feature {NONE} -- Initialization

	make_new (a_name: STRING_32)
			-- Create a new session with `a_name'.
		require
			name_not_empty: not a_name.is_empty
		do
			session_name := a_name
			create last_error.make_empty
			create last_prompt_path.make_empty
			create class_specs.make (10)
			create generated_files.make (10)
			iteration := 0
			state := State_initialized

			create_session_directory
			if is_valid then
				create_initial_prompt
				save_session
			end
		ensure
			name_set: session_name = a_name
		end

	make_from_existing (a_name: STRING_32)
			-- Load existing session named `a_name'.
		require
			name_not_empty: not a_name.is_empty
		do
			session_name := a_name
			create last_error.make_empty
			create last_prompt_path.make_empty
			create class_specs.make (10)
			create generated_files.make (10)
			iteration := 0
			state := State_initialized

			load_session
		ensure
			name_set: session_name = a_name
		end

feature -- Status

	is_valid: BOOLEAN
			-- Is this a valid session?
		do
			Result := last_error.is_empty
		end

	is_assembled: BOOLEAN
			-- Has project been assembled?

	has_pending_work: BOOLEAN
			-- Are there still classes to generate?
		do
			Result := across class_specs as ic some not ic.is_generated end
		end

feature -- Access

	session_name: STRING_32
			-- Name of this session

	session_path: STRING_32
			-- Full path to session directory
		do
			Result := sessions_root + "/" + session_name
		end

	prompts_path: STRING_32
			-- Path to prompts subdirectory
		do
			Result := session_path + "/prompts"
		end

	responses_path: STRING_32
			-- Path to responses subdirectory
		do
			Result := session_path + "/responses"
		end

	output_path: STRING_32
			-- Path to output subdirectory
		do
			Result := session_path + "/output"
		end

	state: STRING_32
			-- Current session state

	iteration: INTEGER
			-- Current iteration number

	class_specs: ARRAYED_LIST [SCG_SESSION_CLASS_SPEC]
			-- Specifications for classes to generate

	generated_files: ARRAYED_LIST [STRING_32]
			-- List of generated file paths (after assembly)

	last_error: STRING_32
			-- Error message from last failed operation

	last_prompt_path: STRING_32
			-- Path to last generated prompt file

	prompt_count: INTEGER
			-- Number of prompts generated

	response_count: INTEGER
			-- Number of responses processed

feature -- Element change

	add_class_spec (a_name, a_description: STRING_32; a_features: ARRAYED_LIST [STRING_32])
			-- Add a class specification to generate.
		require
			name_not_empty: not a_name.is_empty
		local
			l_spec: SCG_SESSION_CLASS_SPEC
		do
			create l_spec.make (a_name, a_description, a_features)
			class_specs.extend (l_spec)
			save_session
		ensure
			spec_added: class_specs.count = old class_specs.count + 1
		end

	add_response (a_content: STRING_32; a_type: STRING_32)
			-- Add a response from Claude.
		require
			content_not_empty: not a_content.is_empty
			type_not_empty: not a_type.is_empty
		local
			l_file: SIMPLE_FILE
			l_filename: STRING_32
			l_ext: STRING
		do
			response_count := response_count + 1

			-- Determine file extension based on type
			if a_type.is_case_insensitive_equal ("class_code") then
				l_ext := ".e"
			else
				l_ext := ".json"
			end

			l_filename := responses_path + "/" + formatted_number (response_count) + "_response" + l_ext

			create l_file.make (l_filename.to_string_8)
			if l_file.write_text (a_content.to_string_8) then
				-- Update state
				if a_type.is_case_insensitive_equal ("system_spec") then
					state := State_spec_received
				elseif a_type.is_case_insensitive_equal ("class_code") then
					state := State_generating
				end
				save_session
			end
		end

	mark_class_generated (a_class_name: STRING_32; a_code: STRING_32)
			-- Mark a class as generated with its code.
		require
			name_not_empty: not a_class_name.is_empty
			code_not_empty: not a_code.is_empty
		do
			across class_specs as ic loop
				if ic.name.is_case_insensitive_equal (a_class_name) then
					ic.set_generated (a_code)
				end
			end
			save_session
		end

	save_next_prompt (a_prompt: STRING_32)
			-- Save the next prompt to the prompts directory.
		require
			prompt_not_empty: not a_prompt.is_empty
		local
			l_file: SIMPLE_FILE
			l_filename: STRING_32
		do
			prompt_count := prompt_count + 1
			l_filename := prompts_path + "/" + formatted_number (prompt_count) + "_prompt.txt"
			last_prompt_path := l_filename

			create l_file.make (l_filename.to_string_8)
			if l_file.write_text (a_prompt.to_string_8) then
				save_session
			end
		ensure
			prompt_count_incremented: prompt_count = old prompt_count + 1
		end

feature -- Operations

	reset
			-- Reset session to clean state (delete prompts, responses, reset counters).
		local
			l_dir: DIRECTORY
			l_file: RAW_FILE
		do
			-- Clear prompts directory
			create l_dir.make (prompts_path.to_string_8)
			if l_dir.exists then
				l_dir.open_read
				from l_dir.start l_dir.readentry until l_dir.lastentry = Void loop
					if attached l_dir.lastentry as l_entry then
						if not l_entry.same_string (".") and not l_entry.same_string ("..") then
							create l_file.make (prompts_path.to_string_8 + "/" + l_entry)
							if l_file.exists and then not l_file.is_directory then
								l_file.delete
							end
						end
					end
					l_dir.readentry
				end
				l_dir.close
			end

			-- Clear responses directory
			create l_dir.make (responses_path.to_string_8)
			if l_dir.exists then
				l_dir.open_read
				from l_dir.start l_dir.readentry until l_dir.lastentry = Void loop
					if attached l_dir.lastentry as l_entry then
						if not l_entry.same_string (".") and not l_entry.same_string ("..") then
							create l_file.make (responses_path.to_string_8 + "/" + l_entry)
							if l_file.exists and then not l_file.is_directory then
								l_file.delete
							end
						end
					end
					l_dir.readentry
				end
				l_dir.close
			end

			-- Reset counters and state
			prompt_count := 0
			response_count := 0
			iteration := 0
			state := State_initialized
			class_specs.wipe_out
			generated_files.wipe_out
			is_assembled := False

			-- Save clean session state
			save_session

			-- Recreate initial prompt
			create_initial_prompt
		ensure
			clean_state: prompt_count = 1 -- just the initial prompt
			responses_cleared: response_count = 0
			classes_cleared: class_specs.is_empty
		end

	assemble_project (a_output_path: STRING_32)
			-- Assemble final project at `a_output_path'.
		require
			output_path_not_empty: not a_output_path.is_empty
		local
			l_gen: SCG_PROJECT_GEN
			l_path, l_src_path: SIMPLE_PATH
			l_file: SIMPLE_FILE
			l_src_dir: STRING_32
			l_simple_libs: ARRAYED_LIST [STRING]
			l_class_path: STRING_32
			l_sanitized_path: STRING_32
		do
			generated_files.wipe_out

			-- Sanitize output path: strip trailing /src or \src if present
			l_sanitized_path := a_output_path.twin
			if l_sanitized_path.ends_with ("/src") or l_sanitized_path.ends_with ("\src") then
				l_sanitized_path.remove_tail (4)
			end
			if l_sanitized_path.ends_with ("/") or l_sanitized_path.ends_with ("\") then
				l_sanitized_path.remove_tail (1)
			end

			-- Create simple_libs list (empty for now, could be configured)
			create l_simple_libs.make (5)

			-- Generate project scaffold
			create l_path.make_from (l_sanitized_path.to_string_8)
			create l_gen.make_with_name (l_path, session_name.to_string_8, l_simple_libs)

			if l_gen.is_generated then
				-- Write generated class files using SIMPLE_PATH for proper path construction
				create l_src_path.make_from (l_sanitized_path.to_string_8)
				l_src_dir := l_src_path.add ("src").to_string.to_string_32

				across class_specs as ic loop
					if ic.is_generated and then attached ic.generated_code as l_code then
						-- Use SIMPLE_PATH for proper path separator handling
						create l_src_path.make_from (l_src_dir.to_string_8)
						l_class_path := l_src_path.add (ic.name.as_lower + ".e").to_string.to_string_32
						create l_file.make (l_class_path.to_string_8)
						if l_file.write_text (l_code.to_string_8) then
							generated_files.extend (l_class_path)
						end
					end
				end

				is_assembled := True
				state := State_assembled
				save_session
			else
				if attached l_gen.verification_error as l_err then
					last_error := l_err.to_string_32
				else
					last_error := "Project generation failed"
				end
			end
		end

feature {NONE} -- Session Persistence

	create_session_directory
			-- Create the session directory structure.
		local
			l_dir: SIMPLE_FILE
		do
			-- Create sessions root if needed
			create l_dir.make (sessions_root.to_string_8)
			if not l_dir.exists then
				if not l_dir.create_directory then
					last_error := "Failed to create sessions directory"
				end
			end

			if last_error.is_empty then
				-- Create session directory
				create l_dir.make (session_path.to_string_8)
				if l_dir.exists then
					last_error := "Session already exists: " + session_name
				else
					if not l_dir.create_directory then
						last_error := "Failed to create session directory"
					end
				end
			end

			if last_error.is_empty then
				-- Create subdirectories
				create l_dir.make (prompts_path.to_string_8)
				if not l_dir.create_directory then
					last_error := "Failed to create prompts directory"
				end
			end

			if last_error.is_empty then
				create l_dir.make (responses_path.to_string_8)
				if not l_dir.create_directory then
					last_error := "Failed to create responses directory"
				end
			end

			if last_error.is_empty then
				create l_dir.make (output_path.to_string_8)
				if not l_dir.create_directory then
					last_error := "Failed to create output directory"
				end
			end
		end

	create_initial_prompt
			-- Create the initial system design prompt.
		local
			l_builder: SCG_PROMPT_BUILDER
			l_prompt: STRING_32
		do
			create l_builder.make (Current)
			l_prompt := l_builder.build_system_design_prompt

			prompt_count := 1
			last_prompt_path := prompts_path + "/001_system_design.txt"

			save_prompt_file (last_prompt_path, l_prompt)
		end

	save_prompt_file (a_path: STRING_32; a_content: STRING_32)
			-- Save prompt content to file.
		local
			l_file: SIMPLE_FILE
		do
			create l_file.make (a_path.to_string_8)
			if not l_file.write_text (a_content.to_string_8) then
				last_error := "Failed to write prompt file: " + a_path
			end
		end

	save_session
			-- Save session state to session.json.
		local
			l_json: SIMPLE_JSON_OBJECT
			l_classes_arr: SIMPLE_JSON_ARRAY
			l_class_obj: SIMPLE_JSON_OBJECT
			l_file: SIMPLE_FILE
			l_discard_obj: SIMPLE_JSON_OBJECT
			l_discard_arr: SIMPLE_JSON_ARRAY
		do
			create l_json.make
			l_discard_obj := l_json.put_string (session_name, "name")
			l_discard_obj := l_json.put_string (state, "state")
			l_discard_obj := l_json.put_integer (iteration, "iteration")
			l_discard_obj := l_json.put_integer (prompt_count, "prompt_count")
			l_discard_obj := l_json.put_integer (response_count, "response_count")

			-- Save class specs
			create l_classes_arr.make
			across class_specs as ic loop
				create l_class_obj.make
				l_discard_obj := l_class_obj.put_string (ic.name, "name")
				l_discard_obj := l_class_obj.put_string (ic.description, "description")
				l_discard_obj := l_class_obj.put_boolean (ic.is_generated, "is_generated")
				if ic.is_generated and then attached ic.generated_code as l_code then
					l_discard_obj := l_class_obj.put_string (l_code, "code")
				end
				l_discard_arr := l_classes_arr.add_object (l_class_obj)
			end
			l_discard_obj := l_json.put_array (l_classes_arr, "classes")

			-- Write to file
			create l_file.make ((session_path + "/session.json").to_string_8)
			if not l_file.write_text (l_json.to_json_string.to_string_8) then
				-- Silently fail on save (log in production)
			end
		end

	load_session
			-- Load session state from session.json.
		local
			l_file: SIMPLE_FILE
			l_json_parser: SIMPLE_JSON
			l_json_text: STRING_32
			l_spec: SCG_SESSION_CLASS_SPEC
			l_features: ARRAYED_LIST [STRING_32]
			l_classes_arr: SIMPLE_JSON_ARRAY
			l_class_val: SIMPLE_JSON_VALUE
			l_name, l_desc: STRING_32
			i: INTEGER
		do
			create l_file.make ((session_path + "/session.json").to_string_8)
			if l_file.exists then
				l_json_text := l_file.read_text.to_string_32

				create l_json_parser
				if attached l_json_parser.parse (l_json_text) as l_value then
					if l_value.is_object then
						-- Load basic fields
						if attached l_json_parser.query_string (l_value, "$.state") as l_st then
							state := l_st
						end
						iteration := l_json_parser.query_integer (l_value, "$.iteration").to_integer_32
						prompt_count := l_json_parser.query_integer (l_value, "$.prompt_count").to_integer_32
						response_count := l_json_parser.query_integer (l_value, "$.response_count").to_integer_32

						-- Load class specs
						if l_value.as_object.has_key ("classes") then
							if attached l_value.as_object.item ("classes") as l_classes_val then
								if l_classes_val.is_array then
									l_classes_arr := l_classes_val.as_array
									from i := 1 until i > l_classes_arr.count loop
										l_class_val := l_classes_arr.item (i)
										if l_class_val.is_object then
											create l_features.make (0)
											l_name := ""
											l_desc := ""
											if attached l_json_parser.query_string (l_class_val, "$.name") as l_n then
												l_name := l_n
											end
											if attached l_json_parser.query_string (l_class_val, "$.description") as l_d then
												l_desc := l_d
											end
											if not l_name.is_empty then
												create l_spec.make (l_name, l_desc, l_features)
												if attached l_json_parser.query_string (l_class_val, "$.code") as l_code then
													l_spec.set_generated (l_code)
												end
												class_specs.extend (l_spec)
											end
										end
										i := i + 1
									end
								end
							end
						end
					end
				else
					last_error := "Invalid session.json: " + l_json_parser.errors_as_string.to_string_8
				end
			else
				last_error := "Session not found: " + session_name.to_string_8
			end
		end

feature {NONE} -- Helpers

	formatted_number (a_num: INTEGER): STRING_32
			-- Format number as 3-digit string (e.g., 001, 023).
		do
			create Result.make (3)
			if a_num < 10 then
				Result.append ("00")
			elseif a_num < 100 then
				Result.append ("0")
			end
			Result.append (a_num.out)
		ensure
			length_at_least_3: Result.count >= 3
		end

	sessions_root: STRING_32
			-- Root directory for all sessions
		once
			Result := "sessions"
		end

feature -- State Constants

	State_initialized: STRING_32 = "initialized"
	State_spec_received: STRING_32 = "spec_received"
	State_generating: STRING_32 = "generating"
	State_assembled: STRING_32 = "assembled"

invariant
	session_name_not_empty: not session_name.is_empty
	class_specs_exists: class_specs /= Void
	generated_files_exists: generated_files /= Void
	last_error_exists: last_error /= Void

end
