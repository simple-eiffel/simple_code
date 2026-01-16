note
	description: "[
		Contract completeness refinement job.

		Derived from: D:\prod\reference_docs\claude\contract_patterns.md

		Addresses the "true but incomplete" problem identified by Meyer.
		Ensures postconditions answer:
		1. What changed?
		2. How did it change?
		3. What did NOT change? (frame conditions)

		Applies systematic postcondition templates for:
		- Collection operations (add, remove, clear, replace)
		- Search/query operations
		- Attribute setters
		- State machine operations
		- Resource management (open/close)
	]"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_CONTRACT_COMPLETENESS_JOB

inherit
	SCG_REFINEMENT_JOB

feature -- Access

	name: STRING_32
		once
			Result := "Contract Completeness"
		end

	source_document: STRING_32
		once
			Result := "D:\prod\reference_docs\claude\contract_patterns.md"
		end

	description: STRING_32
		once
			Result := "Ensures postconditions are complete, not just true - addresses what changed, how, and what didn't"
		end

	priority: INTEGER = 210
			-- After basic contracts, before final review

feature {NONE} -- Implementation

	build_prompt (a_class_text: STRING_32): STRING_32
			-- Compact prompt (~60% smaller than original)
		do
			create Result.make (1600)
			Result.append ("TASK: contract_completeness%N")
			Result.append ("PRINCIPLE: Postconditions must answer:%N")
			Result.append ("1. What changed? 2. How (use 'old')? 3. What didn't change?%N")
			Result.append ("PATTERNS:%N")
			Result.append ("- Add: has+count_increased (old count+1)%N")
			Result.append ("- Remove: not_has+count_decreased (old count-1)%N")
			Result.append ("- Clear: is_empty+count=0%N")
			Result.append ("- Setter: attr_set (attr ~ a_val)%N")
			Result.append ("- Search: found_implies_has+void_implies_not_has%N")
			Result.append ("- State: now_in+was_in (old state)%N")
			Result.append ("INCOMPLETE: has_item only%N")
			Result.append ("COMPLETE: has_item + count = old count + 1%N")
			Result.append ("CLASS:%N```eiffel%N")
			Result.append (a_class_text)
			Result.append ("%N```%N")
			Result.append ("ACTION: Complete postconditions. Output ```eiffel class only.%N")
		end

end
