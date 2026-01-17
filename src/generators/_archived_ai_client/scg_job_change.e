note
	description: "[
		Represents a single change proposed by a refinement job.

		Used for differential output mode where jobs output specific changes
		instead of full class text. This enables parallel job execution with
		merge-based result combination.

		Change Types:
			Replace: Find old_text and replace with new_text
			Insert: Add new_text at specified location
			Delete: Remove old_text

		Usage:
			create change.make_replace ("feature_name", "old code", "new code", "naming_job", 100)
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_JOB_CHANGE

create
	make_replace,
	make_insert,
	make_delete

feature {NONE} -- Initialization

	make_replace (a_location, a_old_text, a_new_text, a_job_name: STRING_32; a_priority: INTEGER)
			-- Create a replacement change
		require
			location_not_empty: not a_location.is_empty
			old_text_not_empty: not a_old_text.is_empty
			new_text_not_empty: not a_new_text.is_empty
			job_name_not_empty: not a_job_name.is_empty
		do
			change_type := Change_replace
			location := a_location
			old_text := a_old_text
			new_text := a_new_text
			job_name := a_job_name
			priority := a_priority
		ensure
			is_replace: change_type = Change_replace
			location_set: location = a_location
			old_text_set: old_text = a_old_text
			new_text_set: new_text = a_new_text
			job_name_set: job_name = a_job_name
			priority_set: priority = a_priority
		end

	make_insert (a_location, a_new_text, a_job_name: STRING_32; a_priority: INTEGER)
			-- Create an insertion change
		require
			location_not_empty: not a_location.is_empty
			new_text_not_empty: not a_new_text.is_empty
			job_name_not_empty: not a_job_name.is_empty
		do
			change_type := Change_insert
			location := a_location
			create old_text.make_empty
			new_text := a_new_text
			job_name := a_job_name
			priority := a_priority
		ensure
			is_insert: change_type = Change_insert
			location_set: location = a_location
			new_text_set: new_text = a_new_text
		end

	make_delete (a_location, a_old_text, a_job_name: STRING_32; a_priority: INTEGER)
			-- Create a deletion change
		require
			location_not_empty: not a_location.is_empty
			old_text_not_empty: not a_old_text.is_empty
			job_name_not_empty: not a_job_name.is_empty
		do
			change_type := Change_delete
			location := a_location
			old_text := a_old_text
			create new_text.make_empty
			job_name := a_job_name
			priority := a_priority
		ensure
			is_delete: change_type = Change_delete
			location_set: location = a_location
			old_text_set: old_text = a_old_text
		end

feature -- Access

	change_type: INTEGER
			-- Type of change (Replace, Insert, Delete)

	location: STRING_32
			-- Where in the class this change applies (feature name or marker)

	old_text: STRING_32
			-- Text to find (for Replace/Delete)

	new_text: STRING_32
			-- Text to insert (for Replace/Insert)

	job_name: STRING_32
			-- Which job proposed this change

	priority: INTEGER
			-- Priority for conflict resolution (higher wins)

feature -- Status

	is_replace: BOOLEAN
			-- Is this a replacement change?
		do
			Result := change_type = Change_replace
		end

	is_insert: BOOLEAN
			-- Is this an insertion change?
		do
			Result := change_type = Change_insert
		end

	is_delete: BOOLEAN
			-- Is this a deletion change?
		do
			Result := change_type = Change_delete
		end

	conflicts_with (other: SCG_JOB_CHANGE): BOOLEAN
			-- Does this change conflict with `other`?
			-- Conflict if both modify same old_text
		do
			if is_replace or is_delete then
				if other.is_replace or other.is_delete then
					Result := old_text.same_string (other.old_text)
				end
			end
		end

feature -- Comparison

	has_higher_priority (other: SCG_JOB_CHANGE): BOOLEAN
			-- Does this change have higher priority than `other`?
		do
			Result := priority > other.priority
		end

feature -- Output

	to_string: STRING_32
			-- String representation for logging
		do
			create Result.make (200)
			Result.append ("[")
			Result.append (job_name)
			Result.append ("] ")
			inspect change_type
			when Change_replace then
				Result.append ("REPLACE at ")
			when Change_insert then
				Result.append ("INSERT at ")
			when Change_delete then
				Result.append ("DELETE at ")
			else
				Result.append ("UNKNOWN at ")
			end
			Result.append (location)
		end

feature -- Constants

	Change_replace: INTEGER = 1
	Change_insert: INTEGER = 2
	Change_delete: INTEGER = 3

invariant
	location_exists: location /= Void
	old_text_exists: old_text /= Void
	new_text_exists: new_text /= Void
	job_name_exists: job_name /= Void
	valid_type: change_type >= Change_replace and change_type <= Change_delete

end
