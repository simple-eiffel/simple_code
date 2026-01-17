note
	description: "[
		Assembles feature implementations into a class skeleton.

		Takes a class skeleton (signatures + contracts + placeholder bodies)
		and a set of generated implementations, replacing the placeholders
		with actual code.

		Handles:
		- Replacing placeholder bodies with implementations
		- Adding helper features if any were generated
		- Preserving class structure (note, inherit, invariant)

		Usage:
			create assembler.make (skeleton_text)
			assembler.add_implementation ("put", put_implementation)
			assembler.add_implementation ("item", item_implementation)
			complete_class := assembler.assemble
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_FEATURE_ASSEMBLER

create
	make

feature {NONE} -- Initialization

	make (a_skeleton: STRING_32)
			-- Create assembler with class skeleton.
		require
			skeleton_not_empty: not a_skeleton.is_empty
		do
			skeleton_text := a_skeleton
			create implementations.make (10)
			create helper_features.make (5)
			create assembly_log.make (10)
			create last_error.make_empty
		ensure
			skeleton_set: skeleton_text = a_skeleton
			implementations_empty: implementations.is_empty
		end

feature -- Access

	skeleton_text: STRING_32
			-- Class skeleton text

	implementations: HASH_TABLE [STRING_32, STRING_32]
			-- Feature implementations keyed by feature name

	helper_features: ARRAYED_LIST [STRING_32]
			-- Helper features to add

	assembly_log: ARRAYED_LIST [STRING_32]
			-- Log of assembly operations

	last_error: STRING_32
			-- Error message if assembly failed

feature -- Status

	has_error: BOOLEAN
			-- Did assembly encounter an error?
		do
			Result := not last_error.is_empty
		end

feature -- Building

	add_implementation (a_feature_name: STRING_32; a_implementation: STRING_32)
			-- Add implementation for feature.
		require
			name_not_empty: not a_feature_name.is_empty
			impl_not_empty: not a_implementation.is_empty
		do
			implementations.force (a_implementation, a_feature_name)
			log_action ("Added implementation for: " + a_feature_name)
		ensure
			has_implementation: implementations.has (a_feature_name)
		end

	add_helper (a_helper_text: STRING_32)
			-- Add a helper feature.
		require
			helper_not_empty: not a_helper_text.is_empty
		do
			helper_features.extend (a_helper_text)
			log_action ("Added helper feature")
		ensure
			helper_added: helper_features.count = old helper_features.count + 1
		end

	add_from_feature_gen (a_gen: SCG_FEATURE_GEN)
			-- Add implementation from feature generator.
		require
			gen_not_void: a_gen /= Void
			gen_succeeded: a_gen.is_generated
		do
			add_implementation (a_gen.feature_spec.name, a_gen.implementation_text)
			across a_gen.helper_features as ic loop
				add_helper (ic)
			end
		end

feature -- Assembly

	assemble: STRING_32
			-- Assemble complete class from skeleton and implementations.
		local
			l_result: STRING_32
		do
			log_action ("Starting assembly...")
			l_result := skeleton_text.twin

			-- Replace each placeholder with implementation
			from
				implementations.start
			until
				implementations.after
			loop
				l_result := replace_placeholder (l_result, implementations.key_for_iteration, implementations.item_for_iteration)
				implementations.forth
			end

			-- Add helper features before invariant (or at end if no invariant)
			if not helper_features.is_empty then
				l_result := insert_helpers (l_result)
			end

			log_action ("Assembly complete (" + implementations.count.out + " features, " + helper_features.count.out + " helpers)")
			Result := l_result
		ensure
			result_not_empty: not Result.is_empty
		end

