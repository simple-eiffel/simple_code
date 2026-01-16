note
	description: "[
		Code Review Hat refinement job.

		Derived from: D:\prod\reference_docs\claude\HATS.md

		Final quality review pass checking:
		- Correctness
		- Contracts
		- Eiffel-specific patterns
		- Maintainability
		- Command-Query Separation

		Fixes Critical and High severity issues found.
	]"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_CODE_REVIEW_JOB

inherit
	SCG_REFINEMENT_JOB

feature -- Access

	name: STRING_32
		once
			Result := "Code Review"
		end

	source_document: STRING_32
		once
			Result := "D:\prod\reference_docs\claude\HATS.md"
		end

	description: STRING_32
		once
			Result := "Final quality review: correctness, contracts, Eiffel patterns, maintainability"
		end

	priority: INTEGER = 300
			-- Final review pass

feature {NONE} -- Implementation

	build_prompt (a_class_text: STRING_32): STRING_32
			-- Compact prompt (~60% smaller than original)
		do
			create Result.make (1500)
			Result.append ("TASK: code_review%N")
			Result.append ("CHECK:%N")
			Result.append ("- Correctness: logic, edge cases, error handling%N")
			Result.append ("- Void safety: attached/detachable correct%N")
			Result.append ("- STRING_8 vs STRING_32 correct%N")
			Result.append ("- CQS: queries no side effects, commands no returns%N")
			Result.append ("- ARRAYED_LIST.has uses ref eq (use ~ for value)%N")
			Result.append ("- Contracts complete (not just true)%N")
			Result.append ("- Loop invariants+variants present%N")
			Result.append ("SEVERITY:%N")
			Result.append ("- Critical/High: FIX (security, bugs, crashes)%N")
			Result.append ("- Medium/Low: Note only%N")
			Result.append ("CLASS:%N```eiffel%N")
			Result.append (a_class_text)
			Result.append ("%N```%N")
			Result.append ("ACTION: Fix critical/high issues. Output ```eiffel class only.%N")
		end

end
