note
	description: "[
		System-level AI-assisted code generator.

		Orchestrates the full generation hierarchy:
		1. Takes system specification (requirements, domain description)
		2. Decomposes into clusters and class specifications (AI-assisted)
		3. Uses SCG_PROJECT_GEN to create project scaffold (ECF, directories)
		4. Uses SCG_CLASS_NEGOTIATOR to generate each class
		5. Validates with compilation (SC_COMPILER)

		Works at any scale:
		- Full system from scratch
		- Subsystem/cluster within existing system
		- Single class (degenerates to SCG_CLASS_GEN)

		Usage:
			create gen.make (system_spec, output_path, simple_libs)
			if gen.is_generated then
				-- Project created at output_path
			end
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_SYS_GEN

create
	make,
	make_subsystem

feature {NONE} -- Initialization

	make (a_system_spec: STRING_32; a_output_path: STRING; a_simple_libs: ARRAYED_LIST [STRING])
			-- Generate complete system from specification.
		require
			spec_not_empty: not a_system_spec.is_empty
			path_not_empty: not a_output_path.is_empty
		do
			system_spec := a_system_spec
			output_path := a_output_path
			simple_libs := a_simple_libs
			is_subsystem := False

			create class_specs.make (10)
			create generated_classes.make (10)
			create generation_log.make (20)
			create last_error.make_empty

			-- Setup AI client
			create {CLAUDE_CLIENT} ai_client.make
			ai_client.set_model ({CLAUDE_CLIENT}.model_opus_45)

			generate_system
		ensure
			spec_stored: system_spec = a_system_spec
			path_stored: output_path = a_output_path
		end

	make_subsystem (a_system_spec: STRING_32; a_project_path: STRING; a_cluster_name: STRING)
			-- Generate subsystem/cluster within existing project.
		require
			spec_not_empty: not a_system_spec.is_empty
			path_not_empty: not a_project_path.is_empty
			cluster_not_empty: not a_cluster_name.is_empty
		do
			system_spec := a_system_spec
			output_path := a_project_path
			cluster_name := a_cluster_name
			is_subsystem := True
			create simple_libs.make (0)

			create class_specs.make (10)
			create generated_classes.make (10)
			create generation_log.make (20)
			create last_error.make_empty

			-- Setup AI client
			create {CLAUDE_CLIENT} ai_client.make
			ai_client.set_model ({CLAUDE_CLIENT}.model_opus_45)

			generate_subsystem
		ensure
			spec_stored: system_spec = a_system_spec
			path_stored: output_path = a_project_path
			cluster_stored: cluster_name = a_cluster_name
			is_subsystem_mode: is_subsystem
		end

feature -- Status

	is_generated: BOOLEAN
			-- Was system successfully generated?

	is_compiled: BOOLEAN
			-- Did generated system compile successfully?

	is_subsystem: BOOLEAN
			-- Is this a subsystem within existing project?

	has_error: BOOLEAN
			-- Did generation fail?
		do
			Result := not last_error.is_empty
		end

feature -- Access

	system_spec: STRING_32
			-- System/subsystem specification

	output_path: STRING
			-- Output path for generated project

	cluster_name: STRING
			-- Cluster name (if subsystem)
		attribute
			create Result.make_empty
		end

	simple_libs: ARRAYED_LIST [STRING]
			-- Simple libraries to include

	project_name: STRING
			-- Derived project name
		attribute
			create Result.make_empty
		end

	class_specs: ARRAYED_LIST [SCG_CLASS_SPEC]
			-- Specifications for classes to generate

	generated_classes: ARRAYED_LIST [STRING_32]
			-- Generated class texts

	ai_client: AI_CLIENT
			-- AI client for decomposition

	last_error: STRING_32
			-- Error message if generation failed

	generation_log: ARRAYED_LIST [STRING_32]
			-- Log of generation phases

