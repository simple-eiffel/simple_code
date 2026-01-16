note
	description: "[
		Specification for a single Eiffel feature.

		Contains everything needed to generate an implementation:
		- Feature name
		- Full signature (arguments, return type)
		- Preconditions (require clause)
		- Postconditions (ensure clause)
		- Intent description (from note clause)

		The contracts serve as guardrails - the generated implementation
		must satisfy them.

		Usage:
			create spec.make ("put", "put (a_item: G)", "not is_full", "count = old count + 1", "Adds item to stack")
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_FEATURE_SPEC

create
	make,
	make_empty

feature {NONE} -- Initialization

	make (a_name, a_signature, a_require, a_ensure, a_note: STRING_32)
			-- Create feature specification.
		require
			name_not_empty: not a_name.is_empty
			signature_not_empty: not a_signature.is_empty
		do
			name := a_name
			signature := a_signature
			require_clause := a_require
			ensure_clause := a_ensure
			note_clause := a_note
		ensure
			name_set: name = a_name
			signature_set: signature = a_signature
			require_set: require_clause = a_require
			ensure_set: ensure_clause = a_ensure
			note_set: note_clause = a_note
		end

	make_empty
			-- Create empty specification.
		do
			create name.make_empty
			create signature.make_empty
			create require_clause.make_empty
			create ensure_clause.make_empty
			create note_clause.make_empty
		end

feature -- Access

	name: STRING_32
			-- Feature name (e.g., "put", "is_empty", "count")

	signature: STRING_32
			-- Full signature (e.g., "put (a_item: G)", "count: INTEGER")

	require_clause: STRING_32
			-- Preconditions (may be empty)

	ensure_clause: STRING_32
			-- Postconditions (may be empty)

	note_clause: STRING_32
			-- Intent description (may be empty)

feature -- Derived

	has_arguments: BOOLEAN
			-- Does this feature have arguments?
		do
			Result := signature.has ('(')
		end

	has_return_type: BOOLEAN
			-- Does this feature have a return type (query)?
		do
			Result := signature.has (':') and not has_arguments
				or (has_arguments and signature.substring_index ("):", 1) > 0)
		end

	is_command: BOOLEAN
			-- Is this a command (no return type)?
		do
			Result := not has_return_type
		end

	is_query: BOOLEAN
			-- Is this a query (has return type)?
		do
			Result := has_return_type
		end

	has_preconditions: BOOLEAN
			-- Does this feature have preconditions?
		do
			Result := not require_clause.is_empty
		end

	has_postconditions: BOOLEAN
			-- Does this feature have postconditions?
		do
			Result := not ensure_clause.is_empty
		end

	arguments_string: STRING_32
			-- Extract just the arguments portion (e.g., "a_item: G")
		local
			l_start, l_end: INTEGER
		do
			create Result.make_empty
			l_start := signature.index_of ('(', 1)
			if l_start > 0 then
				l_end := signature.index_of (')', l_start)
				if l_end > l_start + 1 then
					Result := signature.substring (l_start + 1, l_end - 1)
				end
			end
		end

	return_type: STRING_32
			-- Extract return type (e.g., "INTEGER", "BOOLEAN")
		local
			l_colon: INTEGER
		do
			create Result.make_empty
			if has_arguments then
				l_colon := signature.substring_index ("):", 1)
				if l_colon > 0 then
					Result := signature.substring (l_colon + 2, signature.count)
					Result.left_adjust
					Result.right_adjust
				end
			else
				l_colon := signature.index_of (':', 1)
				if l_colon > 0 then
					Result := signature.substring (l_colon + 1, signature.count)
					Result.left_adjust
					Result.right_adjust
				end
			end
		end

feature -- Output

	to_string: STRING_32
			-- String representation for logging.
		do
			create Result.make (200)
			Result.append (name)
			if has_return_type then
				Result.append (": ")
				Result.append (return_type)
			end
			if has_preconditions then
				Result.append (" [require]")
			end
			if has_postconditions then
				Result.append (" [ensure]")
			end
		end

	to_context_string: STRING_32
			-- Format for providing as context to AI (signature + contracts).
		do
			create Result.make (500)
			Result.append (signature)
			Result.append ("%N")
			if has_preconditions then
				Result.append ("    require%N")
				Result.append ("        ")
				Result.append (require_clause.twin)
				if not require_clause.ends_with ("%N") then
					Result.append ("%N")
				end
			end
			if has_postconditions then
				Result.append ("    ensure%N")
				Result.append ("        ")
				Result.append (ensure_clause.twin)
				if not ensure_clause.ends_with ("%N") then
					Result.append ("%N")
				end
			end
		end

invariant
	name_exists: name /= Void
	signature_exists: signature /= Void
	require_exists: require_clause /= Void
	ensure_exists: ensure_clause /= Void
	note_exists: note_clause /= Void

end
