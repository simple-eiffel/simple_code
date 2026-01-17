note
	description: "[
		Naming conventions refinement job.

		Derived from: D:\prod\reference_docs\claude\NAMING_CONVENTIONS.md

		Reviews and corrects:
		- Class names (ALL_CAPS)
		- Feature names (all_lowercase with underscores)
		- Constant names (Initial_cap)
		- Argument prefixes (a_)
		- Local variable prefixes (l_ for clarity, ic_ for cursors)
		- Standard feature names (item, count, extend, etc.)
		- Command-Query naming (verbs for commands, nouns for queries)
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_NAMING_JOB

inherit
	SCG_REFINEMENT_JOB

feature -- Access

	name: STRING_32
		once
			Result := {STRING_32} "Naming Conventions Review"
		end

	source_document: STRING_32
		once
			Result := {STRING_32} "D:\prod\reference_docs\claude\NAMING_CONVENTIONS.md"
		end

	description: STRING_32
		once
			Result := {STRING_32} "Reviews naming: aliases (max 2), argument consistency, prefixes"
		end

	priority: INTEGER = 100
			-- Early pass - naming affects everything else

feature {NONE} -- Implementation

	build_prompt (a_class_text: STRING_32): STRING_32
			-- Compact prompt with alias limits and argument naming consistency.
		do
			create Result.make (2000)
			Result.append ({STRING_32} "TASK: naming_review%N")
			Result.append ({STRING_32} "RULES:%N")
			Result.append ({STRING_32} "- class: ALL_CAPS_UNDERSCORES (LINKED_LIST)%N")
			Result.append ({STRING_32} "- feature: lowercase_underscores (set_owner)%N")
			Result.append ({STRING_32} "- constant: Initial_cap (Pi, Max_size)%N")
			Result.append ({STRING_32} "- arg: a_ prefix (a_name, a_count)%N")
			Result.append ({STRING_32} "- cursor: ic_ prefix (ic, ic_item)%N")
			Result.append ({STRING_32} "- bool_query: is_/has_ prefix (is_empty, has_key)%N")
			Result.append ({STRING_32} "- command: verb (set, remove, wipe_out)%N")
			Result.append ({STRING_32} "- query: noun (count, item, capacity)%N")
			Result.append ({STRING_32} "ALIASES (critical):%N")
			Result.append ({STRING_32} "- MAX 1 alias per feature (2 names total)%N")
			Result.append ({STRING_32} "  WRONG: compute_add, add, sum (3 names)%N")
			Result.append ({STRING_32} "  RIGHT: add, sum (2 names max)%N")
			Result.append ({STRING_32} "- Pick ONE canonical name + ONE common alias%N")
			Result.append ({STRING_32} "ARGUMENT CONSISTENCY:%N")
			Result.append ({STRING_32} "- Related features must use SAME arg names%N")
			Result.append ({STRING_32} "  WRONG: add(a_val), remove(a_item), clear%N")
			Result.append ({STRING_32} "  RIGHT: add(a_item), remove(a_item), clear%N")
			Result.append ({STRING_32} "- Division: a_dividend, a_divisor (not a_operand_a/b)%N")
			Result.append ({STRING_32} "- Binary ops: a_left, a_right OR a_first, a_second%N")
			Result.append ({STRING_32} "STRING_32: use manifest {STRING_32} for concat%N")
			Result.append ({STRING_32} "CLASS:%N```eiffel%N")
			Result.append (a_class_text)
			Result.append ({STRING_32} "%N```%N")
			Result.append ({STRING_32} "ACTION: Fix violations. Output ```eiffel class only.%N")
		end

end
