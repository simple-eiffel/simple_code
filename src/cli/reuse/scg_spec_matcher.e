note
	description: "[
		Semantic specification matcher for reuse discovery.

		Computes match scores between class specifications and
		existing classes/features in the knowledge base.

		Scoring factors:
		- Name similarity (class/feature names)
		- Signature compatibility (parameter types)
		- Contract coverage (pre/postconditions)
		- Description keyword overlap
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_SPEC_MATCHER

create
	make

feature {NONE} -- Initialization

	make
			-- Create specification matcher.
		do
			-- Ready to match
		end

feature -- Matching

	match_class_name (a_spec_name, a_class_name: STRING): REAL_64
			-- Score how well class names match (0.0 to 1.0).
		require
			spec_not_empty: not a_spec_name.is_empty
			class_not_empty: not a_class_name.is_empty
		local
			l_spec_upper, l_class_upper: STRING
			l_spec_words, l_class_words: LIST [STRING]
			l_common: INTEGER
		do
			l_spec_upper := a_spec_name.as_upper
			l_class_upper := a_class_name.as_upper

			-- Exact match
			if l_spec_upper.is_equal (l_class_upper) then
				Result := 1.0
			-- Prefix/suffix match
			elseif l_spec_upper.starts_with (l_class_upper) or
			       l_class_upper.starts_with (l_spec_upper) then
				Result := 0.8
			elseif l_spec_upper.ends_with (l_class_upper) or
			       l_class_upper.ends_with (l_spec_upper) then
				Result := 0.7
			-- Substring match
			elseif l_spec_upper.has_substring (l_class_upper) or
			       l_class_upper.has_substring (l_spec_upper) then
				Result := 0.6
			else
				-- Word overlap scoring
				l_spec_words := split_words (l_spec_upper)
				l_class_words := split_words (l_class_upper)
				l_common := count_common_words (l_spec_words, l_class_words)
				if l_spec_words.count > 0 then
					Result := l_common / l_spec_words.count.max (l_class_words.count)
				else
					Result := 0.0
				end
			end
		ensure
			valid_range: Result >= 0.0 and Result <= 1.0
		end

	match_feature_name (a_spec_feature, a_feature_name: STRING): REAL_64
			-- Score how well feature names match (0.0 to 1.0).
		require
			spec_not_empty: not a_spec_feature.is_empty
			feature_not_empty: not a_feature_name.is_empty
		local
			l_spec_lower, l_feat_lower: STRING
		do
			l_spec_lower := a_spec_feature.as_lower
			l_feat_lower := a_feature_name.as_lower

			-- Exact match
			if l_spec_lower.is_equal (l_feat_lower) then
				Result := 1.0
			-- Common transformations (parse vs parse_string, load vs load_from_file)
			elseif l_spec_lower.starts_with (l_feat_lower) or
			       l_feat_lower.starts_with (l_spec_lower) then
				Result := 0.85
			-- Substring match
			elseif l_spec_lower.has_substring (l_feat_lower) or
			       l_feat_lower.has_substring (l_spec_lower) then
				Result := 0.6
			else
				-- Word component match
				Result := word_component_match (l_spec_lower, l_feat_lower)
			end
		ensure
			valid_range: Result >= 0.0 and Result <= 1.0
		end

	match_description (a_spec_desc, a_class_desc: STRING): REAL_64
			-- Score how well descriptions match by keyword overlap.
		require
			spec_desc_not_void: a_spec_desc /= Void
			class_desc_not_void: a_class_desc /= Void
		local
			l_spec_words, l_class_words: LIST [STRING]
			l_common: INTEGER
			l_spec_lower, l_class_lower: STRING
		do
			if a_spec_desc.is_empty or a_class_desc.is_empty then
				Result := 0.0
			else
				l_spec_lower := a_spec_desc.as_lower
				l_class_lower := a_class_desc.as_lower

				l_spec_words := extract_keywords (l_spec_lower)
				l_class_words := extract_keywords (l_class_lower)

				l_common := count_common_words (l_spec_words, l_class_words)
				if l_spec_words.count > 0 then
					Result := l_common / l_spec_words.count.max (1)
					Result := Result.min (1.0) -- Cap at 1.0
				else
					Result := 0.0
				end
			end
		ensure
			valid_range: Result >= 0.0 and Result <= 1.0
		end

	signature_compatible (a_sig1, a_sig2: STRING): BOOLEAN
			-- Are two signatures compatible (same return type and parameter count)?
		local
			l_params1, l_params2: INTEGER
			l_has_result1, l_has_result2: BOOLEAN
		do
			-- Count parameters (commas + 1 if not empty)
			l_params1 := parameter_count (a_sig1)
			l_params2 := parameter_count (a_sig2)

			-- Check for result type
			l_has_result1 := a_sig1.has (':') and then a_sig1.index_of (':', 1) < a_sig1.index_of (')', 1).max (a_sig1.count)
			l_has_result2 := a_sig2.has (':')

			-- Compatible if same parameter count and both have/lack return type
			Result := l_params1 = l_params2 and l_has_result1 = l_has_result2
		end

	contracts_subsume (a_source_contracts, a_target_contracts: STRING): BOOLEAN
			-- Do source contracts cover what target contracts require?
			-- (i.e., source has at least as strong preconditions and postconditions)
		do
			-- Simple heuristic: if source has contracts and they're non-empty, consider it a match
			-- A more sophisticated implementation would parse and compare contracts
			if a_source_contracts.is_empty then
				-- No contracts in source - always compatible (no constraints)
				Result := True
			elseif a_target_contracts.is_empty then
				-- Source has contracts, target doesn't need them - compatible
				Result := True
			else
				-- Both have contracts - check for keyword overlap
				Result := a_source_contracts.has_substring ("require") implies
				          a_target_contracts.has_substring ("require")
			end
		end

	compute_overall_score (a_name_score, a_desc_score: REAL_64;
	                       a_feature_matches: INTEGER; a_total_features: INTEGER): REAL_64
			-- Compute overall match score from component scores.
		require
			scores_valid: a_name_score >= 0.0 and a_desc_score >= 0.0
		local
			l_feature_score: REAL_64
		do
			-- Weight factors
			-- Name: 40%, Description: 20%, Feature coverage: 40%
			if a_total_features > 0 then
				l_feature_score := a_feature_matches / a_total_features
			else
				l_feature_score := 0.0
			end

			Result := (a_name_score * 0.4) +
			          (a_desc_score * 0.2) +
			          (l_feature_score * 0.4)

			Result := Result.min (1.0)
		ensure
			valid_range: Result >= 0.0 and Result <= 1.0
		end

