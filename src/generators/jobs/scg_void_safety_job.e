note
	description: "[
		Void safety refinement job.

		Derived from: D:\prod\reference_docs\claude\EIFFEL_MENTAL_MODEL.md

		Ensures proper void safety patterns:
		- Correct use of attached vs detachable types
		- Proper Certified Attachment Patterns (CAPs)
		- No unnecessary detachable types
		- Proper handling of optional values
	]"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_VOID_SAFETY_JOB

inherit
	SCG_REFINEMENT_JOB

feature -- Access

	name: STRING_32
		once
			Result := "Void Safety Review"
		end

	source_document: STRING_32
		once
			Result := "D:\prod\reference_docs\claude\EIFFEL_MENTAL_MODEL.md"
		end

	description: STRING_32
		once
			Result := "Ensures proper void safety: attached/detachable usage, CAPs, optional handling"
		end

	priority: INTEGER = 120
			-- Early pass - type safety

feature {NONE} -- Implementation

	build_prompt (a_class_text: STRING_32): STRING_32
			-- Compact prompt (~60% smaller than original)
		do
			create Result.make (1200)
			Result.append ("TASK: void_safety_review%N")
			Result.append ("RULES:%N")
			Result.append ("- attached: default, cannot be Void, safe to call%N")
			Result.append ("- detachable: may be Void, needs CAP before use%N")
			Result.append ("CAPs (use before accessing detachable):%N")
			Result.append ("- if attached x as l_x then l_x.f end%N")
			Result.append ("- if x /= Void then x.f end%N")
			Result.append ("FIX:%N")
			Result.append ("- Remove unnecessary detachable types%N")
			Result.append ("- Add CAPs before detachable access%N")
			Result.append ("- Init all attached attrs in creation%N")
			Result.append ("CLASS:%N```eiffel%N")
			Result.append (a_class_text)
			Result.append ("%N```%N")
			Result.append ("ACTION: Fix void safety. Output ```eiffel class only.%N")
		end

end
