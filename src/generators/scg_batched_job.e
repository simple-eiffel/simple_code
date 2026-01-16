note
	description: "[
		Batched refinement job combining multiple passes into a single AI call.

		Combines related jobs (e.g., Wave 1 structural jobs) into one prompt,
		reducing API calls and latency while maintaining quality.

		Usage:
			create batched.make_wave_1  -- Naming + CQS + Void Safety
			batched.apply (ai_client, class_text)

		Benefits:
			- 3 API calls -> 1 API call (3x speedup)
			- Reduced token overhead from repeated class text
			- AI can consider all aspects together

		Tradeoffs:
			- Less granular error reporting
			- All-or-nothing success per batch
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_BATCHED_JOB

inherit
	SCG_REFINEMENT_JOB

create
	make_wave_1,
	make_wave_3,
	make_custom

feature {NONE} -- Initialization

	make_wave_1
			-- Create batch for Wave 1 structural jobs: Naming, CQS, Void Safety
		do
			internal_name := "Batched Structural Pass"
			internal_description := "Combined: Naming + CQS + Void Safety"
			internal_priority := 100
			create passes.make (3)
			passes.extend (create {TUPLE [name, rules: STRING_32]}.default_create)
			passes [1].name := "NAMING"
			passes [1].rules := naming_rules
			passes.extend (create {TUPLE [name, rules: STRING_32]}.default_create)
			passes [2].name := "CQS"
			passes [2].rules := cqs_rules
			passes.extend (create {TUPLE [name, rules: STRING_32]}.default_create)
			passes [3].name := "VOID_SAFETY"
			passes [3].rules := void_safety_rules
		ensure
			is_wave_1: internal_name.has_substring ("Structural")
			has_3_passes: passes.count = 3
		end

	make_wave_3
			-- Create batch for Wave 3 contract jobs: Contractor, Completeness, Specification
		do
			internal_name := "Batched Contract Pass"
			internal_description := "Combined: Contractor + Completeness + Specification"
			internal_priority := 200
			create passes.make (3)
			passes.extend (create {TUPLE [name, rules: STRING_32]}.default_create)
			passes [1].name := "CONTRACTOR_HAT"
			passes [1].rules := contractor_rules
			passes.extend (create {TUPLE [name, rules: STRING_32]}.default_create)
			passes [2].name := "COMPLETENESS"
			passes [2].rules := completeness_rules
			passes.extend (create {TUPLE [name, rules: STRING_32]}.default_create)
			passes [3].name := "SPECIFICATION"
			passes [3].rules := specification_rules
		ensure
			is_wave_3: internal_name.has_substring ("Contract")
			has_3_passes: passes.count = 3
		end

	make_custom (a_name: STRING_32; a_passes: like passes; a_priority: INTEGER)
			-- Create custom batch with given passes
		require
			name_not_empty: not a_name.is_empty
			passes_not_empty: not a_passes.is_empty
			valid_priority: a_priority >= 0 and a_priority <= 999
		do
			internal_name := a_name
			internal_description := "Custom batch: " + a_passes.count.out + " passes"
			internal_priority := a_priority
			passes := a_passes
		ensure
			name_set: internal_name = a_name
			passes_set: passes = a_passes
			priority_set: internal_priority = a_priority
		end

feature -- Access

	name: STRING_32
		do
			Result := internal_name
		end

	source_document: STRING_32
		once
			Result := "Multiple reference documents (batched)"
		end

	description: STRING_32
		do
			Result := internal_description
		end

	priority: INTEGER
		do
			Result := internal_priority
		end

	passes: ARRAYED_LIST [TUPLE [name, rules: STRING_32]]
			-- Passes to apply in order

feature {NONE} -- Implementation

	internal_name: STRING_32
		attribute
			create Result.make_empty
		end

	internal_description: STRING_32
		attribute
			create Result.make_empty
		end

	internal_priority: INTEGER

	build_prompt (a_class_text: STRING_32): STRING_32
			-- Build multi-pass prompt
		local
			l_pass_num: INTEGER
		do
			create Result.make (3000)
			Result.append ("Apply these passes IN ORDER to the class:%N%N")

			l_pass_num := 1
			across passes as ic loop
				Result.append ("PASS " + l_pass_num.out + " - " + ic.name + ":%N")
				Result.append (ic.rules)
				Result.append ("%N%N")
				l_pass_num := l_pass_num + 1
			end

			Result.append ("CLASS:%N```eiffel%N")
			Result.append (a_class_text)
			Result.append ("%N```%N%N")
			Result.append ("ACTION: Apply ALL passes in order. Output final ```eiffel class only.%N")
		end

feature {NONE} -- Pass Rules

	naming_rules: STRING_32
		once
			Result := "[
- class: ALL_CAPS_UNDERSCORES
- feature: lowercase_underscores
- constant: Initial_cap
- arg: a_ prefix
- cursor: ic_ prefix
- bool_query: is_/has_ prefix
]"
		end

	cqs_rules: STRING_32
		once
			Result := "[
- Query: returns value, NO side effects
- Command: modifies state, NO return value
- Split violations: top+remove instead of pop
]"
		end

	void_safety_rules: STRING_32
		once
			Result := "[
- attached = never Void (default)
- detachable = may be Void (explicit)
- Use CAPs: if attached x as l_x then
- Initialize in make or as attribute default
]"
		end

	contractor_rules: STRING_32
		once
			Result := "[
- require: validate inputs at public boundaries
- ensure: verify outputs match specification
- invariant: maintain object consistency
- Check: meaningful tag names
]"
		end

	completeness_rules: STRING_32
		once
			Result := "[
- All public features need require/ensure
- Creation procedures need ensure
- Queries with constraints need ensure
- Class invariant captures valid states
]"
		end

	specification_rules: STRING_32
		once
			Result := "[
- Postconditions verify behavior, not implementation
- Use old in ensure for delta checks
- Contracts express WHAT not HOW
- Invariants express class semantics
]"
		end

invariant
	name_exists: internal_name /= Void
	description_exists: internal_description /= Void
	passes_exists: passes /= Void
	valid_priority: internal_priority >= 0 and internal_priority <= 999

end