feature {NONE} -- System Generation

	generate_system
			-- Generate complete system.
		do
			log_action ("=== Starting system generation ===")

			-- Phase 1: Decompose system into classes
			log_action ("Phase 1: System decomposition")
			decompose_system

			if not has_error then
				-- Phase 2: Create project scaffold
				log_action ("Phase 2: Creating project scaffold")
				create_project_scaffold

				if not has_error then
					-- Phase 3: Generate each class
					log_action ("Phase 3: Generating classes")
					generate_classes

					if not has_error then
						-- Phase 4: Validate compilation
						log_action ("Phase 4: Validating compilation")
						validate_compilation

						is_generated := is_compiled
					end
				end
			end

			log_action ("=== System generation " + (if is_generated then "succeeded" else "failed" end) + " ===")
		end

	generate_subsystem
			-- Generate subsystem within existing project.
		do
			log_action ("=== Starting subsystem generation ===")

			-- Phase 1: Decompose into classes
			log_action ("Phase 1: Subsystem decomposition")
			decompose_system

			if not has_error then
				-- Phase 2: Create cluster directory
				log_action ("Phase 2: Creating cluster directory")
				create_cluster_directory

				if not has_error then
					-- Phase 3: Generate each class
					log_action ("Phase 3: Generating classes")
					generate_classes

					-- Note: Compilation validation requires full project context
					-- For subsystems, we assume the caller will validate
					is_generated := not has_error
				end
			end

			log_action ("=== Subsystem generation " + (if is_generated then "succeeded" else "failed" end) + " ===")
		end

	decompose_system
			-- Use AI to decompose system into class specifications.
		local
			l_prompt: STRING_32
			l_response: AI_RESPONSE
		do
			l_prompt := build_decomposition_prompt
			l_response := ai_client.ask_with_system (decomposition_system_prompt, l_prompt)

			if l_response.is_success then
				parse_decomposition (l_response.text)
				log_action ("Decomposed into " + class_specs.count.out + " classes")
			else
				if attached l_response.error_message as err then
					last_error := "Decomposition failed: " + err
				else
					last_error := "Decomposition failed: Unknown error"
				end
				log_action ("ERROR: " + last_error)
			end
		end

	build_decomposition_prompt: STRING_32
			-- Build prompt for system decomposition.
		do
			create Result.make (2000)
			Result.append ("Decompose this system into Eiffel classes.%N%N")

			Result.append ("=== SYSTEM SPECIFICATION ===%N")
			Result.append (system_spec)
			Result.append ("%N%N")

			Result.append ("=== SIMPLE ECOSYSTEM CONTEXT ===%N")
			Result.append ("Available libraries: ")
			across simple_libs as ic loop
				Result.append (ic)
				Result.append (", ")
			end
			Result.append ("%N%N")

			Result.append ("=== OUTPUT FORMAT ===%N")
			Result.append ("For each class, provide:%N")
			Result.append ("CLASS: ClassName%N")
			Result.append ("PURPOSE: What this class does%N")
			Result.append ("RESPONSIBILITIES:%N")
			Result.append ("- responsibility 1%N")
			Result.append ("- responsibility 2%N")
			Result.append ("COLLABORATORS: OtherClass1, OtherClass2%N")
			Result.append ("---%N%N")

			Result.append ("Identify 3-10 core classes. Focus on domain entities and key services.%N")
		end

	decomposition_system_prompt: STRING_32
			-- System prompt for decomposition.
		once
			Result := {STRING_32} "[
