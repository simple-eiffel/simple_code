note
	description: "[
		Pipeline events for the class generation assembly line.

		Provides a pub-sub mechanism using agents for external monitoring
		of the class-building cycle progression.

		Event Types:
			- pipeline_started: Pipeline begins execution
			- job_started: A refinement job begins
			- job_completed: A refinement job completes successfully
			- job_failed: A refinement job fails
			- pipeline_completed: Pipeline finishes (success or failure)

		Usage (subscriber):
			events.subscribe_job_started (agent my_handler)
			events.subscribe_job_completed (agent my_completion_handler)

		Usage (publisher - internal to pipeline):
			events.notify_job_started (job, class_text)
			events.notify_job_completed (job, refined_text)
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_PIPELINE_EVENTS

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize event subscriber lists
		do
			create pipeline_started_subscribers.make (5)
			create pipeline_completed_subscribers.make (5)
			create job_started_subscribers.make (5)
			create job_completed_subscribers.make (5)
			create job_failed_subscribers.make (5)
			create progress_subscribers.make (5)
		end

feature -- Pipeline Events

	subscribe_pipeline_started (a_handler: PROCEDURE [STRING_32])
			-- Subscribe to pipeline started event.
			-- Handler receives: system_spec
		require
			handler_not_void: a_handler /= Void
		do
			pipeline_started_subscribers.extend (a_handler)
		ensure
			subscribed: pipeline_started_subscribers.has (a_handler)
		end

	subscribe_pipeline_completed (a_handler: PROCEDURE [BOOLEAN, STRING_32])
			-- Subscribe to pipeline completed event.
			-- Handler receives: is_success, result_or_error
		require
			handler_not_void: a_handler /= Void
		do
			pipeline_completed_subscribers.extend (a_handler)
		ensure
			subscribed: pipeline_completed_subscribers.has (a_handler)
		end

feature -- Job Events

	subscribe_job_started (a_handler: PROCEDURE [STRING_32, INTEGER, INTEGER])
			-- Subscribe to job started event.
			-- Handler receives: job_name, job_index, total_jobs
		require
			handler_not_void: a_handler /= Void
		do
			job_started_subscribers.extend (a_handler)
		ensure
			subscribed: job_started_subscribers.has (a_handler)
		end

	subscribe_job_completed (a_handler: PROCEDURE [STRING_32, STRING_32, INTEGER, INTEGER])
			-- Subscribe to job completed event.
			-- Handler receives: job_name, changes_made, job_index, total_jobs
		require
			handler_not_void: a_handler /= Void
		do
			job_completed_subscribers.extend (a_handler)
		ensure
			subscribed: job_completed_subscribers.has (a_handler)
		end

	subscribe_job_failed (a_handler: PROCEDURE [STRING_32, STRING_32, BOOLEAN])
			-- Subscribe to job failed event.
			-- Handler receives: job_name, error_message, is_critical
		require
			handler_not_void: a_handler /= Void
		do
			job_failed_subscribers.extend (a_handler)
		ensure
			subscribed: job_failed_subscribers.has (a_handler)
		end

feature -- Progress Events

	subscribe_progress (a_handler: PROCEDURE [INTEGER, INTEGER, STRING_32])
			-- Subscribe to progress updates.
			-- Handler receives: completed_jobs, total_jobs, current_job_name
		require
			handler_not_void: a_handler /= Void
		do
			progress_subscribers.extend (a_handler)
		ensure
			subscribed: progress_subscribers.has (a_handler)
		end

feature -- Unsubscribe

	unsubscribe_all
			-- Remove all subscribers
		do
			pipeline_started_subscribers.wipe_out
			pipeline_completed_subscribers.wipe_out
			job_started_subscribers.wipe_out
			job_completed_subscribers.wipe_out
			job_failed_subscribers.wipe_out
			progress_subscribers.wipe_out
		ensure
			pipeline_started_empty: pipeline_started_subscribers.is_empty
			pipeline_completed_empty: pipeline_completed_subscribers.is_empty
			job_started_empty: job_started_subscribers.is_empty
			job_completed_empty: job_completed_subscribers.is_empty
			job_failed_empty: job_failed_subscribers.is_empty
			progress_empty: progress_subscribers.is_empty
		end

feature {SCG_CLASS_GEN, SCG_JOB_PIPELINE, SCG_WAVE_PIPELINE} -- Notification (internal use)

	notify_pipeline_started (a_system_spec: STRING_32)
			-- Notify subscribers that pipeline has started
		do
			across pipeline_started_subscribers as ic loop
				ic.call ([a_system_spec])
			end
		end

	notify_pipeline_completed (a_success: BOOLEAN; a_result_or_error: STRING_32)
			-- Notify subscribers that pipeline has completed
		do
			across pipeline_completed_subscribers as ic loop
				ic.call ([a_success, a_result_or_error])
			end
		end

	notify_job_started (a_job_name: STRING_32; a_index, a_total: INTEGER)
			-- Notify subscribers that a job has started
		require
			valid_index: a_index >= 1 and a_index <= a_total
		do
			across job_started_subscribers as ic loop
				ic.call ([a_job_name, a_index, a_total])
			end
		end

	notify_job_completed (a_job_name, a_changes: STRING_32; a_index, a_total: INTEGER)
			-- Notify subscribers that a job has completed
		require
			valid_index: a_index >= 1 and a_index <= a_total
		do
			across job_completed_subscribers as ic loop
				ic.call ([a_job_name, a_changes, a_index, a_total])
			end
			-- Also send progress update
			notify_progress (a_index, a_total, a_job_name)
		end

	notify_job_failed (a_job_name, a_error: STRING_32; a_is_critical: BOOLEAN)
			-- Notify subscribers that a job has failed
		do
			across job_failed_subscribers as ic loop
				ic.call ([a_job_name, a_error, a_is_critical])
			end
		end

	notify_progress (a_completed, a_total: INTEGER; a_current_job: STRING_32)
			-- Notify subscribers of progress update
		require
			valid_completed: a_completed >= 0 and a_completed <= a_total
		do
			across progress_subscribers as ic loop
				ic.call ([a_completed, a_total, a_current_job])
			end
		end

feature {NONE} -- Subscriber Lists

	pipeline_started_subscribers: ARRAYED_LIST [PROCEDURE [STRING_32]]
	pipeline_completed_subscribers: ARRAYED_LIST [PROCEDURE [BOOLEAN, STRING_32]]
	job_started_subscribers: ARRAYED_LIST [PROCEDURE [STRING_32, INTEGER, INTEGER]]
	job_completed_subscribers: ARRAYED_LIST [PROCEDURE [STRING_32, STRING_32, INTEGER, INTEGER]]
	job_failed_subscribers: ARRAYED_LIST [PROCEDURE [STRING_32, STRING_32, BOOLEAN]]
	progress_subscribers: ARRAYED_LIST [PROCEDURE [INTEGER, INTEGER, STRING_32]]

invariant
	pipeline_started_exists: pipeline_started_subscribers /= Void
	pipeline_completed_exists: pipeline_completed_subscribers /= Void
	job_started_exists: job_started_subscribers /= Void
	job_completed_exists: job_completed_subscribers /= Void
	job_failed_exists: job_failed_subscribers /= Void
	progress_exists: progress_subscribers /= Void

end
