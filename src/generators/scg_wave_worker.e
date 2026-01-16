note
	description: "[
		SCOOP-compatible worker for parallel job execution.

		Each worker runs on its own SCOOP processor (thread) with its own
		AI client instance, enabling true parallel AI API calls.

		Usage:
			create worker.make (naming_job, claude_client)
			-- In coordinator:
			launch_worker (worker, class_text)  -- async command
			wait_for_worker (worker)             -- sync via precondition
			changes := get_worker_changes (worker)
	]"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_WAVE_WORKER

create
	make

feature {NONE} -- Initialization

	make (a_job: SCG_REFINEMENT_JOB; a_ai: AI_CLIENT)
			-- Create worker with job and AI client
		require
			job_not_void: a_job /= Void
			ai_not_void: a_ai /= Void
		do
			job := a_job
			ai_client := a_ai
			create changes.make (10)
			create result_text.make_empty
			create error_message.make_empty
			is_done := False
			is_success := False
		ensure
			job_set: job = a_job
			ai_set: ai_client = a_ai
			not_done: not is_done
			not_success: not is_success
		end

feature -- Access

	job: SCG_REFINEMENT_JOB
			-- The refinement job to execute

	ai_client: AI_CLIENT
			-- AI client for this worker (each worker has own instance)

	changes: ARRAYED_LIST [SCG_JOB_CHANGE]
			-- Changes produced by the job (for differential output mode)

	result_text: STRING_32
			-- Full result text (for full-output mode fallback)

	error_message: STRING_32
			-- Error message if job failed

	job_name: STRING_32
			-- Name of the job
		do
			Result := job.name
		end

feature -- Status

	is_done: BOOLEAN
			-- Has this worker finished execution?

	is_success: BOOLEAN
			-- Did the job complete successfully?

feature -- Execution

	execute (a_class_text: STRING_32)
			-- Execute the job on the given class text.
			-- This is an ASYNC command - returns immediately when called on separate object.
		require
			text_not_empty: not a_class_text.is_empty
			not_already_done: not is_done
		do
			-- Reset state
			changes.wipe_out
			result_text.wipe_out
			error_message.wipe_out
			is_success := False

			-- Execute the job
			job.apply (ai_client, a_class_text)

			if job.is_success then
				result_text := job.result_text.twin
				-- Try to parse differential changes from result
				parse_differential_output (job.result_text)
				is_success := True
			else
				error_message := job.last_error.twin
			end

			is_done := True
		ensure
			now_done: is_done
			success_has_result: is_success implies not result_text.is_empty
			failure_has_error: not is_success implies not error_message.is_empty
		end

	reset
			-- Reset worker for reuse
		do
			is_done := False
			is_success := False
			changes.wipe_out
			result_text.wipe_out
			error_message.wipe_out
		ensure
			not_done: not is_done
			not_success: not is_success
			changes_empty: changes.is_empty
		end

feature {NONE} -- Differential Output Parsing

	parse_differential_output (a_response: STRING_32)
			-- Try to extract differential changes from AI response.
			-- Format: CHANGE:<location>|OLD:<text>|NEW:<text>
		local
			l_lines: LIST [STRING_32]
			l_line: STRING_32
			l_change: detachable SCG_JOB_CHANGE
		do
			l_lines := a_response.split ('%N')
			across l_lines as ic loop
				l_line := ic
				l_line.left_adjust
				l_line.right_adjust
				if l_line.starts_with ("CHANGE:") then
					l_change := parse_change_line (l_line)
					if attached l_change as lc then
						changes.extend (lc)
					end
				end
			end
		end

	parse_change_line (a_line: STRING_32): detachable SCG_JOB_CHANGE
			-- Parse a single change line.
			-- Format: CHANGE:<location>|OLD:<text>|NEW:<text>
		local
			l_parts: LIST [STRING_32]
			l_location, l_old, l_new: STRING_32
			l_temp: STRING_32
		do
			-- Remove "CHANGE:" prefix
			l_temp := a_line.substring (8, a_line.count)
			l_parts := l_temp.split ('|')

			if l_parts.count >= 3 then
				-- Extract location
				l_location := l_parts [1]
				l_location.left_adjust
				l_location.right_adjust

				-- Extract OLD: part
				l_old := l_parts [2]
				if l_old.starts_with ("OLD:") then
					l_old := l_old.substring (5, l_old.count)
				end
				l_old.left_adjust
				l_old.right_adjust

				-- Extract NEW: part
				l_new := l_parts [3]
				if l_new.starts_with ("NEW:") then
					l_new := l_new.substring (5, l_new.count)
				end
				l_new.left_adjust
				l_new.right_adjust

				if not l_location.is_empty and not l_old.is_empty then
					if l_new.is_empty then
						create Result.make_delete (l_location, l_old, job.name, job.priority)
					else
						create Result.make_replace (l_location, l_old, l_new, job.name, job.priority)
					end
				end
			end
		end

invariant
	job_exists: job /= Void
	ai_exists: ai_client /= Void
	changes_exists: changes /= Void
	result_text_exists: result_text /= Void
	error_exists: error_message /= Void

end
