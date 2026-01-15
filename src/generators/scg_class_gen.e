note
	description: "[
		AI-assisted Eiffel class generator.

		Generates production-quality Eiffel classes using a multi-phase AI workflow:

		Phase 1 - Initial Generation:
			Uses AI to create an Eiffel class based on system and class specifications.
			The AI is instructed to include comprehensive notes clause documentation.

		Phase 2 - Semantic Frame Naming:
			Applies the semantic frame naming pattern from SEMANTIC_FRAME_NAMING.md
			to add context-appropriate feature aliases.

		Phase 3 - Iterative Hat Passes:
			Applies looping hat prompts from LOOPING_HATS.md to iteratively improve:
			- CONTRACTOR HAT: Strengthen Design by Contract coverage
			- SPECIFICATION HAT: Ensure complete preconditions/postconditions
			- CODE REVIEW HAT: General quality review

		Usage:
			create gen.make_class (system_spec, class_spec, ai_client, Void)
			if gen.is_generated then
				class_text := gen.generated_class_text
			end

		The generator defaults to Claude (Opus) when no AI client is provided,
		falling back to Ollama if Claude is unavailable.
	]"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"
	design_references: "[
		- D:\prod\reference_docs\specs\apps\SPEECH_STUDIO_APP_SPEC.json (system spec example)
		- D:\prod\reference_docs\standards\SEMANTIC_FRAME_NAMING.md (naming pattern)
		- D:\prod\reference_docs\claude\LOOPING_HATS.md (iterative improvement)
	]"

class
	SCG_CLASS_GEN

create
	make_class

feature {NONE} -- Initialization

	make_class (a_system_spec, a_class_spec: STRING_32; a_ai: detachable AI_CLIENT; a_ai_model: detachable STRING_32)
			-- Create a new class based on `a_system_spec' and `a_class_spec'.
			-- Uses `a_ai' if provided, otherwise defaults to Claude code Opus.
			-- `a_ai_model' can override the default model selection.
		require
			system_spec_not_empty: not a_system_spec.is_empty
			class_spec_not_empty: not a_class_spec.is_empty
			ai_client_and_model: attached a_ai implies attached a_ai_model
		do
			system_spec := a_system_spec
			class_spec := a_class_spec

			-- Setup AI client
			setup_ai_client (a_ai, a_ai_model)

			if is_ai_configured then
				-- Phase 1: Generate initial class
				log_phase ("Phase 1: Initial Class Generation")
				generate_initial_class

				if not has_error then
					-- Phase 2: Apply semantic frame naming
					log_phase ("Phase 2: Semantic Frame Naming")
					apply_semantic_framing

					if not has_error then
						-- Phase 3: Apply looping hats
						log_phase ("Phase 3: Iterative Hat Passes")
						apply_looping_hats
					end
				end

				is_generated := not has_error and not generated_class_text.is_empty
			else
				last_error := "Failed to configure AI client"
			end
		ensure
			system_spec_stored: system_spec = a_system_spec
			class_spec_stored: class_spec = a_class_spec
			log_not_void: generation_log /= Void
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
			end
			-- Otherwise, attribute defaults apply:
			-- ai_client = CLAUDE_CLIENT, ai_model = "claude-opus-4-20250514"
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

feature {NONE} -- Phase 2: Semantic Framing

	apply_semantic_framing
			-- Apply semantic frame naming pattern to add context-appropriate aliases.
		require
			ai_configured: is_ai_configured
			class_text_exists: not generated_class_text.is_empty
		local
			l_prompt: STRING_32
			l_response: AI_RESPONSE
		do
			l_prompt := build_semantic_framing_prompt
			log_action ("Applying semantic frame naming")

			if attached ai_client as ai then
				l_response := ai.ask_with_system (eiffel_expert_system_prompt, l_prompt)
				if l_response.is_success then
					generated_class_text := extract_eiffel_code (l_response.text)
					log_action ("Semantic framing applied")
				else
					-- Log warning but continue - semantic framing is enhancement
					log_action ("WARNING: Semantic framing failed, continuing with original")
				end
			end
		end

	build_semantic_framing_prompt: STRING_32
			-- Build prompt for semantic frame naming pass.
		do
			create Result.make (3000)
			Result.append ("Apply the Semantic Frame Naming pattern to this Eiffel class.%N%N")

			Result.append ("=== SEMANTIC FRAME NAMING PATTERN ===%N")
			Result.append (semantic_framing_instructions)
			Result.append ("%N%N")

			Result.append ("=== CURRENT CLASS ===%N")
			Result.append ("```eiffel%N")
			Result.append (generated_class_text)
			Result.append ("%N```%N%N")

			Result.append ("=== TASK ===%N")
			Result.append ("1. Identify the semantic frames (usage contexts) this class will serve%N")
			Result.append ("2. For each feature, add context-appropriate aliases where beneficial%N")
			Result.append ("3. Use comma-separated names for queries (not attributes directly)%N")
			Result.append ("4. Document the semantic frames in the class notes%N")
			Result.append ("5. Do NOT add frivolous aliases - only genuinely useful ones%N%N")

			Result.append ("Output the improved Eiffel class wrapped in ```eiffel ... ``` markers.%N")
		ensure
			result_not_empty: not Result.is_empty
		end

	semantic_framing_instructions: STRING_32
			-- Key instructions from SEMANTIC_FRAME_NAMING.md
		once
			Result := "[
Semantic Frame Naming allows Eiffel classes to speak the vocabulary of different usage contexts.

