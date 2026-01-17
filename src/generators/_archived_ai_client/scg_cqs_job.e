note
	description: "[
		Command-Query Separation refinement job.

		Derived from: D:\prod\reference_docs\claude\EIFFEL_MENTAL_MODEL.md

		Ensures strict Command-Query Separation:
		- Commands (procedures) change state, return nothing
		- Queries (functions/attributes) return values, no side effects
		- Query names should be NOUNS (what it returns)
		- Command names should be VERBS (what it does)

		Also ensures Uniform Access Principle is respected.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_CQS_JOB

inherit
	SCG_REFINEMENT_JOB

feature -- Access

	name: STRING_32
		once
			Result := {STRING_32} "Command-Query Separation"
		end

	source_document: STRING_32
		once
			Result := {STRING_32} "D:\prod\reference_docs\claude\EIFFEL_MENTAL_MODEL.md"
		end

	description: STRING_32
		once
			Result := {STRING_32} "Ensures CQS compliance: queries=nouns, commands=verbs, no mixing"
		end

	priority: INTEGER = 110
			-- Early pass - structural principle

feature {NONE} -- Implementation

	build_prompt (a_class_text: STRING_32): STRING_32
			-- Compact prompt with noun/verb naming enforcement.
		do
			create Result.make (2000)
			Result.append ({STRING_32} "TASK: cqs_review%N")
			Result.append ({STRING_32} "RULES:%N")
			Result.append ({STRING_32} "BEHAVIOR:%N")
			Result.append ({STRING_32} "- Query: returns value, NO side effects%N")
			Result.append ({STRING_32} "- Command: modifies state, NO return value%N")
			Result.append ({STRING_32} "NAMING (critical):%N")
			Result.append ({STRING_32} "- Query names = NOUNS (what it returns)%N")
			Result.append ({STRING_32} "  WRONG: compute_sum, get_value, calculate_total%N")
			Result.append ({STRING_32} "  RIGHT: sum, value, total, count, item, first%N")
			Result.append ({STRING_32} "- Command names = VERBS (what it does)%N")
			Result.append ({STRING_32} "  RIGHT: add, remove, clear, reset, record, store%N")
			Result.append ({STRING_32} "- Boolean queries: is_/has_ prefix%N")
			Result.append ({STRING_32} "  RIGHT: is_empty, has_item, is_valid%N")
			Result.append ({STRING_32} "FIX PATTERNS:%N")
			Result.append ({STRING_32} "- compute_X -> X (drop verb prefix from queries)%N")
			Result.append ({STRING_32} "- get_X -> X (drop get_ prefix)%N")
			Result.append ({STRING_32} "- calculate_X -> X (drop calculate_ prefix)%N")
			Result.append ({STRING_32} "- pop:T that removes+returns -> item + remove%N")
			Result.append ({STRING_32} "- Function with side effect -> extract to command%N")
			Result.append ({STRING_32} "STRING_32 concat: use {STRING_32} %"text%" + var%N")
			Result.append ({STRING_32} "CLASS:%N```eiffel%N")
			Result.append (a_class_text)
			Result.append ({STRING_32} "%N```%N")
			Result.append ({STRING_32} "ACTION: Fix CQS + naming. Output ```eiffel class only.%N")
		end

end
