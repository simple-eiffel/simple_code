note
	description: "[
		Generates Eiffel feature implementation from specification.

		Takes a feature spec (signature + contracts) and class context,
		generates the implementation (do...end block) that satisfies
		the contracts.

		The contracts act as guardrails - the AI must generate code
		that satisfies the preconditions and postconditions.

		SCOOP-compatible: Can run on separate processor for parallel
		feature generation within a class.

		Usage:
			create gen.make (feature_spec, class_context, ai_client)
			if gen.is_generated then
				implementation := gen.implementation_text
			end
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_FEATURE_GEN

create
	make

feature {NONE} -- Initialization

	make (a_spec: SCG_FEATURE_SPEC; a_class_context: STRING_32; a_ai: AI_CLIENT)
			-- Generate implementation for `a_spec' within `a_class_context'.
		require
			spec_not_void: a_spec /= Void
			spec_has_name: not a_spec.name.is_empty
			context_not_empty: not a_class_context.is_empty
			ai_not_void: a_ai /= Void
		do
			feature_spec := a_spec
			class_context := a_class_context
			ai_client := a_ai
			create implementation_text.make_empty
			create full_feature_text.make_empty
			create last_error.make_empty
			create helper_features.make (2)

			generate_implementation
		ensure
			spec_set: feature_spec = a_spec
			context_set: class_context = a_class_context
		end

feature -- Status

	is_generated: BOOLEAN
			-- Was implementation successfully generated?

	has_error: BOOLEAN
			-- Did generation fail?
		do
			Result := not last_error.is_empty
		end

	needs_helpers: BOOLEAN
			-- Does this feature need helper features?
		do
			Result := not helper_features.is_empty
		end

feature -- Access

	feature_spec: SCG_FEATURE_SPEC
			-- The feature specification being implemented

	class_context: STRING_32
			-- Class context (other feature signatures for reference)

	ai_client: AI_CLIENT
			-- AI client for generation

	implementation_text: STRING_32
			-- Generated implementation (just the do...end block content)

	full_feature_text: STRING_32
			-- Complete feature text (signature + contracts + implementation)

	helper_features: ARRAYED_LIST [STRING_32]
			-- Any helper features the AI determined are needed

	last_error: STRING_32
			-- Error message if generation failed

feature {NONE} -- Generation

	generate_implementation
			-- Generate the feature implementation.
		local
			l_prompt: STRING_32
			l_response: AI_RESPONSE
		do
			l_prompt := build_implementation_prompt

			l_response := ai_client.ask_with_system (implementation_system_prompt, l_prompt)

			if l_response.is_success then
				parse_response (l_response.text)
				if not implementation_text.is_empty then
					build_full_feature_text
					is_generated := True
				else
					last_error := "No implementation extracted from AI response"
				end
			else
				if attached l_response.error_message as err then
					last_error := err.twin
				else
					last_error := "Unknown AI error"
				end
			end
		end

	build_implementation_prompt: STRING_32
			-- Build prompt for implementation generation.
		do
			create Result.make (2000)
			Result.append ("Generate the IMPLEMENTATION for this Eiffel feature.%N%N")

			Result.append ("=== FEATURE TO IMPLEMENT ===%N")
			Result.append (feature_spec.signature)
			Result.append ("%N")

			if feature_spec.has_preconditions then
				Result.append ("    require%N")
				Result.append ("        ")
				Result.append (feature_spec.require_clause)
				Result.append ("%N")
			end

			if feature_spec.has_postconditions then
				Result.append ("    ensure%N")
				Result.append ("        ")
				Result.append (feature_spec.ensure_clause)
				Result.append ("%N")
			end

			if not feature_spec.note_clause.is_empty then
				Result.append ("%NINTENT: ")
				Result.append (feature_spec.note_clause)
				Result.append ("%N")
			end

			Result.append ("%N=== CLASS CONTEXT (other features you can call) ===%N")
			Result.append (class_context)
			Result.append ("%N")

			Result.append ("%N=== OUTPUT FORMAT ===%N")
			Result.append ("Provide ONLY the implementation in this format:%N")
			Result.append ("IMPL:%N")
			Result.append ("local%N")
			Result.append ("    -- local variables if needed%N")
			Result.append ("do%N")
			Result.append ("    -- implementation code%N")
			Result.append ("end%N")
			Result.append ("%N")
			Result.append ("If you need helper features, add:%N")
			Result.append ("HELPER:%N")
			Result.append ("helper_name: TYPE%N")
			Result.append ("    do%N")
			Result.append ("        -- helper code%N")
			Result.append ("    end%N")
		end

	implementation_system_prompt: STRING_32
			-- System prompt for implementation generation.
		once
			Result := {STRING_32} "[
