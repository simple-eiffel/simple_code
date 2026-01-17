note
	description: "[
		Contract completeness refinement job.

		Derived from: D:\prod\reference_docs\claude\contract_patterns.md

		Addresses the "true but incomplete" problem identified by Meyer.
		Ensures postconditions answer:
		1. What changed?
		2. How did it change?
		3. What did NOT change? (frame conditions)

		Also removes bad contract patterns:
		- Trivially-true assertions (count >= 0 for collections)
		- Recursive postconditions (calling same feature in ensure)
		- Tautological conditions

		Applies systematic postcondition templates for:
		- Collection operations (add, remove, clear, replace)
		- Search/query operations
		- Attribute setters
		- State machine operations
		- Resource management (open/close)
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_CONTRACT_COMPLETENESS_JOB

inherit
	SCG_REFINEMENT_JOB

feature -- Access

	name: STRING_32
		once
			Result := {STRING_32} "Contract Completeness"
		end

	source_document: STRING_32
		once
			Result := {STRING_32} "D:\prod\reference_docs\claude\contract_patterns.md"
		end

	description: STRING_32
		once
			Result := {STRING_32} "Ensures postconditions are complete, removes trivial/recursive contracts"
		end

	priority: INTEGER = 210
			-- After basic contracts, before final review

feature {NONE} -- Implementation

	build_prompt (a_class_text: STRING_32): STRING_32
			-- Compact prompt with trivial/recursive contract detection.
		do
			create Result.make (2200)
			Result.append ({STRING_32} "TASK: contract_completeness%N")
			Result.append ({STRING_32} "PRINCIPLE: Postconditions must answer:%N")
			Result.append ({STRING_32} "1. What changed? 2. How (use 'old')? 3. What didn't change?%N")
			Result.append ({STRING_32} "REMOVE BAD CONTRACTS:%N")
			Result.append ({STRING_32} "1. TRIVIALLY TRUE (always true by definition):%N")
			Result.append ({STRING_32} "   REMOVE: count >= 0 (count is never negative)%N")
			Result.append ({STRING_32} "   REMOVE: Result /= Void (for attached return types)%N")
			Result.append ({STRING_32} "   REMOVE: list.count >= 0 (collection counts >= 0 by design)%N")
			Result.append ({STRING_32} "2. RECURSIVE POSTCONDITIONS (call same feature):%N")
			Result.append ({STRING_32} "   REMOVE: Result = same_feature (other_args)%N")
			Result.append ({STRING_32} "   Example: sum ensure commutative: Result = sum(b, a) -- BAD%N")
			Result.append ({STRING_32} "   These waste cycles and may cause infinite recursion%N")
			Result.append ({STRING_32} "3. TAUTOLOGICAL (restates the obvious):%N")
			Result.append ({STRING_32} "   REMOVE: Result = a + b in feature that does Result := a + b%N")
			Result.append ({STRING_32} "   Keep ONLY if documenting a non-obvious relationship%N")
			Result.append ({STRING_32} "GOOD PATTERNS:%N")
			Result.append ({STRING_32} "- Add: has+count_increased (old count+1)%N")
			Result.append ({STRING_32} "- Remove: not_has+count_decreased (old count-1)%N")
			Result.append ({STRING_32} "- Clear: is_empty+count=0%N")
			Result.append ({STRING_32} "- Setter: attr_set (attr = a_val)%N")
			Result.append ({STRING_32} "- Frame: other_attr_unchanged (other = old other)%N")
			Result.append ({STRING_32} "STRING_32 concat: use {STRING_32} %"text%" + var%N")
			Result.append ({STRING_32} "CLASS:%N```eiffel%N")
			Result.append (a_class_text)
			Result.append ({STRING_32} "%N```%N")
			Result.append ({STRING_32} "ACTION: Remove bad contracts, complete good ones. Output ```eiffel class only.%N")
		end

end