feature {NONE} -- Implementation

	replace_placeholder (a_text: STRING_32; a_feature_name: STRING_32; a_implementation: STRING_32): STRING_32
			-- Replace placeholder body for feature with actual implementation.
		local
			l_feature_start, l_do_start, l_end_pos: INTEGER
			l_placeholder_start, l_placeholder_end: INTEGER
		do
			Result := a_text.twin

			-- Find the feature
			l_feature_start := find_feature_start (Result, a_feature_name)

			if l_feature_start > 0 then
				-- Find the placeholder: do check False then end end
				l_do_start := Result.substring_index ("do", l_feature_start)

				if l_do_start > 0 then
					-- Check if this is a placeholder (contains "check False")
					l_placeholder_start := Result.substring_index ("check False", l_do_start)

					if l_placeholder_start > 0 and l_placeholder_start < l_do_start + 100 then
						-- Find the end of the placeholder block
						l_placeholder_end := find_placeholder_end (Result, l_do_start)

						if l_placeholder_end > l_do_start then
							-- Replace placeholder with implementation
							Result.replace_substring (a_implementation, l_do_start, l_placeholder_end)
							log_action ("Replaced placeholder for: " + a_feature_name)
						else
							log_action ("WARNING: Could not find placeholder end for: " + a_feature_name)
						end
					else
						-- Not a placeholder, may already have implementation
						log_action ("Skipping (not placeholder): " + a_feature_name)
					end
				else
					log_action ("WARNING: No 'do' found for: " + a_feature_name)
				end
			else
				log_action ("WARNING: Feature not found: " + a_feature_name)
			end
		end

	find_feature_start (a_text: STRING_32; a_feature_name: STRING_32): INTEGER
			-- Find start position of feature definition.
		local
			l_pos: INTEGER
			l_line_start: INTEGER
			l_found: BOOLEAN
		do
			-- Look for feature name at start of a line (with possible indentation)
			from l_pos := 1 until l_found or l_pos = 0 loop
				l_pos := a_text.substring_index (a_feature_name, l_pos)
				if l_pos > 0 then
					-- Check if this is at line start (after tabs/spaces only)
					l_line_start := a_text.last_index_of ('%N', l_pos) + 1
					if is_feature_definition (a_text, l_line_start, l_pos, a_feature_name) then
						Result := l_pos
						l_found := True
					else
						l_pos := l_pos + a_feature_name.count
					end
				end
			end
		end

	is_feature_definition (a_text: STRING_32; a_line_start, a_name_pos: INTEGER; a_name: STRING_32): BOOLEAN
			-- Is this occurrence a feature definition (not just a reference)?
		local
			l_before: STRING_32
			l_after_pos: INTEGER
			l_after_char: CHARACTER_32
		do
			-- Text between line start and name should be only whitespace
			if a_name_pos > a_line_start then
				l_before := a_text.substring (a_line_start, a_name_pos - 1)
				l_before.left_adjust
				l_before.right_adjust
				Result := l_before.is_empty
			else
				Result := True
			end

			-- Character after name should be space, (, :, or newline
			if Result then
				l_after_pos := a_name_pos + a_name.count
				if l_after_pos <= a_text.count then
					l_after_char := a_text.item (l_after_pos)
					Result := l_after_char = ' ' or l_after_char = '(' or l_after_char = ':' or l_after_char = '%N' or l_after_char = '%T'
				end
			end
		end

	find_placeholder_end (a_text: STRING_32; a_do_start: INTEGER): INTEGER
			-- Find end of placeholder block (the 'end' after 'do check False then end').
		local
			l_depth: INTEGER
			l_pos: INTEGER
			l_found: BOOLEAN
		do
			-- The placeholder is: do check False then end end
			-- We need to find the outer 'end'
			l_depth := 1
			l_pos := a_do_start + 2 -- Skip "do"

			from until l_found or l_pos > a_text.count loop
				if a_text.substring_index ("do", l_pos) = l_pos then
					l_depth := l_depth + 1
					l_pos := l_pos + 2
				elseif a_text.substring_index ("if", l_pos) = l_pos and then
				       (l_pos + 2 > a_text.count or else not a_text.item (l_pos + 2).is_alpha) then
					l_depth := l_depth + 1
					l_pos := l_pos + 2
				elseif a_text.substring_index ("from", l_pos) = l_pos then
					l_depth := l_depth + 1
					l_pos := l_pos + 4
				elseif a_text.substring_index ("inspect", l_pos) = l_pos then
					l_depth := l_depth + 1
					l_pos := l_pos + 7
				elseif a_text.substring_index ("check", l_pos) = l_pos then
					l_depth := l_depth + 1
					l_pos := l_pos + 5
				elseif a_text.substring_index ("end", l_pos) = l_pos and then
				       (l_pos + 3 > a_text.count or else not a_text.item (l_pos + 3).is_alpha) then
					l_depth := l_depth - 1
					if l_depth = 0 then
						Result := l_pos + 2 -- Position at end of "end"
						l_found := True
					else
						l_pos := l_pos + 3
					end
				else
					l_pos := l_pos + 1
				end
			end
		end

	insert_helpers (a_text: STRING_32): STRING_32
			-- Insert helper features into class.
		local
			l_invariant_pos: INTEGER
			l_end_pos: INTEGER
			l_insert_pos: INTEGER
			l_helpers: STRING_32
		do
			Result := a_text.twin

			-- Build helpers text
			create l_helpers.make (500)
			l_helpers.append ("%N%Nfeature {NONE} -- Implementation helpers%N%N")
			across helper_features as ic loop
				l_helpers.append (ic)
				l_helpers.append ("%N%N")
			end

			-- Find insertion point (before invariant, or before final end)
			l_invariant_pos := Result.substring_index ("invariant", 1)
			if l_invariant_pos > 0 then
				l_insert_pos := l_invariant_pos
			else
				-- Find the final "end" of the class
				l_end_pos := Result.count
				from until l_end_pos < 3 or else Result.substring (l_end_pos - 2, l_end_pos).same_string ("end") loop
					l_end_pos := l_end_pos - 1
				end
				l_insert_pos := l_end_pos - 2
			end

			Result.insert_string (l_helpers, l_insert_pos)
			log_action ("Inserted " + helper_features.count.out + " helper features")
		end

	log_action (a_message: STRING_32)
			-- Log an action.
		do
			assembly_log.extend (a_message)
		end

invariant
	skeleton_exists: skeleton_text /= Void
	implementations_exists: implementations /= Void
	helper_features_exists: helper_features /= Void
	assembly_log_exists: assembly_log /= Void
	last_error_exists: last_error /= Void

end
