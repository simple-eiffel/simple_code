note
	description: "[
		SQLite audit storage for Claude-in-the-Loop artifacts.

		Stores all prompts, responses, and generated code for:
		- Audit trail across sessions
		- Reference for refinement cycles
		- Analytics on generation patterns
		- Recovery if files are lost
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_AUDIT_DB

create
	make

feature {NONE} -- Initialization

	make (a_db_path: STRING)
			-- Create or open audit database at `a_db_path'.
		require
			path_not_empty: not a_db_path.is_empty
		do
			db_path := a_db_path
			create last_error.make_empty
			open_database
			if is_open then
				ensure_schema
			end
		ensure
			path_set: db_path = a_db_path
		end

feature -- Status

	is_open: BOOLEAN
			-- Is database connection open?

	has_error: BOOLEAN
			-- Did last operation fail?
		do
			Result := not last_error.is_empty
		end

feature -- Access

	db_path: STRING
			-- Path to SQLite database file

	last_error: STRING_32
			-- Error message from last failed operation

feature -- Artifact Storage

	store_prompt (a_session: STRING_32; a_iteration: INTEGER; a_prompt_type: STRING_32; a_class_name: detachable STRING_32; a_content: STRING_32)
			-- Store a prompt artifact.
		require
			is_open: is_open
			session_not_empty: not a_session.is_empty
			content_not_empty: not a_content.is_empty
		do
			store_artifact (a_session, a_iteration, "prompt", a_prompt_type, a_class_name, a_content, Void)
		end

	store_response (a_session: STRING_32; a_iteration: INTEGER; a_response_type: STRING_32; a_class_name: detachable STRING_32; a_content: STRING_32; a_code: detachable STRING_32)
			-- Store a response artifact.
		require
			is_open: is_open
			session_not_empty: not a_session.is_empty
			content_not_empty: not a_content.is_empty
		do
			store_artifact (a_session, a_iteration, "response", a_response_type, a_class_name, a_content, a_code)
		end

	store_generated_code (a_session: STRING_32; a_iteration: INTEGER; a_class_name: STRING_32; a_code: STRING_32)
			-- Store generated class code.
		require
			is_open: is_open
			session_not_empty: not a_session.is_empty
			class_not_empty: not a_class_name.is_empty
			code_not_empty: not a_code.is_empty
		do
			store_artifact (a_session, a_iteration, "class_code", "generated", a_class_name, Void, a_code)
		end

	store_test_code (a_session: STRING_32; a_iteration: INTEGER; a_test_class: STRING_32; a_target_class: STRING_32; a_code: STRING_32)
			-- Store generated test class code.
		require
			is_open: is_open
			session_not_empty: not a_session.is_empty
			test_class_not_empty: not a_test_class.is_empty
			code_not_empty: not a_code.is_empty
		local
			l_content: STRING_32
		do
			create l_content.make (50)
			l_content.append ("target_class: ")
			l_content.append (a_target_class)
			store_artifact (a_session, a_iteration, "test_code", "generated", a_test_class, l_content, a_code)
		end

	store_refinement (a_session: STRING_32; a_iteration: INTEGER; a_class_name: STRING_32; a_issues: STRING_32; a_code: STRING_32)
			-- Store refinement artifact.
		require
			is_open: is_open
			session_not_empty: not a_session.is_empty
			class_not_empty: not a_class_name.is_empty
		do
			store_artifact (a_session, a_iteration, "refinement", "fix", a_class_name, a_issues, a_code)
		end

	store_compile_result (a_session: STRING_32; a_iteration: INTEGER; a_success: BOOLEAN; a_output: STRING_32)
			-- Store compilation result.
		require
			is_open: is_open
			session_not_empty: not a_session.is_empty
		local
			l_type: STRING_32
		do
			if a_success then
				l_type := "success"
			else
				l_type := "failure"
			end
			store_artifact (a_session, a_iteration, "compile", l_type, Void, a_output, Void)
		end

feature -- Queries

	get_session_history (a_session: STRING_32): ARRAYED_LIST [TUPLE [id: INTEGER; artifact_type: STRING_32; subtype: STRING_32; class_name: detachable STRING_32; created_at: STRING_32]]
			-- Get all artifacts for a session in chronological order.
		require
			is_open: is_open
			session_not_empty: not a_session.is_empty
		local
			l_result: SIMPLE_SQL_RESULT
			l_row: SIMPLE_SQL_ROW
			l_class_name: detachable STRING_32
		do
			create Result.make (20)
			if attached db as l_db then
				l_result := l_db.query_with_args (
					"SELECT id, artifact_type, subtype, class_name, created_at FROM artifacts WHERE session_name = ? ORDER BY created_at ASC",
					<<a_session.to_string_8>>
				)
				across l_result.rows as ic loop
					l_row := ic
					if l_row.is_null ("class_name") then
						l_class_name := Void
					else
						l_class_name := l_row.string_value ("class_name")
					end
					Result.extend ([
						l_row.integer_value ("id"),
						l_row.string_value ("artifact_type"),
						l_row.string_value ("subtype"),
						l_class_name,
						l_row.string_value ("created_at")
					])
				end
			end
		end

	get_class_history (a_session: STRING_32; a_class_name: STRING_32): ARRAYED_LIST [TUPLE [id: INTEGER; artifact_type: STRING_32; iteration: INTEGER; created_at: STRING_32]]
			-- Get all artifacts for a specific class.
		require
			is_open: is_open
			session_not_empty: not a_session.is_empty
			class_not_empty: not a_class_name.is_empty
		local
			l_result: SIMPLE_SQL_RESULT
			l_row: SIMPLE_SQL_ROW
		do
			create Result.make (10)
			if attached db as l_db then
				l_result := l_db.query_with_args (
					"SELECT id, artifact_type, iteration, created_at FROM artifacts WHERE session_name = ? AND class_name = ? ORDER BY created_at ASC",
					<<a_session.to_string_8, a_class_name.to_string_8>>
				)
				across l_result.rows as ic loop
					l_row := ic
					Result.extend ([
						l_row.integer_value ("id"),
						l_row.string_value ("artifact_type"),
						l_row.integer_value ("iteration"),
						l_row.string_value ("created_at")
					])
				end
			end
		end

	get_artifact_content (a_id: INTEGER): detachable STRING_32
			-- Get content of artifact by ID.
		require
			is_open: is_open
			valid_id: a_id > 0
		local
			l_result: SIMPLE_SQL_RESULT
		do
			if attached db as l_db then
				l_result := l_db.query_with_args ("SELECT content FROM artifacts WHERE id = ?", <<a_id>>)
				if not l_result.is_empty then
					if not l_result.first.is_null ("content") then
						Result := l_result.first.string_value ("content")
					end
				end
			end
		end

	get_artifact_code (a_id: INTEGER): detachable STRING_32
			-- Get code of artifact by ID.
		require
			is_open: is_open
			valid_id: a_id > 0
		local
			l_result: SIMPLE_SQL_RESULT
		do
			if attached db as l_db then
				l_result := l_db.query_with_args ("SELECT code FROM artifacts WHERE id = ?", <<a_id>>)
				if not l_result.is_empty then
					if not l_result.first.is_null ("code") then
						Result := l_result.first.string_value ("code")
					end
				end
			end
		end

	get_latest_code (a_session: STRING_32; a_class_name: STRING_32): detachable STRING_32
			-- Get most recent code for a class.
		require
			is_open: is_open
			session_not_empty: not a_session.is_empty
			class_not_empty: not a_class_name.is_empty
		local
			l_result: SIMPLE_SQL_RESULT
		do
			if attached db as l_db then
				l_result := l_db.query_with_args (
					"SELECT code FROM artifacts WHERE session_name = ? AND class_name = ? AND code IS NOT NULL ORDER BY created_at DESC LIMIT 1",
					<<a_session.to_string_8, a_class_name.to_string_8>>
				)
				if not l_result.is_empty then
					Result := l_result.first.string_value ("code")
				end
			end
		end

	get_all_sessions: ARRAYED_LIST [STRING_32]
			-- Get list of all session names.
		require
			is_open: is_open
		local
			l_result: SIMPLE_SQL_RESULT
		do
			create Result.make (10)
			if attached db as l_db then
				l_result := l_db.query ("SELECT DISTINCT session_name FROM artifacts ORDER BY session_name")
				across l_result.rows as ic loop
					Result.extend (ic.string_value ("session_name"))
				end
			end
		end

	get_session_stats (a_session: STRING_32): TUPLE [prompts: INTEGER; responses: INTEGER; classes: INTEGER; refinements: INTEGER; compiles: INTEGER]
			-- Get statistics for a session.
		require
			is_open: is_open
			session_not_empty: not a_session.is_empty
		local
			l_result: SIMPLE_SQL_RESULT
			l_row: SIMPLE_SQL_ROW
			l_prompts, l_responses, l_classes, l_refinements, l_compiles: INTEGER
			l_type: STRING_32
		do
			if attached db as l_db then
				l_result := l_db.query_with_args (
					"SELECT artifact_type, COUNT(*) as cnt FROM artifacts WHERE session_name = ? GROUP BY artifact_type",
					<<a_session.to_string_8>>
				)
				across l_result.rows as ic loop
					l_row := ic
					l_type := l_row.string_value ("artifact_type")
					if l_type.same_string ("prompt") then
						l_prompts := l_row.integer_value ("cnt")
					elseif l_type.same_string ("response") then
						l_responses := l_row.integer_value ("cnt")
					elseif l_type.same_string ("class_code") then
						l_classes := l_row.integer_value ("cnt")
					elseif l_type.same_string ("refinement") then
						l_refinements := l_row.integer_value ("cnt")
					elseif l_type.same_string ("compile") then
						l_compiles := l_row.integer_value ("cnt")
					end
				end
			end
			Result := [l_prompts, l_responses, l_classes, l_refinements, l_compiles]
		end

feature -- Operations

	reset_all
			-- Delete all artifacts from database (full reset).
		require
			is_open: is_open
		do
			last_error.wipe_out
			if attached db as l_db then
				l_db.execute ("DELETE FROM artifacts")
			end
		end

	reset_session (a_session: STRING_32)
			-- Delete all artifacts for a specific session.
		require
			is_open: is_open
			session_not_empty: not a_session.is_empty
		do
			last_error.wipe_out
			if attached db as l_db then
				l_db.execute_with_args ("DELETE FROM artifacts WHERE session_name = ?", <<a_session.to_string_8>>)
			end
		end

	vacuum
			-- Reclaim disk space after deletions.
		require
			is_open: is_open
		do
			if attached db as l_db then
				l_db.execute ("VACUUM")
			end
		end

	close
			-- Close database connection.
		do
			if attached db as l_db then
				l_db.close
			end
			db := Void
			is_open := False
		ensure
			not_open: not is_open
		end

feature {NONE} -- Implementation

	db: detachable SIMPLE_SQL_DATABASE
			-- Database connection

	open_database
			-- Open or create the database.
		local
			l_db: SIMPLE_SQL_DATABASE
		do
			last_error.wipe_out
			create l_db.make (db_path)
			if l_db.is_open then
				db := l_db
				is_open := True
			else
				last_error := "Failed to open database: " + db_path.to_string_32
			end
		end

	ensure_schema
			-- Create tables if they don't exist.
		do
			if attached db as l_db then
				l_db.execute ("[
					CREATE TABLE IF NOT EXISTS artifacts (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						session_name TEXT NOT NULL,
						iteration INTEGER DEFAULT 0,
						artifact_type TEXT NOT NULL,
						subtype TEXT,
						class_name TEXT,
						content TEXT,
						code TEXT,
						created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
					)
				]")

				-- Create indexes for common queries
				l_db.execute ("CREATE INDEX IF NOT EXISTS idx_session ON artifacts(session_name)")
				l_db.execute ("CREATE INDEX IF NOT EXISTS idx_class ON artifacts(session_name, class_name)")
				l_db.execute ("CREATE INDEX IF NOT EXISTS idx_type ON artifacts(artifact_type)")
			end
		end

	store_artifact (a_session: STRING_32; a_iteration: INTEGER; a_type, a_subtype: STRING_32; a_class_name, a_content, a_code: detachable STRING_32)
			-- Store an artifact in the database.
		require
			is_open: is_open
			session_not_empty: not a_session.is_empty
			type_not_empty: not a_type.is_empty
		local
			l_class_arg, l_content_arg, l_code_arg: detachable ANY
		do
			last_error.wipe_out
			if attached db as l_db then
				-- Convert detachable strings to detachable ANY for null handling
				if attached a_class_name as l_cn then
					l_class_arg := l_cn.to_string_8
				end
				if attached a_content as l_ct then
					l_content_arg := l_ct.to_string_8
				end
				if attached a_code as l_cd then
					l_code_arg := l_cd.to_string_8
				end

				l_db.execute_with_args (
					"INSERT INTO artifacts (session_name, iteration, artifact_type, subtype, class_name, content, code) VALUES (?, ?, ?, ?, ?, ?, ?)",
					<<a_session.to_string_8, a_iteration, a_type.to_string_8, a_subtype.to_string_8, l_class_arg, l_content_arg, l_code_arg>>
				)
			end
		end

invariant
	db_path_not_empty: not db_path.is_empty
	last_error_exists: last_error /= Void

end
