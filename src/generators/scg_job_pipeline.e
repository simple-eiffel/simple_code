note
	description: "[
		Job pipeline for the class generation assembly line.

		Executes refinement jobs sequentially, applying each to the
		generated class text. Publishes events for external monitoring
		via SCG_PIPELINE_EVENTS.

		Pipeline Phases (by priority):
			100-149: Structure/Naming (naming, CQS, void safety)
			150-199: Semantic (semantic framing)
			200-299: Contracts (contractor, completeness, specification)
			300-399: Final Review (code review)

		Usage:
			create pipeline.make (registry, ai_client)
			pipeline.events.subscribe_progress (agent my_progress_handler)
			pipeline.execute (initial_class_text)
			if pipeline.is_success then
				final_text := pipeline.result_text
			end
	]"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_JOB_PIPELINE

create
	make

feature {NONE} -- Initialization

	make (a_registry: SCG_JOB_REGISTRY; a_ai: AI_CLIENT)
			-- Create pipeline with job registry and AI client
		require
			registry_not_void: a_registry /= Void
			ai_not_void: a_ai /= Void
		do
			registry := a_registry
			ai_client := a_ai
			create events.make
			create result_text.make_empty
			create last_error.make_empty
			create execution_log.make (20)
		ensure
			registry_set: registry = a_registry
			ai_set: ai_client = a_ai
			events_exists: events /= Void
		end

feature -- Access

	registry: SCG_JOB_REGISTRY
			-- Job registry providing available jobs

	ai_client: AI_CLIENT
			-- AI client for job execution

	events: SCG_PIPELINE_EVENTS
			-- Event publisher for monitoring

	result_text: STRING_32
			-- Final refined class text (if successful)

	last_error: STRING_32
			-- Error message (if failed)

	execution_log: ARRAYED_LIST [STRING_32]
			-- Log of pipeline execution

	completed_jobs: INTEGER
			-- Number of successfully completed jobs

	total_jobs: INTEGER
			-- Total number of jobs to execute

feature -- Status

	is_success: BOOLEAN
			-- Did pipeline execute successfully?

	is_running: BOOLEAN
			-- Is pipeline currently executing?

	current_job_name: STRING_32
			-- Name of currently executing job (if running)
		attribute
			create Result.make_empty
		end

