note
	description: "[
		Git History Integration Helper for simple_codegen CLI.

		Provides Git operations when the project is under version control:
		- Commit history queries
		- Diff generation for context
		- Branch information
		- Change tracking between sessions

		Uses simple_process for git command execution.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_GIT_HELPER

create
	make

feature {NONE} -- Initialization

	make (a_repo_path: STRING_32)
			-- Initialize with repository path.
		require
			path_not_empty: not a_repo_path.is_empty
		do
			repo_path := a_repo_path
			create last_error.make_empty
			create process.make
		ensure
			path_set: repo_path = a_repo_path
		end

feature -- Access

	repo_path: STRING_32
			-- Path to git repository

	last_error: STRING_32
			-- Last error message

	process: SIMPLE_PROCESS
			-- Process executor

feature -- Status

	is_git_repo: BOOLEAN
			-- Is the path a git repository?
		do
			process.run_in_directory ("git rev-parse --is-inside-work-tree", repo_path.to_string_8)
			Result := process.last_exit_code = 0 and then
			          attached process.last_output as l_out and then
			          l_out.has_substring ("true")
		end

	current_branch: STRING_32
			-- Get current branch name.
		require
			is_repo: is_git_repo
		do
			process.run_in_directory ("git branch --show-current", repo_path.to_string_8)
			if process.last_exit_code = 0 and then attached process.last_output as l_out then
				create Result.make_from_string (l_out)
				Result.right_adjust
				Result.left_adjust
			else
				create Result.make_from_string ("unknown")
			end
		end

	has_uncommitted_changes: BOOLEAN
			-- Are there uncommitted changes?
		require
			is_repo: is_git_repo
		do
			process.run_in_directory ("git status --porcelain", repo_path.to_string_8)
			Result := process.last_exit_code = 0 and then
			          attached process.last_output as l_out and then
			          not l_out.is_empty
		end

	uncommitted_files: ARRAYED_LIST [STRING_32]
			-- List of uncommitted file paths.
		require
			is_repo: is_git_repo
		local
			l_lines: LIST [STRING_32]
			l_line: STRING_32
		do
			create Result.make (10)
			process.run_in_directory ("git status --porcelain", repo_path.to_string_8)
			if process.last_exit_code = 0 and then attached process.last_output as l_out and then not l_out.is_empty then
				l_lines := l_out.split ('%N')
				across l_lines as ic loop
					l_line := ic.twin
					l_line.left_adjust
					if l_line.count > 3 then
						Result.extend (l_line.substring (4, l_line.count))
					end
				end
			end
		end

