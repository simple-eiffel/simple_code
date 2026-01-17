note
	description: "[
		Result of reuse discovery for a class specification.

		Contains:
		- Overall recommendation (best reuse strategy)
		- Ranked list of candidates
		- API summary for prompt injection
		- Prompt enhancement text (complete text to add to prompt)
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_REUSE_RESULT

create
	make,
	make_empty

feature {NONE} -- Initialization

	make (a_spec_name: STRING)
			-- Create result for specification `a_spec_name'.
		require
			spec_name_not_empty: not a_spec_name.is_empty
		do
			spec_name := a_spec_name
			create recommendation.make_write_fresh
			create candidates.make (10)
			create api_summary.make_empty
			create prompt_enhancement.make_empty
			create do_not_reinvent.make (5)
			create suggested_imports.make (5)
			create inherit_candidates.make (5)
			create compose_candidates.make (5)
			create internal_candidates.make (5)
			create suggested_ancestors.make (3)
			create semantic_alignments.make (3)
			confidence := 0.0
		ensure
			spec_name_set: spec_name = a_spec_name
		end

	make_empty
			-- Create empty result (no reuse found).
		do
			create spec_name.make_empty
			create recommendation.make_write_fresh
			create candidates.make (0)
			create api_summary.make_empty
			create prompt_enhancement.make_empty
			create do_not_reinvent.make (0)
			create suggested_imports.make (0)
			create inherit_candidates.make (0)
			create compose_candidates.make (0)
			create internal_candidates.make (0)
			create suggested_ancestors.make (0)
			create semantic_alignments.make (0)
			confidence := 0.0
		ensure
			is_empty: is_empty
		end

feature -- Access

	spec_name: STRING
			-- Name of specification this result is for

	recommendation: SCG_REUSE_STRATEGY
			-- Recommended reuse strategy (best option)

	candidates: ARRAYED_LIST [SCG_REUSE_CANDIDATE]
			-- All discovered candidates, sorted by match score (best first)

	api_summary: STRING
			-- Summary of available APIs for prompt injection

	prompt_enhancement: STRING
			-- Complete text to add to generation prompt

	confidence: REAL_64
			-- Confidence in the recommendation (0.0 to 1.0)

	do_not_reinvent: ARRAYED_LIST [STRING]
			-- List of features/classes to NOT reinvent
			-- e.g., ["parse - use SIMPLE_CSV.parse()", "row_at - use SIMPLE_CSV.row_at()"]

	suggested_imports: ARRAYED_LIST [STRING]
			-- Libraries to import based on candidates

	inherit_candidates: ARRAYED_LIST [STRING]
			-- Classes to consider inheriting from (is-a relationships)
			-- Format: "CLASS_NAME (library) - reason"

	compose_candidates: ARRAYED_LIST [STRING]
			-- Classes to consider composing with (has-a relationships)
			-- Format: "CLASS_NAME (library) - reason"

	internal_candidates: ARRAYED_LIST [SCG_REUSE_CANDIDATE]
			-- Candidates from same project (internal reuse)

	suggested_ancestors: ARRAYED_LIST [STRING]
			-- Suggested deferred ancestors to create when semantic alignment detected
			-- Format: "DEFERRED_CLASS_NAME - shared by CLASS1, CLASS2 - reason"

	semantic_alignments: ARRAYED_LIST [STRING]
			-- Detected semantic alignments between classes
			-- Format: "CLASS1 ~ CLASS2: feature1, feature2 (consider common ancestor)"

feature -- Status report

	is_empty: BOOLEAN
			-- Were no candidates found?
		do
			Result := candidates.is_empty
		end

	has_candidates: BOOLEAN
			-- Were candidates found?
		do
			Result := not candidates.is_empty
		end

	has_strong_match: BOOLEAN
			-- Is there at least one strong match (>= 0.8)?
		do
			Result := across candidates as c some c.is_strong_match end
		end

	suggests_reuse: BOOLEAN
			-- Does the recommendation suggest reusing existing code?
		do
			Result := recommendation.suggests_reuse
		end

	best_candidate: detachable SCG_REUSE_CANDIDATE
			-- The best matching candidate, if any
		do
			if not candidates.is_empty then
				Result := candidates.first
			end
		end

feature -- Element change

	set_recommendation (a_recommendation: SCG_REUSE_STRATEGY)
			-- Set the recommended strategy.
		require
			recommendation_not_void: a_recommendation /= Void
		do
			recommendation := a_recommendation
		ensure
			recommendation_set: recommendation = a_recommendation
		end

	set_confidence (a_confidence: REAL_64)
			-- Set confidence level.
		require
			confidence_valid: a_confidence >= 0.0 and a_confidence <= 1.0
		do
			confidence := a_confidence
		ensure
			confidence_set: confidence = a_confidence
		end

	add_candidate (a_candidate: SCG_REUSE_CANDIDATE)
			-- Add a candidate to the list, maintaining sort order by score.
		require
			candidate_not_void: a_candidate /= Void
		local
			l_inserted: BOOLEAN
			i: INTEGER
		do
			-- Insert in sorted order (highest score first)
			from
				i := 1
				l_inserted := False
			until
				i > candidates.count or l_inserted
			loop
				if a_candidate.match_score > candidates.i_th (i).match_score then
					candidates.go_i_th (i)
					candidates.put_left (a_candidate)
					l_inserted := True
				end
				i := i + 1
			end
			if not l_inserted then
				candidates.extend (a_candidate)
			end
		ensure
			candidate_added: candidates.has (a_candidate)
		end

	add_do_not_reinvent (a_item: STRING)
			-- Add an item to the "do not reinvent" list.
		require
			item_not_empty: not a_item.is_empty
		do
			do_not_reinvent.extend (a_item)
		ensure
			item_added: do_not_reinvent.has (a_item)
		end

	add_suggested_import (a_library: STRING)
			-- Add a library to suggested imports (if not already present).
		require
			library_not_empty: not a_library.is_empty
		do
			if not suggested_imports.has (a_library) then
				suggested_imports.extend (a_library)
			end
		end

	add_inherit_candidate (a_class_name, a_library, a_reason: STRING)
			-- Add a class as an inheritance candidate (is-a relationship).
		require
			class_not_empty: not a_class_name.is_empty
			reason_not_empty: not a_reason.is_empty
		local
			l_entry: STRING
		do
			create l_entry.make (100)
			l_entry.append (a_class_name)
			l_entry.append (" (")
			l_entry.append (a_library)
			l_entry.append (") - ")
			l_entry.append (a_reason)
			inherit_candidates.extend (l_entry)
		ensure
			added: inherit_candidates.count = old inherit_candidates.count + 1
		end

	add_compose_candidate (a_class_name, a_library, a_reason: STRING)
			-- Add a class as a composition candidate (has-a relationship).
		require
			class_not_empty: not a_class_name.is_empty
			reason_not_empty: not a_reason.is_empty
		local
			l_entry: STRING
		do
			create l_entry.make (100)
			l_entry.append (a_class_name)
			l_entry.append (" (")
			l_entry.append (a_library)
			l_entry.append (") - ")
			l_entry.append (a_reason)
			compose_candidates.extend (l_entry)
		ensure
			added: compose_candidates.count = old compose_candidates.count + 1
		end

	add_internal_candidate (a_candidate: SCG_REUSE_CANDIDATE)
			-- Add a candidate from the same project (internal reuse).
		require
			candidate_not_void: a_candidate /= Void
		do
			internal_candidates.extend (a_candidate)
		ensure
			added: internal_candidates.has (a_candidate)
		end

	add_suggested_ancestor (a_ancestor_name: STRING; a_shared_by: ARRAYED_LIST [STRING]; a_reason: STRING)
			-- Add a suggested deferred ancestor class.
			-- This is recommended when multiple classes share semantic patterns.
		require
			name_not_empty: not a_ancestor_name.is_empty
			shared_by_at_least_two: a_shared_by.count >= 2
			reason_not_empty: not a_reason.is_empty
		local
			l_entry: STRING
		do
			create l_entry.make (200)
			l_entry.append (a_ancestor_name)
			l_entry.append (" - shared by ")
			across a_shared_by as sb loop
				if @sb.cursor_index > 1 then
					l_entry.append (", ")
				end
				l_entry.append (sb)
			end
			l_entry.append (" - ")
			l_entry.append (a_reason)
			suggested_ancestors.extend (l_entry)
		ensure
			added: suggested_ancestors.count = old suggested_ancestors.count + 1
		end

	add_semantic_alignment (a_class1, a_class2: STRING; a_shared_features: ARRAYED_LIST [STRING])
			-- Record a semantic alignment between two classes.
			-- This suggests they might need a common ancestor.
		require
			class1_not_empty: not a_class1.is_empty
			class2_not_empty: not a_class2.is_empty
			features_not_empty: not a_shared_features.is_empty
		local
			l_entry: STRING
		do
			create l_entry.make (150)
			l_entry.append (a_class1)
			l_entry.append (" ~ ")
			l_entry.append (a_class2)
			l_entry.append (": ")
			across a_shared_features as sf loop
				if @sf.cursor_index > 1 then
					l_entry.append (", ")
				end
				l_entry.append (sf)
			end
			l_entry.append (" (consider common ancestor)")
			semantic_alignments.extend (l_entry)
		ensure
			added: semantic_alignments.count = old semantic_alignments.count + 1
		end

	set_api_summary (a_summary: STRING)
			-- Set the API summary text.
		require
			summary_not_void: a_summary /= Void
		do
			api_summary := a_summary
		ensure
			api_summary_set: api_summary = a_summary
		end

feature -- Output

	build_prompt_enhancement
			-- Build the complete prompt enhancement text from current state.
		local
			l_text: STRING
		do
			create l_text.make (3000)

			l_text.append ("=== REUSE ANALYSIS ===%N")
			l_text.append ("Recommendation: ")
			l_text.append (recommendation.name)
			if has_candidates then
				l_text.append (" ")
				l_text.append (candidates.first.class_name)
			end
			l_text.append ("%N")
			l_text.append ("Confidence: ")
			l_text.append (formatted_confidence)
			l_text.append ("%N%N")

			-- Inheritance candidates (is-a relationships)
			if not inherit_candidates.is_empty then
				l_text.append ("=== INHERITANCE OPTIONS (is-a) ===%N")
				l_text.append ("Consider inheriting from these classes:%N")
				across inherit_candidates as ic loop
					l_text.append ("  INHERIT: ")
					l_text.append (ic)
					l_text.append ("%N")
				end
				l_text.append ("%N")
			end

			-- Composition candidates (has-a relationships)
			if not compose_candidates.is_empty then
				l_text.append ("=== COMPOSITION OPTIONS (has-a) ===%N")
				l_text.append ("Consider using these classes as attributes:%N")
				across compose_candidates as ic loop
					l_text.append ("  USE: ")
					l_text.append (ic)
					l_text.append ("%N")
				end
				l_text.append ("%N")
			end

			-- Internal candidates (same project reuse)
			if not internal_candidates.is_empty then
				l_text.append ("=== INTERNAL REUSE (same project) ===%N")
				l_text.append ("Consider reusing these classes from your own project:%N")
				across internal_candidates as ic loop
					l_text.append ("  REUSE: ")
					l_text.append (ic.class_name)
					if not ic.feature_name.is_empty then
						l_text.append (".")
						l_text.append (ic.feature_name)
					end
					l_text.append (" (score: ")
					l_text.append (((ic.match_score * 100).truncated_to_integer).out)
					l_text.append ("%%)")
					l_text.append ("%N")
				end
				l_text.append ("%N")
			end

			-- Semantic alignments (detected patterns suggesting common ancestors)
			if not semantic_alignments.is_empty then
				l_text.append ("=== SEMANTIC ALIGNMENT DETECTED ===%N")
				l_text.append ("These classes share features and may need a common ancestor:%N")
				across semantic_alignments as sa loop
					l_text.append ("  ALIGNED: ")
					l_text.append (sa)
					l_text.append ("%N")
				end
				l_text.append ("%N")
			end

			-- Suggested ancestors (factoring opportunities)
			if not suggested_ancestors.is_empty then
				l_text.append ("=== SUGGESTED DEFERRED ANCESTORS ===%N")
				l_text.append ("Consider factoring common behavior into these deferred classes:%N")
				across suggested_ancestors as anc loop
					l_text.append ("  FACTOR TO: ")
					l_text.append (anc)
					l_text.append ("%N")
				end
				l_text.append ("%N")
			end

			-- API Summary section
			if not api_summary.is_empty then
				l_text.append ("=== AVAILABLE APIs (from ECF dependencies) ===%N")
				l_text.append (api_summary)
				l_text.append ("%N")
			end

			-- Similar classes section
			if has_candidates then
				l_text.append ("=== SIMILAR CLASSES IN KB ===%N")
				across candidates as c loop
					l_text.append (c.as_prompt_text)
				end
				l_text.append ("%N")
			end

			-- Reuse guidance section
			if not do_not_reinvent.is_empty then
				l_text.append ("=== REUSE GUIDANCE ===%N")
				across do_not_reinvent as item loop
					l_text.append ("- DO NOT reinvent: ")
					l_text.append (item)
					l_text.append ("%N")
				end
				l_text.append ("- GENERATE: Only custom logic not available in existing libraries%N%N")
			end

			-- Suggested imports
			if not suggested_imports.is_empty then
				l_text.append ("=== SUGGESTED IMPORTS ===%N")
				across suggested_imports as lib loop
					l_text.append ("- ")
					l_text.append (lib)
					l_text.append ("%N")
				end
			end

			prompt_enhancement := l_text
		ensure
			prompt_enhancement_built: not prompt_enhancement.is_empty
		end

	as_summary: STRING
			-- One-line summary for display
		do
			create Result.make (100)
			Result.append ("Reuse result for ")
			Result.append (spec_name)
			Result.append (": ")
			Result.append (recommendation.name)
			Result.append (" (")
			Result.append (candidates.count.out)
			Result.append (" candidates, confidence=")
			Result.append (formatted_confidence)
			Result.append (")")
		ensure
			result_not_empty: not Result.is_empty
		end

	as_detailed_report: STRING
			-- Multi-line detailed report
		do
			create Result.make (500)
			Result.append ("=== REUSE DISCOVERY REPORT ===%N")
			Result.append ("Specification: ")
			Result.append (spec_name)
			Result.append ("%N")
			Result.append ("Recommendation: ")
			Result.append (recommendation.name)
			Result.append (" - ")
			Result.append (recommendation.description)
			Result.append ("%N")
			Result.append ("Confidence: ")
			Result.append (formatted_confidence)
			Result.append ("%N")
			Result.append ("Candidates found: ")
			Result.append (candidates.count.out)
			Result.append ("%N%N")

			if has_candidates then
				Result.append ("Top candidates:%N")
				across candidates as c loop
					Result.append ("  ")
					Result.append (c.as_summary)
					Result.append ("%N")
				end
			end
		ensure
			result_not_empty: not Result.is_empty
		end

feature {NONE} -- Implementation

	formatted_confidence: STRING
			-- Confidence formatted as percentage
		do
			create Result.make (5)
			Result.append (((confidence * 100).truncated_to_integer).out)
			Result.append ("%%")
		end

invariant
	candidates_exists: candidates /= Void
	recommendation_exists: recommendation /= Void
	confidence_valid: confidence >= 0.0 and confidence <= 1.0
	do_not_reinvent_exists: do_not_reinvent /= Void
	suggested_imports_exists: suggested_imports /= Void
	inherit_candidates_exists: inherit_candidates /= Void
	compose_candidates_exists: compose_candidates /= Void
	internal_candidates_exists: internal_candidates /= Void
	suggested_ancestors_exists: suggested_ancestors /= Void
	semantic_alignments_exists: semantic_alignments /= Void

end
