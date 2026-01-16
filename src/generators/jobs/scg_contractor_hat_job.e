note
	description: "[
		Contractor Hat refinement job.

		Derived from: D:\prod\reference_docs\claude\HATS.md

		Focus: Adding, reviewing, and strengthening contracts.
		Works through contracts in priority order:
		1. Class invariants
		2. Loop invariants and variants
		3. Check assertions
		4. Preconditions/Postconditions
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_CONTRACTOR_HAT_JOB

inherit
	SCG_REFINEMENT_JOB

feature -- Access

	name: STRING_32
		once
			Result := "Contractor Hat"
		end

	source_document: STRING_32
		once
			Result := "D:\prod\reference_docs\claude\HATS.md"
		end

	description: STRING_32
		once
			Result := "Strengthens DBC coverage: invariants, loop contracts, assertions, pre/postconditions"
		end

	priority: INTEGER = 200
			-- Contract strengthening phase

feature {NONE} -- Implementation

	build_prompt (a_class_text: STRING_32): STRING_32
			-- Compact prompt (~60% smaller than original)
		do
			create Result.make (1400)
			Result.append ("TASK: contractor_hat (DBC strengthening)%N")
			Result.append ("PRIORITY ORDER:%N")
			Result.append ("1. Class invariants - always true about class state%N")
			Result.append ("2. Loop invariant+variant - every loop needs both%N")
			Result.append ("3. Check assertions - internal sanity checks%N")
			Result.append ("4. Preconditions - caller guarantees%N")
			Result.append ("5. Postconditions - feature guarantees (use 'old')%N")
			Result.append ("AVOID TRIVIAL:%N")
			Result.append ("- x /= Void on attached (redundant)%N")
			Result.append ("- Result /= Void on attached return (redundant)%N")
			Result.append ("- count >= 0 (always true)%N")
			Result.append ("GOOD: Express domain logic, not type guarantees%N")
			Result.append ("CLASS:%N```eiffel%N")
			Result.append (a_class_text)
			Result.append ("%N```%N")
			Result.append ("ACTION: Add meaningful contracts. Output ```eiffel class only.%N")
		end

end