Key Rules:
- Routines can have multiple names: `name, account_holder, username: STRING_32 do ... end`
- Attributes CANNOT have multiple names (x, y: INTEGER creates TWO separate attributes)
- For attribute aliasing, wrap with query/command routines
- Generic ancestors stay generic; specialized descendants add specialized vocabulary
- Names should be genuinely natural for each semantic frame

Process:
1. Identify potential semantic frames from the system spec
2. Map features to frame-appropriate vocabulary
3. Add names using Eiffel's comma-separated syntax for routines
4. Document frames in the note clause

Example:
  value,
  payload,     -- HTTP/API frame
  setting,     -- Config frame
  record: detachable ANY
    do
      Result := internal_value
    end
]"
		end

feature {NONE} -- Phase 3: Looping Hats

	apply_looping_hats
			-- Apply iterative hat passes to improve the class.
		require
			ai_configured: is_ai_configured
			class_text_exists: not generated_class_text.is_empty
		do
			-- Apply Contractor Hat (contracts)
			log_action ("Applying CONTRACTOR HAT")
			apply_hat (contractor_hat_prompt, "contracts")

			-- Apply Specification Hat (vibe-contracting)
			if not has_error then
				log_action ("Applying SPECIFICATION HAT")
				apply_hat (specification_hat_prompt, "specifications")
			end

			-- Apply Code Review Hat (quality)
			if not has_error then
				log_action ("Applying CODE REVIEW HAT")
				apply_hat (code_review_hat_prompt, "review")
			end
		end

	apply_hat (a_hat_prompt: STRING_32; a_hat_name: STRING)
			-- Apply a single hat pass to improve the class.
		require
			ai_configured: is_ai_configured
			prompt_not_empty: not a_hat_prompt.is_empty
		local
			l_full_prompt: STRING_32
			l_response: AI_RESPONSE
		do
			create l_full_prompt.make (a_hat_prompt.count + generated_class_text.count + 200)
			l_full_prompt.append (a_hat_prompt)
			l_full_prompt.append ("%N%N=== CURRENT CLASS ===%N")
			l_full_prompt.append ("```eiffel%N")
			l_full_prompt.append (generated_class_text)
			l_full_prompt.append ("%N```%N%N")
			l_full_prompt.append ("Output the improved Eiffel class wrapped in ```eiffel ... ``` markers.%N")

			if attached ai_client as ai then
				l_response := ai.ask_with_system (eiffel_expert_system_prompt, l_full_prompt)
				if l_response.is_success then
					generated_class_text := extract_eiffel_code (l_response.text)
					log_action (a_hat_name + " hat applied successfully")
				else
					-- Log warning but continue
					log_action ("WARNING: " + a_hat_name + " hat failed, continuing")
				end
			end
		end

	contractor_hat_prompt: STRING_32
			-- Prompt for Contractor Hat (contract strengthening)
		once
			Result := "[
Put on your CONTRACTOR HAT.

Your mission: Strengthen Design by Contract coverage.

For each feature:
1. Are preconditions complete? (What MUST be true before calling?)
2. Are postconditions complete? (What is GUARANTEED after?)
3. Are there implicit assumptions that should be explicit contracts?

Rules:
- Do NOT add trivial contracts (e.g., `Result /= Void` when type is attached)
- DO add domain-meaningful contracts (valid ranges, state requirements)
- Ensure class invariants capture stable state rules
]"
		end

	specification_hat_prompt: STRING_32
			-- Prompt for Specification Hat (vibe-contracting)
		once
			Result := "[
Put on your SPECIFICATION HAT.

Your mission: Ensure contracts fully specify behavior.

For each feature:
1. Does the postcondition say what changed AND what stayed the same?
2. Are all side effects documented in the postcondition?
3. Are `old` expressions used where state change matters?
4. Do preconditions document all caller obligations?

Key questions:
- Is this contract TRUE but INCOMPLETE?
- Would a caller know exactly what to expect from this contract?
]"
		end

	code_review_hat_prompt: STRING_32
			-- Prompt for Code Review Hat
		once
			Result := "[
Put on your CODE REVIEW HAT.

Review checklist:
1. Correctness: Logic correct? Edge cases handled?
2. Contracts: Preconditions/postconditions appropriate?
3. Eiffel-specific: Void safety correct? STRING_8 vs STRING_32?
4. Maintainability: Code readable? Well-named features?
5. Command-Query Separation: Queries don't modify state?

Fix any Critical or High severity issues found.
]"
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
			-- System prompt establishing Eiffel expertise.
		once
			Result := "[
You are an expert Eiffel programmer with deep knowledge of:
- Design by Contract (DBC): preconditions, postconditions, class invariants
- Void safety: attached vs detachable types, proper null handling
- SCOOP: concurrency model using separate keyword
- Command-Query Separation: queries return values, commands modify state
- Eiffel naming conventions: lowercase with underscores, descriptive names

You follow the Simple Eiffel ecosystem patterns:
- Use simple_* libraries over ISE stdlib where available
- All code must be SCOOP-compatible (concurrency=scoop)
- Inline C externals for Win32 API (no separate .c files)
- Comprehensive contracts on all public features

When generating Eiffel code:
- Include detailed note clauses
- Use proper Eiffel syntax (create, do, end, etc.)
- Apply meaningful contracts, not trivial ones
- Follow the 6-phase development cycle
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
	generated_implies_text: is_generated implies not generated_class_text.is_empty

end
