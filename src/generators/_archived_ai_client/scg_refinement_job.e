note
	description: "[
		Abstract refinement job for the class generation assembly line.

		Each job represents a specific refinement pass derived from
		reference documentation (D:\prod\reference_docs\claude\*.md).

		Jobs are applied sequentially to improve generated_class_text,
		with each job focusing on a specific aspect of code quality.

		Concrete jobs implement:
		- `name`: Human-readable job identifier
		- `source_document`: Path to the reference doc this job is derived from
		- `build_prompt`: Creates the AI prompt for this refinement pass

		Usage:
			job.apply (ai_client, class_text)
			if job.is_success then
				refined_text := job.result_text
			end
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"
	design_references: "[
		- D:\prod\reference_docs\claude\NAMING_CONVENTIONS.md
		- D:\prod\reference_docs\claude\contract_patterns.md
		- D:\prod\reference_docs\claude\verification_process.md
		- D:\prod\reference_docs\claude\HATS.md
		- D:\prod\reference_docs\claude\EIFFEL_MENTAL_MODEL.md
	]"

deferred class
	SCG_REFINEMENT_JOB

feature -- Access

	name: STRING_32
			-- Human-readable name of this job
		deferred
		ensure
			not_empty: not Result.is_empty
		end

	source_document: STRING_32
			-- Path to reference document this job is derived from
		deferred
		ensure
			not_empty: not Result.is_empty
		end

	description: STRING_32
			-- Brief description of what this job does
		deferred
		ensure
			not_empty: not Result.is_empty
		end

	priority: INTEGER
			-- Execution priority (lower = earlier in pipeline)
			-- 100: Structure/naming passes
			-- 200: Contract passes
			-- 300: Quality review passes
			-- 400: Final polish passes
		deferred
		ensure
			valid_range: Result >= 0 and Result <= 999
		end

feature -- Status

	is_success: BOOLEAN
			-- Did the last apply succeed?

	is_critical: BOOLEAN
			-- Is this job critical (failure should abort pipeline)?
		do
			Result := False
		end

	last_error: STRING_32
			-- Error message from last failed apply
		attribute
			create Result.make_empty
		end

feature -- Results

	result_text: STRING_32
			-- Refined class text after successful apply
		attribute
			create Result.make_empty
		end

	changes_made: STRING_32
			-- Description of changes made (for logging)
		attribute
			create Result.make_empty
		end

feature -- Execution

	apply (a_ai: AI_CLIENT; a_class_text: STRING_32)
			-- Apply this refinement job to `a_class_text' using `a_ai'.
		require
			ai_not_void: a_ai /= Void
			text_not_empty: not a_class_text.is_empty
		local
			l_prompt: STRING_32
			l_response: AI_RESPONSE
		do
			-- Reset state
			is_success := False
			last_error.wipe_out
			result_text.wipe_out
			changes_made.wipe_out

			-- Build and send prompt
			l_prompt := build_prompt (a_class_text)
			l_response := a_ai.ask_with_system (eiffel_expert_system_prompt, l_prompt)

			if l_response.is_success then
				result_text := extract_eiffel_code (l_response.text)
				if not result_text.is_empty then
					is_success := True
					changes_made := name + " applied successfully"
				else
					last_error := "No Eiffel code extracted from response"
				end
			else
				if attached l_response.error_message as l_err then
					last_error := l_err.twin
				else
					last_error := "Unknown AI error"
				end
			end
		ensure
			success_has_result: is_success implies not result_text.is_empty
			failure_has_error: not is_success implies not last_error.is_empty
		end

feature {NONE} -- Implementation

	build_prompt (a_class_text: STRING_32): STRING_32
			-- Build the AI prompt for this refinement job
		require
			text_not_empty: not a_class_text.is_empty
		deferred
		ensure
			not_empty: not Result.is_empty
		end

	eiffel_expert_system_prompt: STRING_32
			-- Compact system prompt (~200 chars vs ~800 original)
		once
			Result := {STRING_32} "[
Expert Eiffel dev. DBC, void-safe, SCOOP, CQS.
simple_* over ISE stdlib. Contracts on public features.
STRING_32 concat: use {STRING_32} "text" + var (NOT "text" + var).
Output: ```eiffel class only, no explanation.
]"
		end

	differential_system_prompt: STRING_32
			-- System prompt for differential output mode
		once
			Result := {STRING_32} "[
Expert Eiffel dev. DBC, void-safe, SCOOP, CQS.
STRING_32 concat: use {STRING_32} "text" + var (NOT "text" + var).
Output CHANGES ONLY, format:
CHANGE:<location>|OLD:<exact text>|NEW:<replacement>
One change per line. No other output.
]"
		end

	extract_eiffel_code (a_response: STRING_32): STRING_32
			-- Extract Eiffel code from AI response (handles ```eiffel ... ``` markers)
		local
			l_start, l_end: INTEGER
		do
			create Result.make_empty

			-- Look for ```eiffel marker
			l_start := a_response.substring_index ("```eiffel", 1)
			if l_start > 0 then
				l_start := a_response.index_of ('%N', l_start) + 1
				l_end := a_response.substring_index ("```", l_start)
				if l_end > l_start then
					Result := a_response.substring (l_start, l_end - 1)
				elseif l_start <= a_response.count then
					Result := a_response.substring (l_start, a_response.count)
				end
			else
				-- Try plain ``` markers
				l_start := a_response.substring_index ("```", 1)
				if l_start > 0 then
					l_start := a_response.index_of ('%N', l_start) + 1
					l_end := a_response.substring_index ("```", l_start)
					if l_end > l_start then
						Result := a_response.substring (l_start, l_end - 1)
					elseif l_start <= a_response.count then
						Result := a_response.substring (l_start, a_response.count)
					end
				else
					-- No markers, return as-is
					Result := a_response.twin
				end
			end

			Result.left_adjust
			Result.right_adjust
		end

invariant
	error_exists: last_error /= Void
	result_exists: result_text /= Void
	changes_exists: changes_made /= Void

end