Expert Eiffel implementer. Generate feature bodies that satisfy contracts.
Use existing class features where possible.
Keep implementations simple and direct.
STRING_32 concat: use {STRING_32} "text" + var (NOT "text" + var).
Output format: IMPL: followed by local/do/end block.
HELPER: for any needed private helpers.
]"
		end

	parse_response (a_response: STRING_32)
			-- Parse AI response to extract implementation and helpers.
		local
			l_impl_start, l_helper_start: INTEGER
			l_impl_text, l_helper_text: STRING_32
		do
			-- Find IMPL: section
			l_impl_start := a_response.substring_index ("IMPL:", 1)
			l_helper_start := a_response.substring_index ("HELPER:", 1)

			if l_impl_start > 0 then
				l_impl_start := l_impl_start + 5 -- Skip "IMPL:"
				if l_helper_start > l_impl_start then
					l_impl_text := a_response.substring (l_impl_start, l_helper_start - 1)
				else
					l_impl_text := a_response.substring (l_impl_start, a_response.count)
				end
				l_impl_text.left_adjust
				l_impl_text.right_adjust
				implementation_text := extract_implementation_block (l_impl_text)
			else
				-- Try to extract from code block
				implementation_text := extract_from_code_block (a_response)
			end

			-- Extract helpers if any
			if l_helper_start > 0 then
				l_helper_text := a_response.substring (l_helper_start + 7, a_response.count)
				parse_helpers (l_helper_text)
			end
		end

	extract_implementation_block (a_text: STRING_32): STRING_32
			-- Extract local/do...end block from text.
		local
			l_do_pos, l_end_pos: INTEGER
			l_local_pos: INTEGER
		do
			create Result.make_empty

			l_local_pos := a_text.substring_index ("local", 1)
			l_do_pos := a_text.substring_index ("do", 1)

			if l_do_pos > 0 then
				-- Find matching end
				l_end_pos := find_matching_end (a_text, l_do_pos)
				if l_end_pos > 0 then
					if l_local_pos > 0 and l_local_pos < l_do_pos then
						Result := a_text.substring (l_local_pos, l_end_pos + 2) -- +2 for "end"
					else
						Result := a_text.substring (l_do_pos, l_end_pos + 2)
					end
				end
			end
		end

	extract_from_code_block (a_response: STRING_32): STRING_32
			-- Extract implementation from ```eiffel block.
		local
			l_start, l_end: INTEGER
		do
			create Result.make_empty
			l_start := a_response.substring_index ("```eiffel", 1)
			if l_start > 0 then
				l_start := a_response.index_of ('%N', l_start) + 1
				l_end := a_response.substring_index ("```", l_start)
				if l_end > l_start then
					Result := extract_implementation_block (a_response.substring (l_start, l_end - 1))
				end
			end
		end

	find_matching_end (a_text: STRING_32; a_start: INTEGER): INTEGER
			-- Find position of 'end' matching 'do' at a_start.
		local
			l_depth: INTEGER
			l_pos: INTEGER
			l_word: STRING_32
		do
			Result := 0
			l_depth := 1
			l_pos := a_start + 2 -- Skip "do"

			from until l_pos > a_text.count or l_depth = 0 loop
				l_word := next_keyword (a_text, l_pos)
				if l_word.same_string ("do") or l_word.same_string ("if") or l_word.same_string ("from") or l_word.same_string ("inspect") then
					l_depth := l_depth + 1
					l_pos := l_pos + l_word.count
				elseif l_word.same_string ("end") then
					l_depth := l_depth - 1
					if l_depth = 0 then
						Result := l_pos - 3 -- Position before "end"
					end
					l_pos := l_pos + 3
				elseif l_word.is_empty then
					l_pos := l_pos + 1
				else
					l_pos := l_pos + l_word.count
				end
			end
		end

	next_keyword (a_text: STRING_32; a_pos: INTEGER): STRING_32
			-- Get next keyword starting at or after a_pos.
		local
			l_start, l_end: INTEGER
		do
			create Result.make_empty
			-- Skip whitespace
			from l_start := a_pos until l_start > a_text.count or a_text.item (l_start).is_alpha loop
				l_start := l_start + 1
			end
			if l_start <= a_text.count then
				from l_end := l_start until l_end > a_text.count or not a_text.item (l_end).is_alpha loop
					l_end := l_end + 1
				end
				if l_end > l_start then
					Result := a_text.substring (l_start, l_end - 1)
				end
			end
		end

	parse_helpers (a_helper_text: STRING_32)
			-- Parse helper features from response.
		local
			l_lines: LIST [STRING_32]
			l_current: STRING_32
			l_in_helper: BOOLEAN
		do
			l_lines := a_helper_text.split ('%N')
			create l_current.make_empty

			across l_lines as ic loop
				if ic.starts_with ("HELPER:") then
					if not l_current.is_empty then
						helper_features.extend (l_current)
					end
					l_current := ic.substring (8, ic.count)
					l_in_helper := True
				elseif l_in_helper then
					l_current.append ("%N")
					l_current.append (ic)
				end
			end

			if not l_current.is_empty then
				helper_features.extend (l_current)
			end
		end

	build_full_feature_text
			-- Build complete feature text from spec and implementation.
		do
			create full_feature_text.make (500)

			-- Feature note if any
			if not feature_spec.note_clause.is_empty then
				full_feature_text.append ("%T")
				full_feature_text.append (feature_spec.name)
				full_feature_text.append ("%N")
				full_feature_text.append ("%T%T%T-- ")
				full_feature_text.append (feature_spec.note_clause)
				full_feature_text.append ("%N")
			else
				full_feature_text.append ("%T")
				full_feature_text.append (feature_spec.signature)
				full_feature_text.append ("%N")
			end

			-- Require clause
			if feature_spec.has_preconditions then
				full_feature_text.append ("%T%Trequire%N")
				full_feature_text.append ("%T%T%T")
				full_feature_text.append (feature_spec.require_clause)
				full_feature_text.append ("%N")
			end

			-- Implementation
			full_feature_text.append ("%T%T")
			full_feature_text.append (implementation_text)
			full_feature_text.append ("%N")

			-- Ensure clause
			if feature_spec.has_postconditions then
				full_feature_text.append ("%T%Tensure%N")
				full_feature_text.append ("%T%T%T")
				full_feature_text.append (feature_spec.ensure_clause)
				full_feature_text.append ("%N")
			end

			full_feature_text.append ("%T%Tend%N")
		end

invariant
	feature_spec_exists: feature_spec /= Void
	class_context_exists: class_context /= Void
	implementation_exists: implementation_text /= Void
	full_feature_exists: full_feature_text /= Void
	last_error_exists: last_error /= Void
	helper_features_exists: helper_features /= Void
	generated_has_implementation: is_generated implies not implementation_text.is_empty

end
