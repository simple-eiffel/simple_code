note
	description: "[
		Validator for generated Eiffel code.

		Validation pipeline:
		1. Syntax check: Uses simple_eiffel_parser
		2. Contract check: Verifies presence of preconditions, postconditions, invariants
		3. Completeness check: No TODOs, all features implemented
		4. Style check: Naming conventions, structure

		Produces detailed validation results and can generate
		refinement prompts for Claude to fix issues.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_VALIDATOR

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize validator.
		do
			create syntax_errors.make (5)
			create contract_warnings.make (5)
			create completeness_issues.make (5)
			create refinement_prompt.make_empty
		end

feature -- Status

	is_valid: BOOLEAN
			-- Is the code valid (syntax + contracts)?
		do
			Result := syntax_valid and contracts_adequate
		end

	syntax_valid: BOOLEAN
			-- Does code pass syntax validation?

	contracts_adequate: BOOLEAN
			-- Are contracts adequate?
		do
			Result := contract_warnings.is_empty
		end

	is_complete: BOOLEAN
			-- Is the code complete (no TODOs, etc.)?
		do
			Result := completeness_issues.is_empty
		end

	needs_refinement_prompt: BOOLEAN
			-- Should a refinement prompt be generated?
		do
			Result := not is_valid or not is_complete
		end

feature -- Access

	syntax_errors: ARRAYED_LIST [STRING_32]
			-- Syntax errors found

	contract_warnings: ARRAYED_LIST [STRING_32]
			-- Contract-related warnings

	completeness_issues: ARRAYED_LIST [STRING_32]
			-- Completeness issues (TODOs, stubs, etc.)

	features_with_preconditions: INTEGER
			-- Count of features with preconditions

	features_with_postconditions: INTEGER
			-- Count of features with postconditions

	has_invariant: BOOLEAN
			-- Does class have an invariant clause?

	total_features: INTEGER
			-- Total feature count

	refinement_prompt: STRING_32
			-- Generated refinement prompt (if needs_refinement_prompt)

feature -- Validation

	validate (a_code: STRING_32)
			-- Validate Eiffel code.
		require
			code_not_empty: not a_code.is_empty
		do
			-- Reset state
			syntax_errors.wipe_out
			contract_warnings.wipe_out
			completeness_issues.wipe_out
			features_with_preconditions := 0
			features_with_postconditions := 0
			has_invariant := False
			total_features := 0
			syntax_valid := False
			refinement_prompt.wipe_out

			-- Run validation pipeline
			validate_syntax (a_code)

			if syntax_valid then
				validate_contracts (a_code)
				validate_completeness (a_code)
				validate_style (a_code)
			end

			-- Generate refinement prompt if needed
			if needs_refinement_prompt then
				generate_refinement_prompt (a_code)
			end
		end

feature {NONE} -- Syntax Validation

	validate_syntax (a_code: STRING_32)
			-- Validate syntax using simple_eiffel_parser.
		local
			l_parser: SIMPLE_EIFFEL_PARSER
			l_ast: EIFFEL_AST
		do
			create l_parser.make
			l_ast := l_parser.parse_string (a_code.to_string_8)

			if l_ast.has_errors then
				across l_ast.parse_errors as ic loop
					syntax_errors.extend (ic.message.to_string_32)
				end
				syntax_valid := False
			else
				syntax_valid := True

				-- Extract feature info for contract analysis
				if not l_ast.classes.is_empty then
					across l_ast.classes as class_ic loop
						total_features := total_features + class_ic.features.count
						across class_ic.features as feat_ic loop
							if not feat_ic.precondition.is_empty then
								features_with_preconditions := features_with_preconditions + 1
							end
							if not feat_ic.postcondition.is_empty then
								features_with_postconditions := features_with_postconditions + 1
							end
						end
					end
				end
			end
		end