feature -- Execution

	execute (a_initial_text: STRING_32)
			-- Execute all jobs in priority order on initial text
		require
			text_not_empty: not a_initial_text.is_empty
			not_running: not is_running
		local
			l_jobs: ARRAYED_LIST [SCG_REFINEMENT_JOB]
			l_current_text: STRING_32
			l_index: INTEGER
			l_abort: BOOLEAN
		do
			-- Initialize state
			is_running := True
			is_success := False
			completed_jobs := 0
			result_text.wipe_out
			last_error.wipe_out
			execution_log.wipe_out
			l_current_text := a_initial_text.twin

			-- Get jobs sorted by priority
			l_jobs := registry.jobs_by_priority
			total_jobs := l_jobs.count

			-- Notify pipeline started
			events.notify_pipeline_started ("Pipeline starting with " + total_jobs.out + " jobs")
			log_entry ("Pipeline started with " + total_jobs.out + " jobs")

			-- Execute each job
			from
				l_index := 1
			until
				l_index > l_jobs.count or l_abort
			loop
				l_current_text := execute_job (l_jobs [l_index], l_current_text, l_index, total_jobs)

				if l_jobs [l_index].is_success then
					completed_jobs := completed_jobs + 1
				elseif l_jobs [l_index].is_critical then
					l_abort := True
					last_error := "Critical job failed: " + l_jobs [l_index].name + " - " + l_jobs [l_index].last_error
					log_entry ("ABORT: " + last_error)
				end
				-- Non-critical failures continue with unchanged text

				l_index := l_index + 1
			end

			-- Finalize
			if l_abort then
				is_success := False
				events.notify_pipeline_completed (False, last_error)
			else
				is_success := True
				result_text := l_current_text
				events.notify_pipeline_completed (True, "Completed " + completed_jobs.out + "/" + total_jobs.out + " jobs")
				log_entry ("Pipeline completed successfully")
			end

			is_running := False
			current_job_name.wipe_out
		ensure
			not_running: not is_running
			success_has_result: is_success implies not result_text.is_empty
			failure_has_error: not is_success implies not last_error.is_empty
		end

	execute_subset (a_initial_text: STRING_32; a_job_names: ARRAY [STRING_32])
			-- Execute only the specified jobs (by name) in priority order
		require
			text_not_empty: not a_initial_text.is_empty
			names_not_empty: not a_job_names.is_empty
			not_running: not is_running
		local
			l_jobs: ARRAYED_LIST [SCG_REFINEMENT_JOB]
			l_job: detachable SCG_REFINEMENT_JOB
			l_current_text: STRING_32
			l_index: INTEGER
			l_abort: BOOLEAN
		do
			-- Initialize state
			is_running := True
			is_success := False
			completed_jobs := 0
			result_text.wipe_out
			last_error.wipe_out
			execution_log.wipe_out
			l_current_text := a_initial_text.twin

			-- Collect specified jobs
			create l_jobs.make (a_job_names.count)
			across a_job_names as ic loop
				l_job := registry.job_by_name (ic)
				if attached l_job as lj then
					l_jobs.extend (lj)
				else
					log_entry ("WARNING: Job not found: " + ic)
				end
			end

			-- Sort by priority
			-- (reuse registry's sorting logic via a temp registry)
			total_jobs := l_jobs.count

			events.notify_pipeline_started ("Subset pipeline with " + total_jobs.out + " jobs")
			log_entry ("Subset pipeline started with " + total_jobs.out + " jobs")

			-- Execute each job
			from
				l_index := 1
			until
				l_index > l_jobs.count or l_abort
			loop
				l_current_text := execute_job (l_jobs [l_index], l_current_text, l_index, total_jobs)

				if l_jobs [l_index].is_success then
					completed_jobs := completed_jobs + 1
				elseif l_jobs [l_index].is_critical then
					l_abort := True
					last_error := "Critical job failed: " + l_jobs [l_index].name
				end

				l_index := l_index + 1
			end

			-- Finalize
			if l_abort then
				is_success := False
				events.notify_pipeline_completed (False, last_error)
			else
				is_success := True
				result_text := l_current_text
				events.notify_pipeline_completed (True, "Completed " + completed_jobs.out + "/" + total_jobs.out + " jobs")
			end

			is_running := False
			current_job_name.wipe_out
		ensure
			not_running: not is_running
		end

feature {NONE} -- Implementation

	execute_job (a_job: SCG_REFINEMENT_JOB; a_text: STRING_32; a_index, a_total: INTEGER): STRING_32
			-- Execute single job, return refined text (or original if failed)
		require
			job_not_void: a_job /= Void
			text_not_empty: not a_text.is_empty
		do
			current_job_name := a_job.name

			-- Notify job started
			events.notify_job_started (a_job.name, a_index, a_total)
			log_entry ("Starting job: " + a_job.name + " (" + a_index.out + "/" + a_total.out + ")")

			-- Execute
			a_job.apply (ai_client, a_text)

			if a_job.is_success then
				Result := a_job.result_text
				events.notify_job_completed (a_job.name, a_job.changes_made, a_index, a_total)
				log_entry ("Completed: " + a_job.name)
			else
				Result := a_text -- Return original on failure
				events.notify_job_failed (a_job.name, a_job.last_error, a_job.is_critical)
				log_entry ("Failed: " + a_job.name + " - " + a_job.last_error)
			end
		ensure
			has_result: not Result.is_empty
		end

	log_entry (a_message: STRING_32)
			-- Add entry to execution log
		do
			execution_log.extend (a_message)
		end

invariant
	registry_exists: registry /= Void
	ai_exists: ai_client /= Void
	events_exists: events /= Void
	result_exists: result_text /= Void
	error_exists: last_error /= Void
	log_exists: execution_log /= Void

end
