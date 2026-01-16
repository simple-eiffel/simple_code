note
	description: "[
		Registry of available refinement jobs for the class generation pipeline.

		Provides:
		- All available jobs sorted by priority
		- Job lookup by name
		- Default job pipeline configuration

		Jobs are derived from reference documentation:
		- D:\prod\reference_docs\claude\NAMING_CONVENTIONS.md
		- D:\prod\reference_docs\claude\contract_patterns.md
		- D:\prod\reference_docs\claude\verification_process.md
		- D:\prod\reference_docs\claude\HATS.md
		- D:\prod\reference_docs\claude\EIFFEL_MENTAL_MODEL.md
		- D:\prod\reference_docs\standards\SEMANTIC_FRAME_NAMING.md

		Usage:
			registry := (create {SCG_JOB_REGISTRY}).default_registry
			across registry.jobs_by_priority as ic loop
				io.put_string (ic.name)
			end
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_JOB_REGISTRY

create
	make,
	default_registry

feature {NONE} -- Initialization

	make
			-- Create empty registry
		do
			create jobs.make (10)
		ensure
			jobs_empty: jobs.is_empty
		end

	default_registry
			-- Create registry with all standard jobs
		do
			make
			register_standard_jobs
		ensure
			has_jobs: not jobs.is_empty
		end

feature -- Access

	jobs: ARRAYED_LIST [SCG_REFINEMENT_JOB]
			-- All registered jobs (unsorted)

	jobs_by_priority: ARRAYED_LIST [SCG_REFINEMENT_JOB]
			-- All jobs sorted by priority (lower priority number = earlier execution)
		local
			l_temp: detachable SCG_REFINEMENT_JOB
			i, j: INTEGER
			l_swapped: BOOLEAN
		do
			create Result.make_from_array (jobs.to_array)
			-- Simple bubble sort (job count is small, ~10 items max)
			from
				i := 1
			until
				i >= Result.count
			loop
				l_swapped := False
				from
					j := 1
				until
					j > Result.count - i
				loop
					if Result [j].priority > Result [j + 1].priority then
						-- Swap
						l_temp := Result [j]
						Result [j] := Result [j + 1]
						check attached l_temp as lt then
							Result [j + 1] := lt
						end
						l_swapped := True
					end
					j := j + 1
				end
				if not l_swapped then
					i := Result.count -- Exit early if sorted
				end
				i := i + 1
			end
		ensure
			same_count: Result.count = jobs.count
			sorted: across 1 |..| (Result.count - 1) as ic_idx all
				Result [ic_idx].priority <= Result [ic_idx + 1].priority
			end
		end

	job_by_name (a_name: STRING_32): detachable SCG_REFINEMENT_JOB
			-- Find job by name (case-insensitive)
		require
			name_not_empty: not a_name.is_empty
		do
			across jobs as ic until Result /= Void loop
				if ic.name.is_case_insensitive_equal (a_name) then
					Result := ic
				end
			end
		end

	job_count: INTEGER
			-- Number of registered jobs
		do
			Result := jobs.count
		end

feature -- Status

	has_job (a_name: STRING_32): BOOLEAN
			-- Is there a job with this name?
		require
			name_not_empty: not a_name.is_empty
		do
			Result := job_by_name (a_name) /= Void
		end

feature -- Registration

	register (a_job: SCG_REFINEMENT_JOB)
			-- Register a job
		require
			job_not_void: a_job /= Void
			not_duplicate: not has_job (a_job.name)
		do
			jobs.extend (a_job)
		ensure
			registered: has_job (a_job.name)
			count_increased: job_count = old job_count + 1
		end

	unregister (a_name: STRING_32)
			-- Remove a job by name
		require
			name_not_empty: not a_name.is_empty
			exists: has_job (a_name)
		local
			l_job: detachable SCG_REFINEMENT_JOB
		do
			l_job := job_by_name (a_name)
			if attached l_job as lj then
				jobs.prune (lj)
			end
		ensure
			removed: not has_job (a_name)
			count_decreased: job_count = old job_count - 1
		end

feature -- Queries

	job_names: ARRAYED_LIST [STRING_32]
			-- Names of all registered jobs
		do
			create Result.make (jobs.count)
			across jobs as ic loop
				Result.extend (ic.name)
			end
		ensure
			same_count: Result.count = jobs.count
		end

	jobs_in_priority_range (a_min, a_max: INTEGER): ARRAYED_LIST [SCG_REFINEMENT_JOB]
			-- Jobs with priority in range [a_min, a_max], sorted by priority
		require
			valid_range: a_min <= a_max
		do
			create Result.make (5)
			across jobs_by_priority as ic loop
				if ic.priority >= a_min and ic.priority <= a_max then
					Result.extend (ic)
				end
			end
		ensure
			all_in_range: across Result as ic all
				ic.priority >= a_min and ic.priority <= a_max
			end
		end

feature {NONE} -- Implementation

	register_standard_jobs
			-- Register all standard refinement jobs
		do
			-- Priority 100-149: Structure/Naming passes
			register (create {SCG_NAMING_JOB})
			register (create {SCG_CQS_JOB})
			register (create {SCG_VOID_SAFETY_JOB})

			-- Priority 150-199: Semantic passes
			register (create {SCG_SEMANTIC_FRAMING_JOB})

			-- Priority 200-299: Contract passes
			register (create {SCG_CONTRACTOR_HAT_JOB})
			register (create {SCG_CONTRACT_COMPLETENESS_JOB})
			register (create {SCG_SPECIFICATION_HAT_JOB})

			-- Priority 300-399: Final review passes
			register (create {SCG_CODE_REVIEW_JOB})
		ensure
			has_jobs: job_count >= 8
		end

invariant
	jobs_exists: jobs /= Void

end
