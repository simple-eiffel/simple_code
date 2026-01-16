note
	description: "[
		Merges changes from multiple parallel jobs into a single class text.

		Handles conflict resolution when multiple jobs modify the same text:
		- Higher priority job wins
		- Logs conflicts for review

		Usage:
			create merger.make
			result := merger.merge (original_text, all_changes)
			if merger.has_conflicts then
				print (merger.conflict_log)
			end
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_CHANGE_MERGER

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize merger
		do
			create conflicts.make (5)
			create merge_log.make (20)
		ensure
			conflicts_empty: conflicts.is_empty
			log_empty: merge_log.is_empty
		end

feature -- Access

	conflicts: ARRAYED_LIST [TUPLE [change1, change2: SCG_JOB_CHANGE; winner: STRING_32]]
			-- Detected conflicts and their resolutions

	merge_log: ARRAYED_LIST [STRING_32]
			-- Log of merge operations

feature -- Status

	has_conflicts: BOOLEAN
			-- Were any conflicts detected during last merge?
		do
			Result := not conflicts.is_empty
		end

	changes_applied: INTEGER
			-- Number of changes successfully applied in last merge

feature -- Operations

	merge (a_original: STRING_32; a_changes: LIST [SCG_JOB_CHANGE]): STRING_32
			-- Merge all changes into original text.
			-- Conflicts resolved by priority (higher wins).
		require
			original_not_void: a_original /= Void
			changes_not_void: a_changes /= Void
		local
			l_sorted_changes: ARRAYED_LIST [SCG_JOB_CHANGE]
			l_filtered_changes: ARRAYED_LIST [SCG_JOB_CHANGE]
		do
			-- Reset state
			conflicts.wipe_out
			merge_log.wipe_out
			changes_applied := 0

			Result := a_original.twin

			if a_changes.is_empty then
				log_entry ("No changes to apply")
			else
				-- Sort by priority (descending) so higher priority applied first
				l_sorted_changes := sort_by_priority (a_changes)

				-- Filter out conflicts (keep higher priority only)
				l_filtered_changes := resolve_conflicts (l_sorted_changes)

				-- Apply remaining changes
				Result := apply_changes (Result, l_filtered_changes)

				log_entry ("Applied " + changes_applied.out + " changes, " + conflicts.count.out + " conflicts resolved")
			end
		ensure
			result_not_void: Result /= Void
		end

	reset
			-- Clear state for next merge
		do
			conflicts.wipe_out
			merge_log.wipe_out
			changes_applied := 0
		ensure
			conflicts_empty: conflicts.is_empty
			log_empty: merge_log.is_empty
			no_changes: changes_applied = 0
		end

feature {NONE} -- Implementation

	sort_by_priority (a_changes: LIST [SCG_JOB_CHANGE]): ARRAYED_LIST [SCG_JOB_CHANGE]
			-- Return changes sorted by priority (descending)
		local
			l_temp: detachable SCG_JOB_CHANGE
			i, j: INTEGER
		do
			create Result.make_from_iterable (a_changes)

			-- Simple bubble sort (change count is small)
			from i := 1 until i >= Result.count loop
				from j := 1 until j > Result.count - i loop
					if Result [j].priority < Result [j + 1].priority then
						l_temp := Result [j]
						Result [j] := Result [j + 1]
						check attached l_temp as lt then
							Result [j + 1] := lt
						end
					end
					j := j + 1
				end
				i := i + 1
			end
		end

	resolve_conflicts (a_sorted_changes: ARRAYED_LIST [SCG_JOB_CHANGE]): ARRAYED_LIST [SCG_JOB_CHANGE]
			-- Filter out conflicting changes, keeping higher priority ones.
			-- Record conflicts for logging.
		local
			l_dominated: ARRAYED_LIST [INTEGER]
			i, j: INTEGER
		do
			create Result.make (a_sorted_changes.count)
			create l_dominated.make (10)

			-- Mark dominated changes (lower priority conflicts)
			from i := 1 until i > a_sorted_changes.count loop
				if not l_dominated.has (i) then
					from j := i + 1 until j > a_sorted_changes.count loop
						if not l_dominated.has (j) then
							if a_sorted_changes [i].conflicts_with (a_sorted_changes [j]) then
								-- i has higher priority (sorted), so j is dominated
								l_dominated.extend (j)
								conflicts.extend ([a_sorted_changes [j], a_sorted_changes [i], a_sorted_changes [i].job_name])
								log_entry ("Conflict: " + a_sorted_changes [j].job_name + " vs " + a_sorted_changes [i].job_name + " -> " + a_sorted_changes [i].job_name + " wins")
							end
						end
						j := j + 1
					end
				end
				i := i + 1
			end

			-- Collect non-dominated changes
			from i := 1 until i > a_sorted_changes.count loop
				if not l_dominated.has (i) then
					Result.extend (a_sorted_changes [i])
				end
				i := i + 1
			end
		end

	apply_changes (a_text: STRING_32; a_changes: LIST [SCG_JOB_CHANGE]): STRING_32
			-- Apply all changes to text
		local
			l_change: SCG_JOB_CHANGE
			l_pos: INTEGER
		do
			Result := a_text.twin

			across a_changes as ic loop
				l_change := ic
				if l_change.is_replace then
					l_pos := Result.substring_index (l_change.old_text, 1)
					if l_pos > 0 then
						Result.replace_substring (l_change.new_text, l_pos, l_pos + l_change.old_text.count - 1)
						changes_applied := changes_applied + 1
						log_entry ("Applied REPLACE from " + l_change.job_name)
					else
						log_entry ("SKIP: old_text not found for " + l_change.job_name)
					end
				elseif l_change.is_delete then
					l_pos := Result.substring_index (l_change.old_text, 1)
					if l_pos > 0 then
						Result.remove_substring (l_pos, l_pos + l_change.old_text.count - 1)
						changes_applied := changes_applied + 1
						log_entry ("Applied DELETE from " + l_change.job_name)
					else
						log_entry ("SKIP: old_text not found for delete from " + l_change.job_name)
					end
				elseif l_change.is_insert then
					-- Insert at location (treat location as marker text to find)
					l_pos := Result.substring_index (l_change.location, 1)
					if l_pos > 0 then
						Result.insert_string (l_change.new_text, l_pos)
						changes_applied := changes_applied + 1
						log_entry ("Applied INSERT from " + l_change.job_name)
					else
						log_entry ("SKIP: insert location not found for " + l_change.job_name)
					end
				end
			end
		end

	log_entry (a_message: STRING_32)
			-- Add entry to merge log
		do
			merge_log.extend (a_message)
		end

feature -- Output

	conflict_log: STRING_32
			-- Human-readable conflict log
		do
			create Result.make (500)
			Result.append ("=== Merge Conflicts ===%N")
			across conflicts as ic loop
				Result.append ("  ")
				Result.append (ic.change1.job_name)
				Result.append (" vs ")
				Result.append (ic.change2.job_name)
				Result.append (" -> Winner: ")
				Result.append (ic.winner)
				Result.append ("%N")
			end
		end

	full_log: STRING_32
			-- Complete merge log
		do
			create Result.make (1000)
			across merge_log as ic loop
				Result.append (ic)
				Result.append ("%N")
			end
		end

invariant
	conflicts_exists: conflicts /= Void
	merge_log_exists: merge_log /= Void

end
