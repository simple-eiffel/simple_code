note
	description: "[
		Executes multiple refinement jobs within a wave.

		Currently executes jobs sequentially within the wave.
		SCOOP parallelization can be added in a future version.

		Results are merged using SCG_CHANGE_MERGER.

		Usage:
			create wave.make (jobs, ai_client_factory)
			result := wave.execute (class_text)
			if wave.has_errors then
				print (wave.error_log)
			end
	]"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_PARALLEL_WAVE

create
	make

feature {NONE} -- Initialization

	make (a_jobs: ARRAY [SCG_REFINEMENT_JOB]; a_ai_factory: FUNCTION [AI_CLIENT])
			-- Create wave with jobs and AI client factory.
			-- Factory creates a new AI_CLIENT for each worker.
		require
			jobs_not_empty: not a_jobs.is_empty
			factory_not_void: a_ai_factory /= Void
		local
			i: INTEGER
			l_worker: SCG_WAVE_WORKER
			l_ai: AI_CLIENT
		do
			create workers.make (a_jobs.count)
			create merger.make
			create error_log.make (10)
			create result_text.make_empty
			ai_factory := a_ai_factory

			-- Create a worker for each job
			from i := a_jobs.lower until i > a_jobs.upper loop
				l_ai := a_ai_factory.item (Void)
				create l_worker.make (a_jobs [i], l_ai)
				workers.extend (l_worker)
				i := i + 1
			end

			job_count := a_jobs.count
		ensure
			workers_created: workers.count = a_jobs.count
			job_count_set: job_count = a_jobs.count
		end

feature -- Access

	workers: ARRAYED_LIST [SCG_WAVE_WORKER]
			-- Workers (one per job)

	merger: SCG_CHANGE_MERGER
			-- Merges changes from all workers

	result_text: STRING_32
			-- Final merged result

	error_log: ARRAYED_LIST [STRING_32]
			-- Errors from failed workers

	job_count: INTEGER
			-- Number of jobs in this wave

	completed_count: INTEGER
			-- Number of workers that completed successfully

	ai_factory: FUNCTION [AI_CLIENT]
			-- Factory to create AI clients

feature -- Status

	has_errors: BOOLEAN
			-- Did any worker fail?
		do
			Result := not error_log.is_empty
		end

	all_successful: BOOLEAN
			-- Did all workers complete successfully?
		do
			Result := completed_count = job_count
		end

feature -- Execution

	execute (a_class_text: STRING_32): STRING_32
			-- Execute all jobs in wave, merge results.
			-- Currently sequential; SCOOP parallelization planned for future.
		require
			text_not_empty: not a_class_text.is_empty
		local
			l_all_changes: ARRAYED_LIST [SCG_JOB_CHANGE]
			l_use_differential: BOOLEAN
			l_worker: SCG_WAVE_WORKER
		do
			-- Reset state
			error_log.wipe_out
			result_text.wipe_out
			completed_count := 0
			l_use_differential := True

			-- Execute all workers (currently sequential)
			across workers as ic loop
				l_worker := ic
				l_worker.execute (a_class_text)
			end

			-- Collect results
			create l_all_changes.make (50)
			across workers as ic loop
				l_worker := ic
				if l_worker.is_success then
					completed_count := completed_count + 1
					-- Copy changes
					across l_worker.changes as jc loop
						l_all_changes.extend (jc)
					end
					-- Check if worker used differential output
					if l_worker.changes.is_empty then
						l_use_differential := False
					end
				else
					error_log.extend ({STRING_32} "Worker " + l_worker.job_name + " failed: " + l_worker.error_message)
				end
			end

			-- Merge results
			if l_use_differential and not l_all_changes.is_empty then
				-- Use differential merge
				result_text := merger.merge (a_class_text, l_all_changes)
			else
				-- Fallback: use last successful worker's full output
				result_text := get_best_full_result (a_class_text)
			end

			Result := result_text
		ensure
			result_not_empty: not Result.is_empty
		end

feature {NONE} -- Implementation

	get_best_full_result (a_fallback: STRING_32): STRING_32
			-- Get full result from highest-priority successful worker
		local
			l_best_priority: INTEGER
			l_worker: SCG_WAVE_WORKER
		do
			Result := a_fallback
			l_best_priority := -1

			across workers as ic loop
				l_worker := ic
				if l_worker.is_done and l_worker.is_success then
					if l_worker.job.priority > l_best_priority then
						l_best_priority := l_worker.job.priority
						if not l_worker.result_text.is_empty then
							Result := l_worker.result_text.twin
						end
					end
				end
			end
		end

invariant
	workers_exists: workers /= Void
	merger_exists: merger /= Void
	error_log_exists: error_log /= Void
	result_text_exists: result_text /= Void
	ai_factory_exists: ai_factory /= Void

end