Expert Eiffel system architect. Decompose requirements into cohesive classes.
Follow single responsibility principle.
Identify key domain entities and services.
STRING_32 concat: use {STRING_32} "text" + var (NOT "text" + var).
Output class specifications in the requested format.
]"
		end

	parse_decomposition (a_response: STRING_32)
			-- Parse decomposition response into class specs.
		local
			l_lines: LIST [STRING_32]
			l_current_name, l_current_purpose: STRING_32
			l_current_responsibilities: ARRAYED_LIST [STRING_32]
			l_current_collaborators: STRING_32
			l_spec: SCG_CLASS_SPEC
			l_line: STRING_32
		do
			l_lines := a_response.split ('%N')
			create l_current_name.make_empty
			create l_current_purpose.make_empty
			create l_current_responsibilities.make (5)
			create l_current_collaborators.make_empty

			across l_lines as ic loop
				l_line := ic.twin
				l_line.left_adjust

				if l_line.starts_with ("CLASS:") then
					-- Save previous if any
					if not l_current_name.is_empty then
						create l_spec.make (l_current_name, l_current_purpose, l_current_responsibilities, l_current_collaborators)
						class_specs.extend (l_spec)
					end
					l_current_name := l_line.substring (7, l_line.count)
					l_current_name.left_adjust
					l_current_name.right_adjust
					create l_current_purpose.make_empty
					create l_current_responsibilities.make (5)
					create l_current_collaborators.make_empty

				elseif l_line.starts_with ("PURPOSE:") then
					l_current_purpose := l_line.substring (9, l_line.count)
					l_current_purpose.left_adjust

				elseif l_line.starts_with ("- ") and not l_current_name.is_empty then
					l_current_responsibilities.extend (l_line.substring (3, l_line.count))

				elseif l_line.starts_with ("COLLABORATORS:") then
					l_current_collaborators := l_line.substring (15, l_line.count)
					l_current_collaborators.left_adjust
				end
			end

			-- Save last class
			if not l_current_name.is_empty then
				create l_spec.make (l_current_name, l_current_purpose, l_current_responsibilities, l_current_collaborators)
				class_specs.extend (l_spec)
			end

			-- Derive project name from first class or system spec
			if not class_specs.is_empty then
				project_name := class_specs.first.name.as_lower
			else
				project_name := "generated_project"
			end
		end

	create_project_scaffold
			-- Create project using SCG_PROJECT_GEN.
		local
			l_path: SIMPLE_PATH
			l_gen: SCG_PROJECT_GEN
		do
			create l_path.make_from (output_path)
			create l_gen.make_with_name (l_path, project_name, simple_libs)

			if l_gen.is_generated and l_gen.is_verified then
				log_action ("Project scaffold created: " + project_name)
			else
				if attached l_gen.verification_error as err then
					last_error := "Project scaffold failed: " + err
				else
					last_error := "Project scaffold failed"
				end
				log_action ("ERROR: " + last_error)
			end
		end

	create_cluster_directory
			-- Create cluster directory within existing project.
		local
			l_dir: SIMPLE_FILE
			l_cluster_path: STRING
		do
			l_cluster_path := output_path + "/src/" + cluster_name
			create l_dir.make (l_cluster_path)

			if l_dir.create_directory then
				log_action ("Cluster directory created: " + cluster_name)
			else
				last_error := "Failed to create cluster directory: " + l_cluster_path
				log_action ("ERROR: " + last_error)
			end
		end

	generate_classes
			-- Generate each class using SCG_CLASS_NEGOTIATOR.
		local
			l_negotiator: SCG_CLASS_NEGOTIATOR
			l_class_spec_text: STRING_32
			l_file: SIMPLE_FILE
			l_class_path: STRING
			l_ok: BOOLEAN
		do
			across class_specs as ic loop
				log_action ("  Generating: " + ic.name)

				-- Build class specification text
				l_class_spec_text := ic.to_spec_string

				-- Generate using negotiator
				create l_negotiator.make (system_spec, l_class_spec_text, ai_client)

				if l_negotiator.is_negotiated then
					generated_classes.extend (l_negotiator.final_class_text)

					-- Save to file
					if is_subsystem then
						l_class_path := output_path + "/src/" + cluster_name + "/" + ic.name.as_lower + ".e"
					else
						l_class_path := output_path + "/" + project_name + "/src/" + ic.name.as_lower + ".e"
					end

					create l_file.make (l_class_path)
					l_ok := l_file.write_text (l_negotiator.final_class_text.to_string_8)

					if l_ok then
						log_action ("    Saved: " + l_class_path)
					else
						log_action ("    WARNING: Failed to save: " + l_class_path)
					end
				else
					log_action ("    WARNING: Generation failed for " + ic.name + ": " + l_negotiator.last_error)
				end
			end

			log_action ("Generated " + generated_classes.count.out + "/" + class_specs.count.out + " classes")
		end

	validate_compilation
			-- Validate generated project compiles.
		local
			l_compiler: SC_COMPILER
			l_ecf_path: STRING
			l_workdir: STRING
			l_discard: SC_COMPILER
		do
			l_ecf_path := project_name + ".ecf"
			l_workdir := output_path + "/" + project_name

			create l_compiler.make (l_ecf_path, project_name)
			l_discard := l_compiler.set_working_directory (l_workdir)
			l_compiler.compile_check

			if l_compiler.is_compiled then
				is_compiled := True
				log_action ("Compilation validation passed")
			else
				is_compiled := False
				last_error := "Compilation failed: " + l_compiler.last_error
				log_action ("ERROR: " + last_error)
			end
		end

	log_action (a_message: STRING_32)
			-- Log an action.
		do
			generation_log.extend (a_message)
		end

feature -- Output

	log_as_string: STRING_32
			-- Return generation log as string.
		do
			create Result.make (2000)
			across generation_log as ic loop
				Result.append (ic)
				Result.append ("%N")
			end
		end

invariant
	system_spec_exists: system_spec /= Void
	output_path_exists: output_path /= Void
	class_specs_exists: class_specs /= Void
	generated_classes_exists: generated_classes /= Void
	generation_log_exists: generation_log /= Void
	last_error_exists: last_error /= Void
	generated_implies_classes: is_generated implies not generated_classes.is_empty

end
