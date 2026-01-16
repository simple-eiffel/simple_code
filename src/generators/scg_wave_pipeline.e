note
	description: "[
		Orchestrates wave-based parallel job execution.

		Jobs are grouped into waves based on logical independence:
		- Wave 1: Structural jobs (Naming, CQS, Void Safety) - PARALLEL
		- Wave 2: Semantic job (Semantic Framing) - SEQUENTIAL
		- Wave 3: Contract jobs (Contractor, Completeness, Specification) - PARALLEL
		- Wave 4: Review job (Code Review) - SEQUENTIAL

		Usage:
			create pipeline.make (ai_client_factory, events)
			result := pipeline.execute (class_text)
	]"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_WAVE_PIPELINE

create
	make

feature {NONE} -- Initialization

	make (a_ai_factory: FUNCTION [AI_CLIENT]; a_events: detachable SCG_PIPELINE_EVENTS)
			-- Create pipeline with AI client factory and optional events.
		require
			factory_not_void: a_ai_factory /= Void
		do
			ai_client_factory := a_ai_factory
			events := a_events
			create wave_1_jobs.make (3)
			create wave_3_jobs.make (3)
			create error_log.make (10)
			setup_waves
		ensure
			factory_set: ai_client_factory = a_ai_factory
			events_set: events = a_events
		end

feature -- Access

	ai_client_factory: FUNCTION [AI_CLIENT]
			-- Factory to create AI clients (one per parallel worker)

	events: detachable SCG_PIPELINE_EVENTS
			-- Optional event notifications

	wave_1_jobs: ARRAYED_LIST [SCG_REFINEMENT_JOB]
			-- Structural jobs (parallel): Naming, CQS, Void Safety

	semantic_job: detachable SCG_REFINEMENT_JOB
			-- Semantic framing job (sequential)

	wave_3_jobs: ARRAYED_LIST [SCG_REFINEMENT_JOB]
			-- Contract jobs (parallel): Contractor, Completeness, Specification

	review_job: detachable SCG_REFINEMENT_JOB
			-- Code review job (sequential)

	error_log: ARRAYED_LIST [STRING_32]
			-- Errors from execution

feature -- Status

	has_errors: BOOLEAN
			-- Did any wave fail?
		do
			Result := not error_log.is_empty
		end

	last_wave_completed: INTEGER
			-- Index of last successfully completed wave (0-4)

feature -- Execution

	execute (a_class_text: STRING_32): STRING_32
			-- Execute all waves, return refined class text.
		require
			text_not_empty: not a_class_text.is_empty
		local
			l_result: STRING_32
			l_ai: AI_CLIENT
		do
			-- Reset state
			error_log.wipe_out
			last_wave_completed := 0
			l_result := a_class_text

			notify_pipeline_started

			-- Wave 1: Parallel structural jobs
			if not wave_1_jobs.is_empty then
				notify_wave_started (1, "Structural")
				l_result := execute_parallel_wave (wave_1_jobs, l_result)
				if not has_errors then
					last_wave_completed := 1
					notify_wave_completed (1)
				end
			end

			-- Wave 2: Sequential semantic job
			if not has_errors and attached semantic_job as sj then
				notify_wave_started (2, "Semantic")
				l_ai := ai_client_factory.item (Void)
				l_result := execute_sequential_job (sj, l_ai, l_result)
				if not has_errors then
					last_wave_completed := 2
					notify_wave_completed (2)
				end
			end

			-- Wave 3: Parallel contract jobs
			if not has_errors and not wave_3_jobs.is_empty then
				notify_wave_started (3, "Contracts")
				l_result := execute_parallel_wave (wave_3_jobs, l_result)
				if not has_errors then
					last_wave_completed := 3
					notify_wave_completed (3)
				end
			end

			-- Wave 4: Sequential review job
			if not has_errors and attached review_job as rj then
				notify_wave_started (4, "Review")
				l_ai := ai_client_factory.item (Void)
				l_result := execute_sequential_job (rj, l_ai, l_result)
				if not has_errors then
					last_wave_completed := 4
					notify_wave_completed (4)
				end
			end

			notify_pipeline_completed (not has_errors)

			Result := l_result
		ensure
			result_not_empty: not Result.is_empty
		end

