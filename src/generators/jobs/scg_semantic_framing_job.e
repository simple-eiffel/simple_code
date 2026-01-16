note
	description: "[
		Semantic Frame Naming refinement job.

		Derived from: D:\prod\reference_docs\standards\SEMANTIC_FRAME_NAMING.md

		Applies the semantic frame naming pattern to add context-appropriate
		feature aliases for different usage domains.

		Key rules:
		- Routines CAN have multiple names (comma-separated)
		- Attributes CANNOT have multiple names (creates separate attributes!)
		- For attribute aliasing, wrap with query/command routines
	]"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_SEMANTIC_FRAMING_JOB

inherit
	SCG_REFINEMENT_JOB

feature -- Access

	name: STRING_32
		once
			Result := "Semantic Frame Naming"
		end

	source_document: STRING_32
		once
			Result := "D:\prod\reference_docs\standards\SEMANTIC_FRAME_NAMING.md"
		end

	description: STRING_32
		once
			Result := "Adds context-appropriate feature aliases for different usage domains"
		end

	priority: INTEGER = 150
			-- After basic structure, before contracts

feature {NONE} -- Implementation

	build_prompt (a_class_text: STRING_32): STRING_32
			-- Compact prompt (~60% smaller than original)
		do
			create Result.make (1400)
			Result.append ("TASK: semantic_framing%N")
			Result.append ("PATTERN: ROUTINES can have multiple names (comma-separated)%N")
			Result.append ("EXAMPLE:%N")
			Result.append ("  name, account_holder, username: STRING_32 do Result := internal_name end%N")
			Result.append ("WARNING: Attributes CANNOT have multi-names (creates separate attrs!)%N")
			Result.append ("SOLUTION: Wrap attribute with aliased query routines%N")
			Result.append ("APPLY WHEN:%N")
			Result.append ("- High fan-in supplier classes%N")
			Result.append ("- Bridge classes between domains%N")
			Result.append ("- API facades%N")
			Result.append ("CLASS:%N```eiffel%N")
			Result.append (a_class_text)
			Result.append ("%N```%N")
			Result.append ("ACTION: Add useful aliases to routines. No frivolous names. Output ```eiffel class only.%N")
		end

end
