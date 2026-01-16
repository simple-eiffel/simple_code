note
	description: "[
		AI-assisted Eiffel class generator using assembly-line refinement.

		Generates production-quality Eiffel classes using a multi-phase AI workflow:

		Phase 1 - Initial Generation:
			Uses AI to create an Eiffel class based on system and class specifications.
			The AI is instructed to include comprehensive notes clause documentation.

		Phase 2 - Assembly-Line Refinement:
			Applies a pipeline of refinement jobs derived from reference documentation:
			- Naming conventions (NAMING_CONVENTIONS.md)
			- Command-Query Separation (EIFFEL_MENTAL_MODEL.md)
			- Void safety (EIFFEL_MENTAL_MODEL.md)
			- Semantic frame naming (SEMANTIC_FRAME_NAMING.md)
			- Contract strengthening (HATS.md)
			- Contract completeness (contract_patterns.md)
			- Specification verification (verification_process.md)
			- Code review (HATS.md)

		Monitoring:
			External code can subscribe to pipeline events for progress monitoring:
			- events.subscribe_pipeline_started (agent ...)
			- events.subscribe_job_started (agent ...)
			- events.subscribe_job_completed (agent ...)
			- events.subscribe_job_failed (agent ...)
			- events.subscribe_pipeline_completed (agent ...)
			- events.subscribe_progress (agent ...)

		Usage:
			create gen.make_class (system_spec, class_spec, ai_client, Void)
			if gen.is_generated then
				class_text := gen.generated_class_text
			end
	]"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"
	design_references: "[
		- D:\prod\reference_docs\claude\NAMING_CONVENTIONS.md
		- D:\prod\reference_docs\claude\contract_patterns.md
		- D:\prod\reference_docs\claude\verification_process.md
		- D:\prod\reference_docs\claude\HATS.md
		- D:\prod\reference_docs\claude\EIFFEL_MENTAL_MODEL.md
		- D:\prod\reference_docs\standards\SEMANTIC_FRAME_NAMING.md
	]"

class
	SCG_CLASS_GEN

create
	make_class,
	make_with_registry

