note
	description: "[
		Command-Query Separation refinement job.

		Derived from: D:\prod\reference_docs\claude\EIFFEL_MENTAL_MODEL.md

		Ensures strict Command-Query Separation:
		- Commands (procedures) change state, return nothing
		- Queries (functions/attributes) return values, no side effects

		Also ensures Uniform Access Principle is respected.
	]"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_CQS_JOB

inherit
	SCG_REFINEMENT_JOB

feature -- Access

	name: STRING_32
		once
			Result := "Command-Query Separation"
		end

	source_document: STRING_32
		once
			Result := "D:\prod\reference_docs\claude\EIFFEL_MENTAL_MODEL.md"
		end

	description: STRING_32
		once
			Result := "Ensures queries don't modify state and commands don't return values"
		end

	priority: INTEGER = 110
			-- Early pass - structural principle

feature {NONE} -- Implementation

	build_prompt (a_class_text: STRING_32): STRING_32
			-- Compact prompt (~60% smaller than original)
		do
			create Result.make (1200)
			Result.append ("TASK: cqs_review%N")
			Result.append ("RULES:%N")
			Result.append ("- Query: returns value, NO side effects%N")
			Result.append ("- Command: modifies state, NO return value%N")
			Result.append ("FIX:%N")
			Result.append ("- pop:T that removes+returns -> split: top + remove%N")
			Result.append ("- Function with side effect -> extract to command%N")
			Result.append ("- Procedure returning Result -> split: command + query%N")
			Result.append ("CLASS:%N```eiffel%N")
			Result.append (a_class_text)
			Result.append ("%N```%N")
			Result.append ("ACTION: Split CQS violations. Output ```eiffel class only.%N")
		end

end