feature -- Strategy Recommendation

	recommend_strategy (a_score: REAL_64; a_is_class_match: BOOLEAN; a_has_feature_match: BOOLEAN): SCG_REUSE_STRATEGY
			-- Recommend reuse strategy based on match results.
		require
			score_valid: a_score >= 0.0 and a_score <= 1.0
		do
			if a_score >= 0.9 and a_is_class_match then
				-- Near-exact class match - use as-is
				create Result.make_use_existing
			elseif a_score >= 0.7 and a_is_class_match then
				-- Good class match - inherit and extend
				create Result.make_inherit_from
			elseif a_score >= 0.5 or a_has_feature_match then
				-- Moderate match or useful features - compose
				create Result.make_compose_with
			else
				-- Low match - write fresh
				create Result.make_write_fresh
			end
		ensure
			result_not_void: Result /= Void
		end

feature {NONE} -- Implementation

	split_words (a_text: STRING): LIST [STRING]
			-- Split text into words by underscore.
		do
			Result := a_text.split ('_')
		end

	count_common_words (a_list1, a_list2: LIST [STRING]): INTEGER
			-- Count words that appear in both lists.
		do
			across a_list1 as w1 loop
				across a_list2 as w2 loop
					if w1.is_equal (w2) then
						Result := Result + 1
					end
				end
			end
		end

	word_component_match (a_word1, a_word2: STRING): REAL_64
			-- Match by word components (underscore-separated).
		local
			l_parts1, l_parts2: LIST [STRING]
			l_common: INTEGER
		do
			l_parts1 := a_word1.split ('_')
			l_parts2 := a_word2.split ('_')
			l_common := count_common_words (l_parts1, l_parts2)
			if l_parts1.count.max (l_parts2.count) > 0 then
				Result := l_common / l_parts1.count.max (l_parts2.count)
			else
				Result := 0.0
			end
		end

	extract_keywords (a_text: STRING): ARRAYED_LIST [STRING]
			-- Extract meaningful keywords from text.
		local
			l_words: LIST [STRING]
		do
			create Result.make (10)
			-- Split on common delimiters
			l_words := a_text.split (' ')
			across l_words as w loop
				w.left_adjust
				w.right_adjust
				-- Filter out stop words and short words
				if w.count >= 3 and not is_stop_word (w) then
					Result.extend (w.twin)
				end
			end
		end

	is_stop_word (a_word: STRING): BOOLEAN
			-- Is this a common stop word to ignore?
		do
			Result := a_word.is_equal ("the") or
			          a_word.is_equal ("and") or
			          a_word.is_equal ("for") or
			          a_word.is_equal ("with") or
			          a_word.is_equal ("from") or
			          a_word.is_equal ("that") or
			          a_word.is_equal ("this") or
			          a_word.is_equal ("class") or
			          a_word.is_equal ("feature")
		end

	parameter_count (a_signature: STRING): INTEGER
			-- Count parameters in a signature.
		local
			l_paren_start, l_paren_end: INTEGER
			l_params: STRING
		do
			l_paren_start := a_signature.index_of ('(', 1)
			l_paren_end := a_signature.index_of (')', 1)
			if l_paren_start > 0 and l_paren_end > l_paren_start then
				l_params := a_signature.substring (l_paren_start + 1, l_paren_end - 1)
				l_params.left_adjust
				l_params.right_adjust
				if l_params.is_empty then
					Result := 0
				else
					-- Count semicolons (separators) + 1
					Result := 1
					across l_params as c loop
						if c = ';' then
							Result := Result + 1
						end
					end
				end
			end
		end

end