feature {NONE} -- Initialization

	make_class (a_system_spec, a_class_spec: STRING_32; a_ai: detachable AI_CLIENT; a_ai_model: detachable STRING_32)
			-- Create a new class based on `a_system_spec' and `a_class_spec'.
			-- Uses `a_ai' if provided, otherwise defaults to Claude Opus.
			-- Uses default job registry with all standard refinement jobs.
		require
			system_spec_not_empty: not a_system_spec.is_empty
			class_spec_not_empty: not a_class_spec.is_empty
			ai_client_and_model: attached a_ai implies attached a_ai_model
		local
			l_registry: SCG_JOB_REGISTRY
		do
			create l_registry.default_registry
			make_with_registry (a_system_spec, a_class_spec, a_ai, a_ai_model, l_registry)
		ensure
			system_spec_stored: system_spec = a_system_spec
			class_spec_stored: class_spec = a_class_spec
			log_not_void: generation_log /= Void
			events_available: events /= Void
		end

	make_with_registry (a_system_spec, a_class_spec: STRING_32; a_ai: detachable AI_CLIENT; a_ai_model: detachable STRING_32; a_registry: SCG_JOB_REGISTRY)
			-- Create a new class with custom job registry.
			-- Allows custom refinement pipeline configuration.
		require
			system_spec_not_empty: not a_system_spec.is_empty
			class_spec_not_empty: not a_class_spec.is_empty
			ai_client_and_model: attached a_ai implies attached a_ai_model
			registry_not_void: a_registry /= Void
		do
			system_spec := a_system_spec
			class_spec := a_class_spec
			job_registry := a_registry

			-- Setup AI client
			setup_ai_client (a_ai, a_ai_model)

			if is_ai_configured then
				-- Create pipeline
				check attached ai_client as l_ai then
					create pipeline.make (job_registry, l_ai)
				end

				-- Phase 1: Generate initial class
				log_phase ("Phase 1: Initial Class Generation")
				notify_phase_started ("Initial Generation")
				generate_initial_class

				if not has_error then
					-- Phase 2: Apply refinement pipeline
					log_phase ("Phase 2: Assembly-Line Refinement")
					notify_phase_started ("Assembly-Line Refinement")
					apply_refinement_pipeline
				end

				is_generated := not has_error and not generated_class_text.is_empty
			else
				last_error := "Failed to configure AI client"
			end
		ensure
			system_spec_stored: system_spec = a_system_spec
			class_spec_stored: class_spec = a_class_spec
			registry_stored: job_registry = a_registry
			log_not_void: generation_log /= Void
			events_available: events /= Void
		end

feature -- Status

	is_generated: BOOLEAN
			-- Was class successfully generated?

	is_ai_configured: BOOLEAN
			-- Is an AI client available?
		do
			Result := attached ai_client
		end

	has_error: BOOLEAN
			-- Did generation encounter an error?
		do
			Result := not last_error.is_empty
		end

feature -- Access

	system_spec: STRING_32
			-- System specification (JSON or text describing the overall system)

	class_spec: STRING_32
			-- Class specification (describes what the class does)

	generated_class_text: STRING_32
			-- The final generated Eiffel class text
		attribute
			create Result.make_empty
		end

	generation_log: ARRAYED_LIST [STRING_32]
			-- Log of generation phases and actions
		attribute
			create Result.make (10)
		end

	last_error: STRING_32
			-- Error message if generation failed
		attribute
			create Result.make_empty
		end

	ai_client: detachable AI_CLIENT
			-- AI client used for generation
		attribute
			create {CLAUDE_CLIENT} Result.make
		end

	ai_model: STRING_32
			-- Model being used for generation
		attribute
			Result := "claude-opus-4-20250514"
		end

	job_registry: SCG_JOB_REGISTRY
			-- Registry of refinement jobs
		attribute
			create Result.default_registry
		end

	pipeline: detachable SCG_JOB_PIPELINE
			-- The sequential refinement pipeline (legacy, kept for compatibility)

	wave_pipeline: detachable SCG_WAVE_PIPELINE
			-- The SCOOP-parallel wave pipeline (preferred)

	use_parallel: BOOLEAN
			-- Use parallel wave pipeline? (default: False - SCOOP requires careful type handling)
		attribute
			Result := False
		end

feature -- Configuration

	set_use_parallel (a_value: BOOLEAN)
			-- Set whether to use parallel wave pipeline.
		do
			use_parallel := a_value
		ensure
			use_parallel_set: use_parallel = a_value
		end

	set_sequential_mode
			-- Use sequential (legacy) pipeline.
		do
			set_use_parallel (False)
		ensure
			is_sequential: not use_parallel
		end

	set_parallel_mode
			-- Use parallel wave pipeline.
		do
			set_use_parallel (True)
		ensure
			is_parallel: use_parallel
		end

feature -- Events (Pub-Sub for external monitoring)

	events: SCG_PIPELINE_EVENTS
			-- Event publisher for monitoring generation progress.
			-- Subscribe before calling make_class to receive all events.
		attribute
			create Result.make
		end

	subscribe_progress (a_handler: PROCEDURE [INTEGER, INTEGER, STRING_32])
			-- Convenience: Subscribe to progress updates.
			-- Handler receives: completed_jobs, total_jobs, current_job_name
		require
			handler_not_void: a_handler /= Void
		do
			events.subscribe_progress (a_handler)
		end

	subscribe_job_started (a_handler: PROCEDURE [STRING_32, INTEGER, INTEGER])
			-- Convenience: Subscribe to job started events.
			-- Handler receives: job_name, job_index, total_jobs
		require
			handler_not_void: a_handler /= Void
		do
			events.subscribe_job_started (a_handler)
		end

	subscribe_job_completed (a_handler: PROCEDURE [STRING_32, STRING_32, INTEGER, INTEGER])
			-- Convenience: Subscribe to job completed events.
			-- Handler receives: job_name, changes_made, job_index, total_jobs
		require
			handler_not_void: a_handler /= Void
		do
			events.subscribe_job_completed (a_handler)
		end

	subscribe_job_failed (a_handler: PROCEDURE [STRING_32, STRING_32, BOOLEAN])
			-- Convenience: Subscribe to job failed events.
			-- Handler receives: job_name, error_message, is_critical
		require
			handler_not_void: a_handler /= Void
		do
			events.subscribe_job_failed (a_handler)
		end

	subscribe_pipeline_completed (a_handler: PROCEDURE [BOOLEAN, STRING_32])
			-- Convenience: Subscribe to pipeline completed event.
			-- Handler receives: is_success, result_or_error
		require
			handler_not_void: a_handler /= Void
		do
			events.subscribe_pipeline_completed (a_handler)
		end

feature {NONE} -- AI Setup

	setup_ai_client (a_ai: detachable AI_CLIENT; a_model: detachable STRING_32)
			-- Configure AI client, using provided client or using defaults.
			-- Defaults: CLAUDE_CLIENT with model "claude-opus-4-20250514"
		require
			model_valid_for_client: attached a_ai as l_ai and then attached a_model as l_model
				implies l_ai.is_valid_model (l_model)
		do
			if attached a_ai as l_ai and then attached a_model as l_model then
				-- Use provided client and model
				ai_client := l_ai
				ai_model := l_model
				l_ai.set_model (l_model)
			else
				create {CLAUDE_CLIENT} ai_client.make
				create ai_model.make_from_string ({CLAUDE_CLIENT}.model_opus_45)
			end
		ensure
			client_configured: attached ai_client
			model_set: not ai_model.is_empty
			model_is_valid: attached ai_client as c implies c.is_valid_model (ai_model)
			provided_client_used: attached a_ai as l_ai implies ai_client = l_ai
			provided_model_used: attached a_model as l_model implies ai_model.same_string (l_model)
		end

feature {NONE} -- Phase 1: Initial Generation

	generate_initial_class
			-- Generate the initial class text using AI.
		require
			ai_configured: is_ai_configured
		local
			l_prompt: STRING_32
			l_response: AI_RESPONSE
		do
			l_prompt := build_initial_generation_prompt
			log_action ("Sending initial generation prompt (" + l_prompt.count.out + " chars)")

			if attached ai_client as ai then
				l_response := ai.ask_with_system (eiffel_expert_system_prompt, l_prompt)
				if l_response.is_success then
					generated_class_text := extract_eiffel_code (l_response.text)
					log_action ("Initial class generated (" + generated_class_text.count.out + " chars)")
				else
					if attached l_response.error_message as l_err then
						last_error := {STRING_32} "AI generation failed: " + l_err
					else
						last_error := {STRING_32} "AI generation failed: Unknown error"
					end
					log_action ({STRING_32} "ERROR: " + last_error)
				end
			end
		end

	build_initial_generation_prompt: STRING_32
			-- Build the prompt for initial class generation.
		do
			create Result.make (2000)
			Result.append ("Generate an Eiffel class based on the following specifications.%N%N")

			Result.append ("=== SYSTEM SPECIFICATION ===%N")
			Result.append (system_spec)
			Result.append ("%N%N")

			Result.append ("=== CLASS SPECIFICATION ===%N")
			Result.append (class_spec)
			Result.append ("%N%N")

			Result.append ("=== REQUIREMENTS ===%N")
			Result.append ("1. Include a comprehensive 'note' clause that documents:%N")
			Result.append ("   - What the class does%N")
			Result.append ("   - How it works within the system%N")
			Result.append ("   - What it represents in the domain%N")
			Result.append ("2. Use Design by Contract (preconditions, postconditions, invariants)%N")
			Result.append ("3. Follow Eiffel void safety (attached/detachable types)%N")
			Result.append ("4. Use SCOOP-compatible concurrency patterns%N")
			Result.append ("5. Follow Command-Query Separation principle%N")
			Result.append ("6. Use meaningful feature names following Eiffel conventions%N%N")

			Result.append ("Output ONLY the Eiffel class code, wrapped in ```eiffel ... ``` markers.%N")
		ensure
			result_not_empty: not Result.is_empty
		end

feature {NONE} -- Phase 2: Refinement Pipeline

	apply_refinement_pipeline
			-- Apply the assembly-line refinement pipeline to generated class.
			-- Uses parallel wave pipeline if use_parallel is True.
		require
			ai_configured: is_ai_configured
			class_text_exists: not generated_class_text.is_empty
		do
			if use_parallel then
				apply_wave_pipeline
			else
				apply_sequential_pipeline
			end
		end

	apply_wave_pipeline
			-- Apply SCOOP-parallel wave pipeline.
		require
			ai_configured: is_ai_configured
			class_text_exists: not generated_class_text.is_empty
		local
			l_wave: SCG_WAVE_PIPELINE
			l_result: STRING_32
		do
			log_action ("Starting PARALLEL wave pipeline")

			-- Create wave pipeline with AI factory
			create l_wave.make (ai_client_factory, events)
			wave_pipeline := l_wave

			-- Execute
			l_result := l_wave.execute (generated_class_text)

			if l_wave.has_errors then
				-- Wave pipeline had errors but may have partial result
				if not l_result.is_empty and not l_result.same_string (generated_class_text) then
					generated_class_text := l_result
					log_action ("Wave pipeline partially completed (wave " + l_wave.last_wave_completed.out + ")")
				end
				across l_wave.error_log as ic loop
					log_action ("ERROR: " + ic)
				end
				if l_wave.last_wave_completed = 0 then
					last_error := "Wave pipeline failed in wave 1"
				end
			else
				generated_class_text := l_result
				log_action ("Wave pipeline completed successfully (4 waves)")
			end
		end

	apply_sequential_pipeline
			-- Apply sequential job pipeline (legacy mode).
		require
			ai_configured: is_ai_configured
			class_text_exists: not generated_class_text.is_empty
		do
			if attached pipeline as l_pipeline then
				-- Wire up pipeline events to our events
				wire_pipeline_events (l_pipeline)

				-- Execute the pipeline
				log_action ("Starting SEQUENTIAL refinement pipeline with " + job_registry.job_count.out + " jobs")
				l_pipeline.execute (generated_class_text)

				if l_pipeline.is_success then
					generated_class_text := l_pipeline.result_text
					log_action ("Pipeline completed successfully")
				else
					-- Pipeline failed but we may have partial result
					if not l_pipeline.result_text.is_empty then
						generated_class_text := l_pipeline.result_text
						log_action ("Pipeline partially completed: " + l_pipeline.last_error)
					else
						last_error := l_pipeline.last_error
						log_action ("Pipeline failed: " + last_error)
					end
				end

				-- Copy pipeline log to our log
				across l_pipeline.execution_log as ic loop
					log_action (ic)
				end
			end
		end

	ai_client_factory: FUNCTION [AI_CLIENT]
			-- Factory to create AI clients for parallel workers.
		do
			Result := agent create_ai_client
		end

	create_ai_client: AI_CLIENT
			-- Create a new AI client instance for parallel worker.
		do
			create {CLAUDE_CLIENT} Result.make
			Result.set_model (ai_model)
		end

	wire_pipeline_events (a_pipeline: SCG_JOB_PIPELINE)
			-- Connect pipeline events to our event publisher
		require
			pipeline_not_void: a_pipeline /= Void
		do
			-- Forward all pipeline events through our events object
			a_pipeline.events.subscribe_pipeline_started (agent on_pipeline_started)
			a_pipeline.events.subscribe_pipeline_completed (agent on_pipeline_completed)
			a_pipeline.events.subscribe_job_started (agent on_job_started)
			a_pipeline.events.subscribe_job_completed (agent on_job_completed)
			a_pipeline.events.subscribe_job_failed (agent on_job_failed)
			a_pipeline.events.subscribe_progress (agent on_progress)
		end

feature {NONE} -- Event Handlers (forward to our subscribers)

	on_pipeline_started (a_info: STRING_32)
		do
			events.notify_pipeline_started (a_info)
		end

	on_pipeline_completed (a_success: BOOLEAN; a_result_or_error: STRING_32)
		do
			events.notify_pipeline_completed (a_success, a_result_or_error)
		end

	on_job_started (a_job_name: STRING_32; a_index, a_total: INTEGER)
		do
			events.notify_job_started (a_job_name, a_index, a_total)
		end

	on_job_completed (a_job_name, a_changes: STRING_32; a_index, a_total: INTEGER)
		do
			events.notify_job_completed (a_job_name, a_changes, a_index, a_total)
		end

	on_job_failed (a_job_name, a_error: STRING_32; a_is_critical: BOOLEAN)
		do
			events.notify_job_failed (a_job_name, a_error, a_is_critical)
		end

	on_progress (a_completed, a_total: INTEGER; a_current_job: STRING_32)
		do
			events.notify_progress (a_completed, a_total, a_current_job)
		end

	notify_phase_started (a_phase_name: STRING_32)
			-- Notify that a generation phase has started
		do
			events.notify_pipeline_started ("Phase: " + a_phase_name)
		end

feature {NONE} -- Helpers

	extract_eiffel_code (a_response: STRING_32): STRING_32
			-- Extract Eiffel code from AI response (handles ```eiffel ... ``` markers).
		local
			l_start, l_end: INTEGER
		do
			-- Look for ```eiffel marker
			l_start := a_response.substring_index ("```eiffel", 1)
			if l_start > 0 then
				l_start := a_response.index_of ('%N', l_start) + 1
				l_end := a_response.substring_index ("```", l_start)
				if l_end > l_start then
					Result := a_response.substring (l_start, l_end - 1)
				else
					Result := a_response.substring (l_start, a_response.count)
				end
			else
				-- Try plain ``` markers
				l_start := a_response.substring_index ("```", 1)
				if l_start > 0 then
					l_start := a_response.index_of ('%N', l_start) + 1
					l_end := a_response.substring_index ("```", l_start)
					if l_end > l_start then
						Result := a_response.substring (l_start, l_end - 1)
					else
						Result := a_response.substring (l_start, a_response.count)
					end
				else
					-- No markers, return as-is
					Result := a_response.twin
				end
			end
			Result.left_adjust
			Result.right_adjust
		ensure
			result_exists: Result /= Void
		end

	log_phase (a_phase: READABLE_STRING_GENERAL)
			-- Log a phase marker.
		do
			generation_log.extend ({STRING_32} "=== " + a_phase.to_string_32 + {STRING_32} " ===")
		end

	log_action (a_action: READABLE_STRING_GENERAL)
			-- Log an action.
		do
			generation_log.extend ({STRING_32} "  " + a_action.to_string_32)
		end

	eiffel_expert_system_prompt: STRING_32
			-- Compact system prompt (~200 chars vs ~800 original)
		once
			Result := "[
Expert Eiffel dev. DBC, void-safe, SCOOP, CQS.
simple_* over ISE stdlib. Contracts on public features.
Output: ```eiffel class with note clause, no explanation.
]"
		end

feature -- Output

	log_as_string: STRING_32
			-- Return the generation log as a single string.
		do
			create Result.make (1000)
			across generation_log as entry loop
				Result.append (entry)
				Result.append_character ('%N')
			end
		ensure
			result_exists: Result /= Void
		end

invariant
	system_spec_exists: system_spec /= Void
	class_spec_exists: class_spec /= Void
	generated_text_exists: generated_class_text /= Void
	log_exists: generation_log /= Void
	error_exists: last_error /= Void
	registry_exists: job_registry /= Void
	events_exists: events /= Void
	generated_implies_text: is_generated implies not generated_class_text.is_empty

end
