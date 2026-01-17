note
	description: "[
		Represents a single reuse candidate discovered during code generation.

		Contains information about a class or feature that could potentially
		be reused when generating new code, including:
		- Library and class information
		- Feature signature and contracts
		- Match score indicating how well it fits the specification
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_REUSE_CANDIDATE

create
	make,
	make_for_class,
	make_for_feature

feature {NONE} -- Initialization

	make (a_library, a_class: STRING; a_feature: detachable STRING; a_signature: STRING; a_contracts: STRING; a_score: REAL_64)
			-- Create reuse candidate.
		require
			library_not_empty: not a_library.is_empty
			class_not_empty: not a_class.is_empty
			score_valid: a_score >= 0.0 and a_score <= 1.0
		do
			library_name := a_library
			class_name := a_class
			if attached a_feature then
				feature_name := a_feature
			else
				create feature_name.make_empty
			end
			signature := a_signature
			contracts := a_contracts
			match_score := a_score
			create description.make_empty
			create strategy.make_compose_with
		ensure
			library_set: library_name = a_library
			class_set: class_name = a_class
			score_set: match_score = a_score
		end

	make_for_class (a_library, a_class, a_description: STRING; a_score: REAL_64)
			-- Create candidate for class-level reuse.
		require
			library_not_empty: not a_library.is_empty
			class_not_empty: not a_class.is_empty
			score_valid: a_score >= 0.0 and a_score <= 1.0
		do
			library_name := a_library
			class_name := a_class
			create feature_name.make_empty
			create signature.make_empty
			create contracts.make_empty
			description := a_description
			match_score := a_score
			create strategy.make_compose_with
		ensure
			is_class_level: is_class_level
		end

	make_for_feature (a_library, a_class, a_feature, a_signature: STRING; a_score: REAL_64)
			-- Create candidate for feature-level reuse.
		require
			library_not_empty: not a_library.is_empty
			class_not_empty: not a_class.is_empty
			feature_not_empty: not a_feature.is_empty
			score_valid: a_score >= 0.0 and a_score <= 1.0
		do
			library_name := a_library
			class_name := a_class
			feature_name := a_feature
			signature := a_signature
			create contracts.make_empty
			create description.make_empty
			match_score := a_score
			create strategy.make_compose_with
		ensure
			is_feature_level: is_feature_level
		end

feature -- Access

	library_name: STRING
			-- Name of library containing this candidate (e.g., "simple_csv")

	class_name: STRING
			-- Name of class (e.g., "SIMPLE_CSV")

	feature_name: STRING
			-- Name of feature if applicable, empty for class-level

	signature: STRING
			-- Feature signature if applicable (e.g., "parse (a_content: STRING)")

	contracts: STRING
			-- Preconditions and postconditions

	description: STRING
			-- Description of what this class/feature does

	match_score: REAL_64
			-- Score from 0.0 to 1.0 indicating match quality
			-- Higher = better match

	strategy: SCG_REUSE_STRATEGY
			-- Recommended reuse strategy for this candidate

feature -- Status report

	is_class_level: BOOLEAN
			-- Is this a class-level candidate (not feature-specific)?
		do
			Result := feature_name.is_empty
		end

	is_feature_level: BOOLEAN
			-- Is this a feature-level candidate?
		do
			Result := not feature_name.is_empty
		end

	is_strong_match: BOOLEAN
			-- Is this a strong match (>= 0.8)?
		do
			Result := match_score >= 0.8
		end

	is_moderate_match: BOOLEAN
			-- Is this a moderate match (>= 0.5 and < 0.8)?
		do
			Result := match_score >= 0.5 and match_score < 0.8
		end

	is_weak_match: BOOLEAN
			-- Is this a weak match (< 0.5)?
		do
			Result := match_score < 0.5
		end

	has_contracts: BOOLEAN
			-- Does this candidate have contracts defined?
		do
			Result := not contracts.is_empty
		end

feature -- Element change

	set_description (a_description: STRING)
			-- Set the description.
		require
			description_not_void: a_description /= Void
		do
			description := a_description
		ensure
			description_set: description = a_description
		end

	set_contracts (a_contracts: STRING)
			-- Set the contracts.
		require
			contracts_not_void: a_contracts /= Void
		do
			contracts := a_contracts
		ensure
			contracts_set: contracts = a_contracts
		end

	set_strategy (a_strategy: SCG_REUSE_STRATEGY)
			-- Set the recommended reuse strategy.
		require
			strategy_not_void: a_strategy /= Void
		do
			strategy := a_strategy
		ensure
			strategy_set: strategy = a_strategy
		end

feature -- Output

	full_name: STRING
			-- Full qualified name (LIBRARY.CLASS.feature or LIBRARY.CLASS)
		do
			create Result.make (50)
			Result.append (library_name)
			Result.append (".")
			Result.append (class_name)
			if is_feature_level then
				Result.append (".")
				Result.append (feature_name)
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	short_name: STRING
			-- Short name for display (CLASS.feature or CLASS)
		do
			create Result.make (30)
			Result.append (class_name)
			if is_feature_level then
				Result.append (".")
				Result.append (feature_name)
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	as_prompt_text: STRING
			-- Format candidate for inclusion in prompt
		do
			create Result.make (200)
			if is_feature_level then
				Result.append ("  ")
				Result.append (feature_name)
				if not signature.is_empty then
					Result.append (": ")
					Result.append (signature)
				end
				Result.append ("%N")
				if has_contracts then
					Result.append ("    ")
					Result.append (contracts)
					Result.append ("%N")
				end
			else
				Result.append ("class ")
				Result.append (class_name)
				if not description.is_empty then
					Result.append (" -- ")
					Result.append (description)
				end
				Result.append ("%N")
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	as_summary: STRING
			-- One-line summary for display
		do
			create Result.make (100)
			Result.append (short_name)
			Result.append (" (")
			Result.append (library_name)
			Result.append (") score=")
			Result.append (formatted_score)
			Result.append (" [")
			Result.append (strategy.name)
			Result.append ("]")
		ensure
			result_not_empty: not Result.is_empty
		end

feature {NONE} -- Implementation

	formatted_score: STRING
			-- Score formatted as percentage
		do
			create Result.make (5)
			Result.append (((match_score * 100).truncated_to_integer).out)
			Result.append ("%%")
		end

invariant
	library_not_empty: not library_name.is_empty
	class_not_empty: not class_name.is_empty
	score_valid: match_score >= 0.0 and match_score <= 1.0
	strategy_exists: strategy /= Void

end