feature -- History

	recent_commits (a_count: INTEGER): ARRAYED_LIST [TUPLE [hash: STRING_32; subject: STRING_32; author: STRING_32; date: STRING_32]]
			-- Get recent commit information.
		require
			is_repo: is_git_repo
			count_positive: a_count > 0
		local
			l_cmd: STRING
			l_lines: LIST [STRING_32]
			l_parts: LIST [STRING_32]
		do
			create Result.make (a_count)
			create l_cmd.make (100)
			l_cmd.append ("git log -")
			l_cmd.append_integer (a_count)
			l_cmd.append (" --pretty=format:%%H|%%s|%%an|%%ad --date=short")

			process.run_in_directory (l_cmd, repo_path.to_string_8)
			if process.last_exit_code = 0 and then attached process.last_output as l_out and then not l_out.is_empty then
				l_lines := l_out.split ('%N')
				across l_lines as ic loop
					l_parts := ic.split ({CHARACTER_32} '|')
					if l_parts.count >= 4 then
						Result.extend ([l_parts.i_th (1), l_parts.i_th (2), l_parts.i_th (3), l_parts.i_th (4)])
					end
				end
			end
		end

	commits_for_file (a_file: STRING_32; a_count: INTEGER): ARRAYED_LIST [TUPLE [hash: STRING_32; subject: STRING_32; date: STRING_32]]
			-- Get commits that touched a specific file.
		require
			is_repo: is_git_repo
			file_not_empty: not a_file.is_empty
			count_positive: a_count > 0
		local
			l_cmd: STRING
			l_lines: LIST [STRING_32]
			l_parts: LIST [STRING_32]
		do
			create Result.make (a_count)
			create l_cmd.make (150)
			l_cmd.append ("git log -")
			l_cmd.append_integer (a_count)
			l_cmd.append (" --pretty=format:%%H|%%s|%%ad --date=short -- ")
			l_cmd.append (a_file.to_string_8)

			process.run_in_directory (l_cmd, repo_path.to_string_8)
			if process.last_exit_code = 0 and then attached process.last_output as l_out and then not l_out.is_empty then
				l_lines := l_out.split ('%N')
				across l_lines as ic loop
					l_parts := ic.split ({CHARACTER_32} '|')
					if l_parts.count >= 3 then
						Result.extend ([l_parts.i_th (1), l_parts.i_th (2), l_parts.i_th (3)])
					end
				end
			end
		end

	commit_message_style: STRING_32
			-- Analyze recent commits to determine message style.
		require
			is_repo: is_git_repo
		local
			l_commits: like recent_commits
			l_has_prefix: BOOLEAN
			l_has_colon: BOOLEAN
		do
			l_commits := recent_commits (10)
			create Result.make (200)
			Result.append ({STRING_32} "Commit Message Style Analysis:%N")

			across l_commits as ic loop
				if ic.subject.has (':') then
					l_has_colon := True
				end
				if ic.subject.count > 0 and then ic.subject.item (1).is_upper then
					l_has_prefix := True
				end
			end

			if l_has_colon then
				Result.append ({STRING_32} "- Uses prefix:message format (e.g., 'feat: add feature')%N")
			end
			if l_has_prefix then
				Result.append ({STRING_32} "- Starts with capital letter%N")
			end
			Result.append ({STRING_32} "- Recent subjects:%N")
			across l_commits as ic loop
				Result.append ({STRING_32} "  * ")
				Result.append (ic.subject)
				Result.append ({STRING_32} "%N")
			end
		end

feature -- Diff

	diff_unstaged: STRING_32
			-- Get diff of unstaged changes.
		require
			is_repo: is_git_repo
		do
			process.run_in_directory ("git diff", repo_path.to_string_8)
			if process.last_exit_code = 0 and then attached process.last_output as l_out then
				Result := l_out
			else
				create Result.make_empty
			end
		end

	diff_staged: STRING_32
			-- Get diff of staged changes.
		require
			is_repo: is_git_repo
		do
			process.run_in_directory ("git diff --cached", repo_path.to_string_8)
			if process.last_exit_code = 0 and then attached process.last_output as l_out then
				Result := l_out
			else
				create Result.make_empty
			end
		end

	diff_between_commits (a_from, a_to: STRING_32): STRING_32
			-- Get diff between two commits.
		require
			is_repo: is_git_repo
			from_not_empty: not a_from.is_empty
			to_not_empty: not a_to.is_empty
		local
			l_cmd: STRING
		do
			create l_cmd.make (100)
			l_cmd.append ("git diff ")
			l_cmd.append (a_from.to_string_8)
			l_cmd.append ("..")
			l_cmd.append (a_to.to_string_8)

			process.run_in_directory (l_cmd, repo_path.to_string_8)
			if process.last_exit_code = 0 and then attached process.last_output as l_out then
				Result := l_out
			else
				create Result.make_empty
			end
		end

	file_diff (a_file: STRING_32): STRING_32
			-- Get diff for a specific file.
		require
			is_repo: is_git_repo
			file_not_empty: not a_file.is_empty
		local
			l_cmd: STRING
		do
			create l_cmd.make (100)
			l_cmd.append ("git diff -- ")
			l_cmd.append (a_file.to_string_8)

			process.run_in_directory (l_cmd, repo_path.to_string_8)
			if process.last_exit_code = 0 and then attached process.last_output as l_out then
				Result := l_out
			else
				create Result.make_empty
			end
		end