feature {NONE} -- Contract Validation

	validate_contracts (a_code: STRING_32)
			-- Validate contract completeness.
		local
			l_lines: LIST [STRING_32]
			l_has_require, l_has_ensure: BOOLEAN
			l_in_feature: BOOLEAN
			l_feature_name: STRING_32
			l_current_feature: STRING_32
		do
			-- Check for invariant
			has_invariant := a_code.has_substring ("invariant")

			if not has_invariant then
				contract_warnings.extend ("Class has no invariant clause")
			end

			-- Count commands/queries without postconditions
			l_lines := a_code.split ('%N')
			l_has_require := False
			l_has_ensure := False
			l_in_feature := False
			create l_feature_name.make_empty
			create l_current_feature.make_empty

			across l_lines as ic loop
				l_current_feature := ic.twin
				l_current_feature.left_adjust

				-- Detect feature start
				if is_feature_declaration (l_current_feature) then
					-- Check previous feature
					if l_in_feature and not l_feature_name.is_empty then
						if not l_has_ensure and is_command_or_query_needing_postcondition (l_feature_name) then
							contract_warnings.extend ("Feature '" + l_feature_name + "' has no postcondition")
						end
					end

					l_feature_name := extract_feature_name (l_current_feature)
					l_in_feature := True
					l_has_require := False
					l_has_ensure := False

				elseif l_current_feature.starts_with ("require") then
					l_has_require := True
				elseif l_current_feature.starts_with ("ensure") then
					l_has_ensure := True
				end
			end

			-- Check last feature
			if l_in_feature and not l_feature_name.is_empty then
				if not l_has_ensure and is_command_or_query_needing_postcondition (l_feature_name) then
					contract_warnings.extend ("Feature '" + l_feature_name + "' has no postcondition")
				end
			end
		end

	is_feature_declaration (a_line: STRING_32): BOOLEAN
			-- Is this line a feature declaration (name followed by parameters or colon)?
		local
			l_trimmed: STRING_32
		do
			l_trimmed := a_line.twin
			l_trimmed.left_adjust

			-- Skip keywords, comments, and clause markers
			if not l_trimmed.is_empty then
				Result := not l_trimmed.starts_with ("--")
					and not l_trimmed.starts_with ("do")
					and not l_trimmed.starts_with ("local")
					and not l_trimmed.starts_with ("require")
					and not l_trimmed.starts_with ("ensure")
					and not l_trimmed.starts_with ("end")
					and not l_trimmed.starts_with ("feature")
					and not l_trimmed.starts_with ("class")
					and not l_trimmed.starts_with ("inherit")
					and not l_trimmed.starts_with ("create")
					and not l_trimmed.starts_with ("note")
					and not l_trimmed.starts_with ("invariant")
					and not l_trimmed.starts_with ("if")
					and not l_trimmed.starts_with ("then")
					and not l_trimmed.starts_with ("else")
					and not l_trimmed.starts_with ("loop")
					and not l_trimmed.starts_with ("from")
					and not l_trimmed.starts_with ("until")
					and not l_trimmed.starts_with ("across")
					and (l_trimmed.has (':') or l_trimmed.has ('('))
					and l_trimmed.item (1).is_alpha
			end
		end

	extract_feature_name (a_line: STRING_32): STRING_32
			-- Extract feature name from declaration line.
		local
			i: INTEGER
		do
			create Result.make_empty
			from i := 1 until i > a_line.count or not a_line.item (i).is_alpha_numeric and a_line.item (i) /= '_' loop
				Result.append_character (a_line.item (i))
				i := i + 1
			end
		end

	is_command_or_query_needing_postcondition (a_name: STRING_32): BOOLEAN
			-- Should this feature have a postcondition?
			-- Commands (setters, state changers) and queries that compute values need postconditions.
		do
			-- Skip attributes and initialization features for simplicity
			Result := not a_name.is_case_insensitive_equal ("make")
				and not a_name.starts_with ("internal_")
				and not a_name.starts_with ("c_")
		end

feature {NONE} -- Completeness Validation

	validate_completeness (a_code: STRING_32)
			-- Check for incomplete implementations.
		do
			-- Check for TODO markers
			if a_code.has_substring ("TODO") or a_code.has_substring ("FIXME") then
				completeness_issues.extend ("Code contains TODO/FIXME markers")
			end

			-- Check for stub implementations
			if a_code.has_substring ("do nothing") or a_code.has_substring ("-- stub") then
				completeness_issues.extend ("Code contains stub implementations")
			end

			-- Check for empty do blocks (likely stubs)
			if a_code.has_substring ("do%N%T%Tend") or a_code.has_substring ("do%N%T%T%Tend") then
				completeness_issues.extend ("Code may have empty do blocks")
			end

			-- Check for unimplemented deferred features
			if a_code.has_substring ("deferred") and not a_code.has_substring ("deferred class") then
				completeness_issues.extend ("Code has deferred features that need implementation")
			end
		end

feature {NONE} -- Style Validation

	validate_style (a_code: STRING_32)
			-- Check for style issues.
		do
			-- Check for missing note clause
			if not a_code.has_substring ("note") then
				completeness_issues.extend ("Class missing 'note' documentation clause")
			end

			-- Check for old-style end marker
			if a_code.has_substring ("end ") and a_code.count > 5 then
				if a_code.substring (a_code.substring_index ("end ", 1) + 4, a_code.count).has_substring ("--") then
					-- That's fine, just a comment
				else
					completeness_issues.extend ("Use just 'end' instead of 'end CLASS_NAME'")
				end
			end
		end

feature {NONE} -- Refinement Prompt

	generate_refinement_prompt (a_code: STRING_32)
			-- Generate refinement prompt from validation issues.
		local
			l_all_issues: ARRAYED_LIST [STRING_32]
		do
			create l_all_issues.make (10)

			-- Collect all issues
			across syntax_errors as ic loop
				l_all_issues.extend ("SYNTAX ERROR: " + ic)
			end
			across contract_warnings as ic loop
				l_all_issues.extend ("CONTRACT: " + ic)
			end
			across completeness_issues as ic loop
				l_all_issues.extend ("COMPLETENESS: " + ic)
			end

			-- Build prompt (caller should use SCG_PROMPT_BUILDER for full prompt)
			create refinement_prompt.make (1000)
			refinement_prompt.append ("The generated code has the following issues:%N%N")
			across l_all_issues as ic loop
				refinement_prompt.append ("- " + ic + "%N")
			end
		end

invariant
	syntax_errors_exists: syntax_errors /= Void
	contract_warnings_exists: contract_warnings /= Void
	completeness_issues_exists: completeness_issues /= Void
	refinement_prompt_exists: refinement_prompt /= Void

end
