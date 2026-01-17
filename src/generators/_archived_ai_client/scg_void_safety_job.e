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
	author: "Larry Rix"
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
			create Result.make (1500)
			Result.append ({STRING_32} "TASK: void_safety_review%N")
			Result.append ({STRING_32} "RULES:%N")
			Result.append ({STRING_32} "- attached: default, cannot be Void, safe to call%N")
			Result.append ({STRING_32} "- detachable: may be Void, needs CAP before use%N")
			Result.append ({STRING_32} "CAPs (use before accessing detachable):%N")
			Result.append ({STRING_32} "- if attached x as l_x then l_x.f end%N")
			Result.append ({STRING_32} "- if x /= Void then x.f end%N")
			Result.append ({STRING_32} "STRING TYPES:%N")
			Result.append ({STRING_32} "- Use {STRING_32} manifest when concatenating with STRING_32%N")
			Result.append ({STRING_32} "- WRONG: %"text: %" + str32  (causes as_string_8 warning)%N")
			Result.append ({STRING_32} "- RIGHT: {STRING_32} %"text: %" + str32%N")
			Result.append ({STRING_32} "FIX:%N")
			Result.append ({STRING_32} "- Remove unnecessary detachable types%N")
			Result.append ({STRING_32} "- Add CAPs before detachable access%N")
			Result.append ({STRING_32} "- Init all attached attrs in creation%N")
			Result.append ({STRING_32} "- Use {STRING_32} manifest for STRING_32 concatenation%N")
			Result.append ({STRING_32} "CLASS:%N```eiffel%N")
			Result.append (a_class_text)
			Result.append ({STRING_32} "%N```%N")
			Result.append ({STRING_32} "ACTION: Fix void safety + string types. Output ```eiffel class only.%N")
		end

end
