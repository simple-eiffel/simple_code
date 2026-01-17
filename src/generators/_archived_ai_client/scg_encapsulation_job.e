note
	description: "[
		Encapsulation refinement job.

		Ensures proper information hiding and encapsulation:
		- No direct return of mutable internal collections
		- Internal state should be protected via {NONE} or copy-on-read
		- Queries should not expose implementation details

		Common violations:
		- Returning internal ARRAYED_LIST directly (should return twin or READABLE_*)
		- Public attributes that should be queries
		- Internal helpers exposed without {NONE}
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_ENCAPSULATION_JOB

inherit
	SCG_REFINEMENT_JOB

feature -- Access

	name: STRING_32
		once
			Result := {STRING_32} "Encapsulation Review"
		end

	source_document: STRING_32
		once
			Result := {STRING_32} "D:\prod\reference_docs\claude\EIFFEL_MENTAL_MODEL.md"
		end

	description: STRING_32
		once
			Result := {STRING_32} "Ensures proper encapsulation: no internal state exposure, protected implementation"
		end

	priority: INTEGER = 125
			-- After void safety (120), before semantic framing (150)

feature {NONE} -- Implementation

	build_prompt (a_class_text: STRING_32): STRING_32
			-- Build prompt for encapsulation review.
		do
			create Result.make (1800)
			Result.append ({STRING_32} "TASK: encapsulation_review%N")
			Result.append ({STRING_32} "RULES:%N")
			Result.append ({STRING_32} "1. NEVER return direct references to mutable internal collections%N")
			Result.append ({STRING_32} "   WRONG: Result := internal_list%N")
			Result.append ({STRING_32} "   RIGHT: Result := internal_list.twin  -- return copy%N")
			Result.append ({STRING_32} "   RIGHT: Result := internal_list.to_array  -- immutable view%N")
			Result.append ({STRING_32} "2. Internal helpers should be in feature {NONE} section%N")
			Result.append ({STRING_32} "3. Mutable attributes should not be directly exposed%N")
			Result.append ({STRING_32} "   Use queries that return copies or immutable views%N")
			Result.append ({STRING_32} "4. Postconditions should NOT enforce reference equality to internals%N")
			Result.append ({STRING_32} "   WRONG: ensure same_reference: Result = internal_list%N")
			Result.append ({STRING_32} "   RIGHT: ensure same_content: Result.count = internal_list.count%N")
			Result.append ({STRING_32} "PATTERNS TO FIX:%N")
			Result.append ({STRING_32} "- 'Result := some_list' where some_list is internal attribute%N")
			Result.append ({STRING_32} "- 'Result = internal_attr' in postconditions (reference check)%N")
			Result.append ({STRING_32} "- Public attributes of collection types%N")
			Result.append ({STRING_32} "STRING_32 concat: use {STRING_32} %"text%" + var%N")
			Result.append ({STRING_32} "CLASS:%N```eiffel%N")
			Result.append (a_class_text)
			Result.append ({STRING_32} "%N```%N")
			Result.append ({STRING_32} "ACTION: Fix encapsulation violations. Output ```eiffel class only.%N")
		end

end
