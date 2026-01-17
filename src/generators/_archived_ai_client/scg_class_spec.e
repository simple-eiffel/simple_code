note
	description: "[
		Specification for a class to be generated.

		Holds the decomposition output for a single class:
		- Name
		- Purpose/responsibility
		- List of responsibilities
		- Collaborating classes

		Used by SCG_SYS_GEN to pass class specifications
		to SCG_CLASS_NEGOTIATOR for generation.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_CLASS_SPEC

create
	make

feature {NONE} -- Initialization

	make (a_name: STRING_32; a_purpose: STRING_32; a_responsibilities: ARRAYED_LIST [STRING_32]; a_collaborators: STRING_32)
			-- Create class specification.
		require
			name_not_empty: not a_name.is_empty
		do
			name := a_name
			purpose := a_purpose
			responsibilities := a_responsibilities
			collaborators := a_collaborators
		ensure
			name_set: name = a_name
			purpose_set: purpose = a_purpose
			responsibilities_set: responsibilities = a_responsibilities
			collaborators_set: collaborators = a_collaborators
		end

feature -- Access

	name: STRING_32
			-- Class name (ALL_CAPS convention)

	purpose: STRING_32
			-- What this class does (one sentence)

	responsibilities: ARRAYED_LIST [STRING_32]
			-- List of responsibilities this class fulfills

	collaborators: STRING_32
			-- Comma-separated list of collaborating class names

feature -- Conversion

	to_spec_string: STRING_32
			-- Convert to specification string for AI prompt.
		do
			create Result.make (500)
			Result.append ("CLASS: ")
			Result.append (name)
			Result.append ("%N%N")

			Result.append ("PURPOSE: ")
			Result.append (purpose)
			Result.append ("%N%N")

			Result.append ("RESPONSIBILITIES:%N")
			across responsibilities as ic loop
				Result.append ("- ")
				Result.append (ic)
				Result.append ("%N")
			end

			if not collaborators.is_empty then
				Result.append ("%NCOLLABORATORS: ")
				Result.append (collaborators)
				Result.append ("%N")
			end
		ensure
			result_not_empty: not Result.is_empty
		end

invariant
	name_exists: name /= Void
	purpose_exists: purpose /= Void
	responsibilities_exists: responsibilities /= Void
	collaborators_exists: collaborators /= Void

end