feature -- Context Generation

	generate_change_context: STRING_32
			-- Generate context summary of recent changes for Claude prompts.
		require
			is_repo: is_git_repo
		local
			l_commits: like recent_commits
			l_files: like uncommitted_files
		do
			create Result.make (2000)
			Result.append ({STRING_32} "=== GIT CONTEXT ===%N%N")

			Result.append ({STRING_32} "Current branch: ")
			Result.append (current_branch)
			Result.append ({STRING_32} "%N%N")

			-- Recent commits
			Result.append ({STRING_32} "Recent commits:%N")
			l_commits := recent_commits (5)
			across l_commits as ic loop
				Result.append ({STRING_32} "  ")
				Result.append (ic.hash.substring (1, ic.hash.count.min (7)))
				Result.append ({STRING_32} " ")
				Result.append (ic.subject)
				Result.append ({STRING_32} " (")
				Result.append (ic.date)
				Result.append ({STRING_32} ")%N")
			end

			-- Uncommitted changes
			if has_uncommitted_changes then
				Result.append ({STRING_32} "%NUncommitted changes:%N")
				l_files := uncommitted_files
				across l_files as ic loop
					Result.append ({STRING_32} "  ")
					Result.append (ic)
					Result.append ({STRING_32} "%N")
				end
			else
				Result.append ({STRING_32} "%NNo uncommitted changes.%N")
			end
		end

	generate_file_history_context (a_file: STRING_32): STRING_32
			-- Generate context for a specific file's history.
		require
			is_repo: is_git_repo
			file_not_empty: not a_file.is_empty
		local
			l_commits: like commits_for_file
		do
			create Result.make (1000)
			Result.append ({STRING_32} "=== FILE HISTORY: ")
			Result.append (a_file)
			Result.append ({STRING_32} " ===%N%N")

			l_commits := commits_for_file (a_file, 10)
			if l_commits.is_empty then
				Result.append ({STRING_32} "No history found for this file.%N")
			else
				across l_commits as ic loop
					Result.append (ic.hash.substring (1, ic.hash.count.min (7)))
					Result.append ({STRING_32} " ")
					Result.append (ic.date)
					Result.append ({STRING_32} " ")
					Result.append (ic.subject)
					Result.append ({STRING_32} "%N")
				end
			end
		end

feature -- Prompt Templates

	git_history_prompt_template: STRING_32
			-- Prompt template for git history analysis.
		once
			create Result.make (1500)
			Result.append ({STRING_32} "=== GIT HISTORY ANALYSIS ===%N%N")
			Result.append ({STRING_32} "Analyze the git history context provided above to:%N")
			Result.append ({STRING_32} "1. Understand recent development activity%N")
			Result.append ({STRING_32} "2. Identify patterns in commits%N")
			Result.append ({STRING_32} "3. Suggest appropriate commit messages for new changes%N")
			Result.append ({STRING_32} "4. Identify related files that may need updates%N%N")
			Result.append ({STRING_32} "OUTPUT FORMAT:%N")
			Result.append ({STRING_32} "```json%N")
			Result.append ({STRING_32} "{%N")
			Result.append ({STRING_32} "  %"type%": %"git_analysis%",%N")
			Result.append ({STRING_32} "  %"recent_focus%": %"description of recent work%",%N")
			Result.append ({STRING_32} "  %"commit_style%": %"conventional|imperative|other%",%N")
			Result.append ({STRING_32} "  %"suggested_commit%": %"suggested commit message%",%N")
			Result.append ({STRING_32} "  %"related_files%": [%"file1.e%", %"file2.e%"],%N")
			Result.append ({STRING_32} "  %"notes%": %"additional observations%"%N")
			Result.append ({STRING_32} "}%N")
			Result.append ({STRING_32} "```%N")
		end

invariant
	repo_path_exists: repo_path /= Void
	process_exists: process /= Void

end
