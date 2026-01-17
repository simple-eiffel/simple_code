note
	description: "[
		Specification Hat refinement job (Vibe-Contracting).

		Derived from: D:\prod\reference_docs\claude\HATS.md
		Based on: D:\prod\reference_docs\claude\verification_process.md

		Focus: Ensuring contracts FULLY specify behavior.
		Based on Meyer's "probable to provable" framework.

		Key questions:
		- Is this contract TRUE but INCOMPLETE?
		- Would a caller know exactly what to expect?
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_SPECIFICATION_HAT_JOB

inherit
	SCG_REFINEMENT_JOB

feature -- Access

	name: STRING_32
		once
			Result := "Specification Hat"
		end

	source_document: STRING_32
		once
			Result := "D:\prod\reference_docs\claude\HATS.md"
		end

	description: STRING_32
		once
			Result := "Ensures contracts fully specify behavior - addresses the 'true but incomplete' problem"
		end

	priority: INTEGER = 220
			-- After contract completeness, ensures full specification

feature {NONE} -- Implementation

	build_prompt (a_class_text: STRING_32): STRING_32
			-- Compact prompt (~60% smaller than original)
		do
			create Result.make (1400)
			Result.append ("TASK: specification_hat (full spec)%N")
			Result.append ("QUESTIONS per feature:%N")
			Result.append ("1. What BEFORE? -> Preconditions%N")
			Result.append ("2. What AFTER? -> Postconditions%N")
			Result.append ("3. What ALWAYS? -> Class invariants%N")
			Result.append ("4. What ELSE? -> Completeness%N")
			Result.append ("CHECK each postcondition: TRUE but INCOMPLETE?%N")
			Result.append ("VERIFY:%N")
			Result.append ("- What changed? What stayed same?%N")
			Result.append ("- Side effects documented?%N")
			Result.append ("- 'old' used for state changes?%N")
			Result.append ("- Caller knows EXACTLY what to expect?%N")
			Result.append ("CLASS:%N```eiffel%N")
			Result.append (a_class_text)
			Result.append ("%N```%N")
			Result.append ("ACTION: Full specification. Output ```eiffel class only.%N")
		end

end