feature -- Configuration

	set_wave_1_jobs (a_jobs: ARRAYED_LIST [SCG_REFINEMENT_JOB])
			-- Set structural jobs for wave 1.
		require
			jobs_not_void: a_jobs /= Void
		do
			wave_1_jobs := a_jobs
		ensure
			wave_1_set: wave_1_jobs = a_jobs
		end

	set_semantic_job (a_job: SCG_REFINEMENT_JOB)
			-- Set semantic framing job.
		require
			job_not_void: a_job /= Void
		do
			semantic_job := a_job
		ensure
			semantic_set: semantic_job = a_job
		end

	set_wave_3_jobs (a_jobs: ARRAYED_LIST [SCG_REFINEMENT_JOB])
			-- Set contract jobs for wave 3.
		require
			jobs_not_void: a_jobs /= Void
		do
			wave_3_jobs := a_jobs
		ensure
			wave_3_set: wave_3_jobs = a_jobs
		end

	set_review_job (a_job: SCG_REFINEMENT_JOB)
			-- Set code review job.
		require
			job_not_void: a_job /= Void
		do
			review_job := a_job
		ensure
			review_set: review_job = a_job
		end

feature {NONE} -- Wave Execution

	execute_parallel_wave (a_jobs: ARRAYED_LIST [SCG_REFINEMENT_JOB]; a_text: STRING_32): STRING_32
			-- Execute jobs in parallel, merge results.
		require
			jobs_not_empty: not a_jobs.is_empty
			text_not_empty: not a_text.is_empty
		local
			l_wave: SCG_PARALLEL_WAVE
		do
			create l_wave.make (a_jobs.to_array, ai_client_factory)
			Result := l_wave.execute (a_text)

			if l_wave.has_errors then
				across l_wave.error_log as ic loop
					error_log.extend (ic)
				end
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	execute_sequential_job (a_job: SCG_REFINEMENT_JOB; a_ai: AI_CLIENT; a_text: STRING_32): STRING_32
			-- Execute single job sequentially.
		require
			job_not_void: a_job /= Void
			ai_not_void: a_ai /= Void
			text_not_empty: not a_text.is_empty
		do
			notify_job_started (a_job.name)
			a_job.apply (a_ai, a_text)

			if a_job.is_success then
				Result := a_job.result_text
				notify_job_completed (a_job.name)
			else
				Result := a_text
				error_log.extend ("Job " + a_job.name + " failed: " + a_job.last_error)
				notify_job_failed (a_job.name, a_job.last_error)
			end
		ensure
			result_not_empty: not Result.is_empty
		end

feature {NONE} -- Wave Setup

	setup_waves
			-- Configure default wave assignments from registry.
		local
			l_registry: SCG_JOB_REGISTRY
		do
			create l_registry.default_registry

			-- Wave 1: Priority 100-120 (Structural)
			across l_registry.jobs_in_priority_range (100, 120) as ic loop
				wave_1_jobs.extend (ic)
			end

			-- Wave 2: Priority 150 (Semantic)
			semantic_job := l_registry.job_by_name ("semantic_framing")

			-- Wave 3: Priority 200-220 (Contracts)
			across l_registry.jobs_in_priority_range (200, 220) as ic loop
				wave_3_jobs.extend (ic)
			end

			-- Wave 4: Priority 300 (Review)
			review_job := l_registry.job_by_name ("code_review")
		end

feature {NONE} -- Event Notifications

	notify_pipeline_started
			-- Notify that pipeline has started.
		do
			if attached events as ev then
				ev.notify_pipeline_started ("Wave Pipeline")
			end
		end

	notify_pipeline_completed (a_success: BOOLEAN)
			-- Notify that pipeline has completed.
		do
			if attached events as ev then
				if a_success then
					ev.notify_pipeline_completed (a_success, "All waves completed")
				else
					ev.notify_pipeline_completed (a_success, "Wave pipeline failed")
				end
			end
		end

	notify_wave_started (a_wave: INTEGER; a_name: STRING_32)
			-- Notify that wave has started.
		do
			if attached events as ev then
				ev.notify_job_started ("Wave " + a_wave.out + ": " + a_name, a_wave, 4)
			end
		end

	notify_wave_completed (a_wave: INTEGER)
			-- Notify that wave has completed.
		do
			if attached events as ev then
				ev.notify_job_completed ("Wave " + a_wave.out, "Wave completed", a_wave, 4)
			end
		end

	notify_job_started (a_job_name: STRING_32)
			-- Notify that job has started.
		do
			if attached events as ev then
				ev.notify_job_started (a_job_name, 1, 1)
			end
		end

	notify_job_completed (a_job_name: STRING_32)
			-- Notify that job has completed.
		do
			if attached events as ev then
				ev.notify_job_completed (a_job_name, "Job completed", 1, 1)
			end
		end

	notify_job_failed (a_job_name, a_error: STRING_32)
			-- Notify that job has failed.
		do
			if attached events as ev then
				ev.notify_job_failed (a_job_name, a_error, False)
			end
		end

invariant
	factory_exists: ai_client_factory /= Void
	wave_1_exists: wave_1_jobs /= Void
	wave_3_exists: wave_3_jobs /= Void
	error_log_exists: error_log /= Void

end
