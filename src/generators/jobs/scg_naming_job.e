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
			Result := "Naming Conventions Review"
		end

	source_document: STRING_32
		once
			Result := "D:\prod\reference_docs\claude\NAMING_CONVENTIONS.md"
		end

	description: STRING_32
		once
			Result := "Reviews naming conventions: class/feature/argument/local names, prefixes, standard names"
		end

	priority: INTEGER = 100
			-- Early pass - naming affects everything else

feature {NONE} -- Implementation

	build_prompt (a_class_text: STRING_32): STRING_32
			-- Compact prompt (~60% smaller than original)
		do
			create Result.make (1500)
			Result.append ("TASK: naming_review%N")
			Result.append ("RULES:%N")
			Result.append ("- class: ALL_CAPS_UNDERSCORES (LINKED_LIST)%N")
			Result.append ("- feature: lowercase_underscores (set_owner)%N")
			Result.append ("- constant: Initial_cap (Pi, Max_size)%N")
			Result.append ("- arg: a_ prefix (a_name, a_count)%N")
			Result.append ("- cursor: ic_ prefix (ic, ic_item)%N")
			Result.append ("- bool_query: is_/has_ prefix (is_empty, has_key)%N")
			Result.append ("- command: verb (set, remove, wipe_out)%N")
			Result.append ("- query: noun (count, item, capacity)%N")
			Result.append ("CLASS:%N```eiffel%N")
			Result.append (a_class_text)
			Result.append ("%N```%N")
			Result.append ("ACTION: Fix violations. Output ```eiffel class only.%N")
		end

end
