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
			create debug_logger.make_to_file ("D:/prod/simple_code/debug_trace.log")
			debug_logger.set_level (debug_logger.Level_debug)
			debug_logger.debug_log ("SCG_SESSION.make_new: START name=" + a_name.to_string_8)

			session_name := a_name
			create last_error.make_empty
			create last_prompt_path.make_empty
			create class_specs.make (10)
			create external_dependencies.make (5)
			create generated_files.make (10)
			create workflow_todos.make (10)
			iteration := 0
			state := State_initialized
			current_step := 1
			use_atomic_prompts := True

			debug_logger.debug_log ("SCG_SESSION.make_new: calling create_session_directory")
			create_session_directory
			if is_valid then
				debug_logger.debug_log ("SCG_SESSION.make_new: calling create_initial_prompt")
				create_initial_prompt
				debug_logger.debug_log ("SCG_SESSION.make_new: calling save_session")
				save_session
			end
			debug_logger.debug_log ("SCG_SESSION.make_new: END is_valid=" + is_valid.out)
		ensure
			name_set: session_name = a_name
		end

	make_from_existing (a_name: STRING_32)
			-- Load existing session named `a_name'.
		require
			name_not_empty: not a_name.is_empty
		do
			create debug_logger.make_to_file ("D:/prod/simple_code/debug_trace.log")
			debug_logger.set_level (debug_logger.Level_debug)
			debug_logger.debug_log ("SCG_SESSION.make_from_existing: START name=" + a_name.to_string_8)

			session_name := a_name
			create last_error.make_empty
			create last_prompt_path.make_empty
			create class_specs.make (10)
			create external_dependencies.make (5)
			create generated_files.make (10)
			create workflow_todos.make (10)
			iteration := 0
			state := State_initialized
			current_step := 1
			use_atomic_prompts := True

			debug_logger.debug_log ("SCG_SESSION.make_from_existing: calling load_session")
			load_session
			debug_logger.debug_log ("SCG_SESSION.make_from_existing: END is_valid=" + is_valid.out)
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

feature -- Workflow Todo Tracking

	workflow_todos: ARRAYED_LIST [TUPLE [task: STRING; status: INTEGER; step: INTEGER]]
			-- Todo list for workflow tracking
			-- status: 0=pending, 1=in_progress, 2=completed

	current_step: INTEGER
			-- Current workflow step index (1-based)

	use_atomic_prompts: BOOLEAN
			-- Use atomic prompt architecture? (default: True)

	initialize_workflow_todos
			-- Initialize todo list with system spec as first task and save.
		do
			create workflow_todos.make (10)
			workflow_todos.extend (["Generate system_spec.json", 0, 1])
			current_step := 1
			use_atomic_prompts := True
			save_session
		ensure
			todos_initialized: workflow_todos.count = 1
			step_at_one: current_step = 1
		end

	add_class_todos
			-- Add todo item for each class in session and save.
		local
			l_step: INTEGER
		do
			l_step := 2
			across class_specs as ic loop
				workflow_todos.extend (["Generate " + ic.name.to_string_8, 0, l_step])
				l_step := l_step + 1
			end
			workflow_todos.extend (["Assemble project", 0, l_step])
			workflow_todos.extend (["Compile and verify", 0, l_step + 1])
			save_session
		ensure
			todos_added: workflow_todos.count >= old workflow_todos.count
		end

	mark_todo_in_progress
			-- Mark current step as in_progress and save.
		require
			valid_step: current_step >= 1 and current_step <= workflow_todos.count
		do
			workflow_todos.i_th (current_step).status := 1
			save_session
		ensure
			marked_in_progress: workflow_todos.i_th (current_step).status = 1
		end

	mark_todo_done
			-- Mark current step as completed and advance to next.
		require
			valid_step: current_step >= 1 and current_step <= workflow_todos.count
		do
			workflow_todos.i_th (current_step).status := 2
			if current_step < workflow_todos.count then
				current_step := current_step + 1
			end
			save_session
		ensure
			marked_done: workflow_todos.i_th (old current_step).status = 2
		end

	get_todo_display: STRING
			-- Formatted todo list for display.
		local
			l_status_char: STRING
		do
			create Result.make (500)
			across workflow_todos as ic loop
				inspect ic.status
				when 0 then
					l_status_char := "  "
				when 1 then
					l_status_char := "→ "
				when 2 then
					l_status_char := "✓ "
				else
					l_status_char := "? "
				end
				Result.append (l_status_char)
				Result.append (ic.task)
				Result.append ("%N")
			end
		end

	get_current_task: STRING
			-- Get description of current task.
		require
			has_todos: not workflow_todos.is_empty
			valid_step: current_step >= 1 and current_step <= workflow_todos.count
		do
			Result := workflow_todos.i_th (current_step).task
		end

	is_workflow_complete: BOOLEAN
			-- Are all workflow todos completed?
		do
			Result := across workflow_todos as ic all ic.status = 2 end
		end

	pending_todo_count: INTEGER
			-- Number of pending (not started) todos.
		do
			across workflow_todos as ic loop
				if ic.status = 0 then
					Result := Result + 1
				end
			end
		end

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

	external_dependencies: ARRAYED_LIST [TUPLE [name: STRING_8; include_path: STRING_8; library_path: STRING_8]]
			-- External C library dependencies for ECF generation
			-- Each tuple contains: name ("libpq"), include path ("$(POSTGRESQL_HOME)/include"),
			-- library path ("$(POSTGRESQL_HOME)/lib/libpq.lib")

	generated_files: ARRAYED_LIST [STRING_32]
			-- List of generated file paths (after assembly)

	last_error: STRING_32
			-- Error message from last failed operation

	last_prompt_path: STRING_32
			-- Path to last generated prompt file

	debug_logger: SIMPLE_LOGGER
			-- Debug logger for tracing

	prompt_count: INTEGER
			-- Number of prompts generated

	response_count: INTEGER
			-- Number of responses processed

	reuse_analysis: detachable SCG_REUSE_RESULT
			-- Cached reuse analysis for the session (at SYSTEM scale)
			-- Populated when system spec is first processed or on-demand

	reuse_discoverer: detachable SCG_REUSE_DISCOVERER
			-- Reuse discoverer instance (created on demand when KB available)

feature -- Reuse Discovery

	discover_reuse_at_scale (a_scale: STRING)
			-- Trigger reuse discovery at the specified scale point.
			-- Scales: "SYSTEM", "CLUSTER", "CLASS", "FEATURE"
		require
			scale_not_empty: not a_scale.is_empty
		local
			l_kb: SCG_KB
			l_ecf_path: STRING
		do
			-- Initialize discoverer if needed
			if not attached reuse_discoverer then
				create l_kb.make
				if l_kb.is_open then
					l_ecf_path := (output_path + "/" + session_name + ".ecf").to_string_8
					create reuse_discoverer.make_with_kb (l_kb, l_ecf_path)
				end
			end

			if attached reuse_discoverer as l_disc then
				-- Set session specs for internal matching
				l_disc.set_session_specs (class_specs)

				if a_scale.is_case_insensitive_equal ("SYSTEM") then
					-- Full system analysis
					if not class_specs.is_empty then
						reuse_analysis := l_disc.discover_for_system (class_specs)
					end
				elseif a_scale.is_case_insensitive_equal ("CLASS") then
					-- Incremental analysis for new class
					if not class_specs.is_empty then
						-- Re-run system analysis to capture new class
						reuse_analysis := l_disc.discover_for_system (class_specs)
					end
				end
			end
		end

	has_reuse_analysis: BOOLEAN
			-- Is there a cached reuse analysis?
		do
			Result := attached reuse_analysis
		end

	get_reuse_prompt_enhancement: STRING_32
			-- Get the prompt enhancement text from reuse analysis.
		do
			if attached reuse_analysis as l_ra then
				Result := l_ra.prompt_enhancement.to_string_32
			else
				create Result.make_empty
			end
		end

feature -- Element change

	add_class_spec (a_name, a_description: STRING_32; a_features: ARRAYED_LIST [STRING_32])
			-- Add a class specification to generate.
			-- Automatically triggers reuse discovery at CLASS scale.
		require
			name_not_empty: not a_name.is_empty
		local
			l_spec: SCG_SESSION_CLASS_SPEC
		do
			create l_spec.make (a_name, a_description, a_features)
			class_specs.extend (l_spec)

			-- Trigger reuse discovery for new class (front-loaded gate)
			discover_reuse_at_scale ("CLASS")

			save_session
		ensure
			spec_added: class_specs.count = old class_specs.count + 1
		end

	add_external_dependency (a_name, a_include_path, a_library_path: STRING_8)
			-- Add an external C library dependency for ECF generation.
		require
			name_not_empty: not a_name.is_empty
		do
			external_dependencies.extend ([a_name, a_include_path, a_library_path])
			save_session
		ensure
			dependency_added: external_dependencies.count = old external_dependencies.count + 1
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
			debug_logger.debug_log ("SCG_SESSION.add_response: START type=" + a_type.to_string_8 + " content_len=" + a_content.count.out)
			response_count := response_count + 1

			-- Determine file extension based on type
			if a_type.is_case_insensitive_equal ("class_code") then
				l_ext := ".e"
			else
				l_ext := ".json"
			end

			l_filename := responses_path + "/" + formatted_number (response_count) + "_response" + l_ext
			debug_logger.debug_log ("SCG_SESSION.add_response: writing to " + l_filename.to_string_8)

			create l_file.make (l_filename.to_string_8)
			if l_file.write_text (a_content.to_string_8) then
				debug_logger.debug_log ("SCG_SESSION.add_response: write success, updating state")
				-- Update state
				if a_type.is_case_insensitive_equal ("system_spec") then
					state := State_spec_received
				elseif a_type.is_case_insensitive_equal ("class_code") then
					state := State_generating
				end
				save_session
			else
				debug_logger.debug_log ("SCG_SESSION.add_response: WRITE FAILED")
			end
			debug_logger.debug_log ("SCG_SESSION.add_response: END")
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
			debug_logger.debug_log ("SCG_SESSION.save_next_prompt: START prompt_len=" + a_prompt.count.out)
			prompt_count := prompt_count + 1
			l_filename := prompts_path + "/" + formatted_number (prompt_count) + "_prompt.txt"
			last_prompt_path := l_filename
			debug_logger.debug_log ("SCG_SESSION.save_next_prompt: writing to " + l_filename.to_string_8)

			create l_file.make (l_filename.to_string_8)
			if l_file.write_text (a_prompt.to_string_8) then
				debug_logger.debug_log ("SCG_SESSION.save_next_prompt: write success")
				save_session
			else
				debug_logger.debug_log ("SCG_SESSION.save_next_prompt: WRITE FAILED")
			end
			debug_logger.debug_log ("SCG_SESSION.save_next_prompt: END")
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

			-- Check if ECF already exists (preserve existing project with libraries)
			create l_path.make_from (l_sanitized_path.to_string_8)
			create l_src_path.make_from (l_sanitized_path.to_string_8)
			l_src_dir := l_src_path.add ("src").to_string.to_string_32

			-- Check for existing ECF (use fresh path to avoid mutating l_path)
			create l_file.make ((create {SIMPLE_PATH}.make_from (l_sanitized_path.to_string_8)).add (session_name.to_string_8 + ".ecf").to_string)
			if l_file.exists then
				-- ECF exists - just write source files, preserve existing ECF with libraries
				-- Ensure src directory exists
				create l_file.make (l_src_dir.to_string_8)
				if not l_file.exists then
					if not l_file.create_directory then
						last_error := "Failed to create src directory"
					end
				end

				across class_specs as ic loop
					if ic.is_generated and then attached ic.generated_code as l_code then
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
				-- No ECF exists - create full project scaffold with external dependencies
				create l_simple_libs.make (5)
				create l_gen.make_with_externals (l_path, session_name.to_string_8, l_simple_libs, external_dependencies)

				if l_gen.is_generated then
					-- Write generated class files
					across class_specs as ic loop
						if ic.is_generated and then attached ic.generated_code as l_code then
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
			debug_logger.debug_log ("SCG_SESSION.save_session: START state=" + state.to_string_8 + " class_count=" + class_specs.count.out)
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

			-- Save external dependencies
			if not external_dependencies.is_empty then
				create l_classes_arr.make  -- reuse for external deps
				across external_dependencies as dep loop
					create l_class_obj.make  -- reuse for dep object
					l_discard_obj := l_class_obj.put_string (dep.name, "name")
					l_discard_obj := l_class_obj.put_string (dep.include_path, "include_path")
					l_discard_obj := l_class_obj.put_string (dep.library_path, "library_path")
					l_discard_arr := l_classes_arr.add_object (l_class_obj)
				end
				l_discard_obj := l_json.put_array (l_classes_arr, "external_dependencies")
			end

			-- Save workflow todos
			l_discard_obj := l_json.put_integer (current_step, "current_step")
			l_discard_obj := l_json.put_boolean (use_atomic_prompts, "use_atomic_prompts")
			if not workflow_todos.is_empty then
				create l_classes_arr.make  -- reuse for todos
				across workflow_todos as todo loop
					create l_class_obj.make
					l_discard_obj := l_class_obj.put_string (todo.task, "task")
					l_discard_obj := l_class_obj.put_integer (todo.status, "status")
					l_discard_obj := l_class_obj.put_integer (todo.step, "step")
					l_discard_arr := l_classes_arr.add_object (l_class_obj)
				end
				l_discard_obj := l_json.put_array (l_classes_arr, "workflow_todos")
			end

			-- Write to file
			debug_logger.debug_log ("SCG_SESSION.save_session: writing to " + (session_path + "/session.json").to_string_8)
			create l_file.make ((session_path + "/session.json").to_string_8)
			if l_file.write_text (l_json.to_json_string.to_string_8) then
				debug_logger.debug_log ("SCG_SESSION.save_session: write success")
			else
				debug_logger.debug_log ("SCG_SESSION.save_session: WRITE FAILED")
			end
			debug_logger.debug_log ("SCG_SESSION.save_session: END")
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
			l_include, l_lib: STRING_8
			i: INTEGER
		do
			debug_logger.debug_log ("SCG_SESSION.load_session: START session_path=" + session_path.to_string_8)
			create l_file.make ((session_path + "/session.json").to_string_8)
			if l_file.exists then
				debug_logger.debug_log ("SCG_SESSION.load_session: session.json exists, reading")
				l_json_text := l_file.read_text.to_string_32
				debug_logger.debug_log ("SCG_SESSION.load_session: read " + l_json_text.count.out + " chars")

				create l_json_parser
				if attached l_json_parser.parse (l_json_text) as l_value then
					debug_logger.debug_log ("SCG_SESSION.load_session: JSON parsed successfully")
					if l_value.is_object then
						-- Load basic fields
						if attached l_json_parser.query_string (l_value, "$.state") as l_st then
							state := l_st
						end
						iteration := l_json_parser.query_integer (l_value, "$.iteration").to_integer_32
						prompt_count := l_json_parser.query_integer (l_value, "$.prompt_count").to_integer_32
						response_count := l_json_parser.query_integer (l_value, "$.response_count").to_integer_32
						debug_logger.debug_log ("SCG_SESSION.load_session: loaded state=" + state.to_string_8 + " prompt_count=" + prompt_count.out)

						-- Load class specs
						if l_value.as_object.has_key ("classes") then
							if attached l_value.as_object.item ("classes") as l_classes_val then
								if l_classes_val.is_array then
									l_classes_arr := l_classes_val.as_array
									debug_logger.debug_log ("SCG_SESSION.load_session: loading " + l_classes_arr.count.out + " class specs")
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
												debug_logger.debug_log ("SCG_SESSION.load_session: loaded class " + l_name.to_string_8)
											end
										end
										i := i + 1
									end
								end
							end
						end

						-- Load external dependencies
						if l_value.as_object.has_key ("external_dependencies") then
							if attached l_value.as_object.item ("external_dependencies") as l_deps_val then
								if l_deps_val.is_array then
									l_classes_arr := l_deps_val.as_array
									from i := 1 until i > l_classes_arr.count loop
										l_class_val := l_classes_arr.item (i)
										if l_class_val.is_object then
											l_name := ""
											l_include := ""
											l_lib := ""
											if attached l_json_parser.query_string (l_class_val, "$.name") as l_n then
												l_name := l_n
											end
											if attached l_json_parser.query_string (l_class_val, "$.include_path") as l_inc then
												l_include := l_inc.to_string_8
											end
											if attached l_json_parser.query_string (l_class_val, "$.library_path") as l_lp then
												l_lib := l_lp.to_string_8
											end
											if not l_name.is_empty then
												external_dependencies.extend ([l_name.to_string_8, l_include, l_lib])
											end
										end
										i := i + 1
									end
								end
							end
						end

						-- Load workflow todos
						current_step := l_json_parser.query_integer (l_value, "$.current_step").to_integer_32
						if current_step < 1 then
							current_step := 1
						end
						-- Default to atomic prompts; check if explicitly set to false
						use_atomic_prompts := True
						if l_value.as_object.has_key ("use_atomic_prompts") then
							if attached l_value.as_object.item ("use_atomic_prompts") as l_ap_val then
								use_atomic_prompts := not l_ap_val.to_json_string.is_case_insensitive_equal ("false")
							end
						end
						if l_value.as_object.has_key ("workflow_todos") then
							if attached l_value.as_object.item ("workflow_todos") as l_todos_val then
								if l_todos_val.is_array then
									l_classes_arr := l_todos_val.as_array
									from i := 1 until i > l_classes_arr.count loop
										l_class_val := l_classes_arr.item (i)
										if l_class_val.is_object then
											l_name := ""
											if attached l_json_parser.query_string (l_class_val, "$.task") as l_t then
												l_name := l_t
											end
											if not l_name.is_empty then
												workflow_todos.extend ([
													l_name.to_string_8,
													l_json_parser.query_integer (l_class_val, "$.status").to_integer_32,
													l_json_parser.query_integer (l_class_val, "$.step").to_integer_32
												])
											end
										end
										i := i + 1
									end
								end
							end
						end
					end
				else
					debug_logger.debug_log ("SCG_SESSION.load_session: JSON PARSE FAILED")
					last_error := "Invalid session.json: " + l_json_parser.errors_as_string.to_string_8
				end
			else
				debug_logger.debug_log ("SCG_SESSION.load_session: session.json NOT FOUND")
				last_error := "Session not found: " + session_name.to_string_8
			end
			debug_logger.debug_log ("SCG_SESSION.load_session: END class_specs.count=" + class_specs.count.out)
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
	workflow_todos_exists: workflow_todos /= Void

end
