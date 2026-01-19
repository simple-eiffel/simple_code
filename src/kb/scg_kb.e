note
	description: "[
		SCG_KB - Knowledge Base Accessor for simple_codegen

		Provides access to Eiffel knowledge for shaping code generation prompts.
		Uses a LOCAL copy of kb.db shipped with simple_codegen (not simple_kb).

		Database should be at: <exe_dir>/data/scg_kb.db

		Provides:
		- Class lookup: get class info, features, contracts
		- Feature lookup: get signatures, pre/post conditions
		- Pattern lookup: get design patterns for context
		- Example lookup: find similar code examples
		- Search: FTS5 full-text search across all content
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_KB

create
	make,
	make_with_path

feature {NONE} -- Initialization

	make
			-- Create with default database path (relative to executable).
		do
			db_path := default_db_path
			initialize_db
		end

	make_with_path (a_path: STRING)
			-- Create with specific database path.
		require
			path_not_empty: not a_path.is_empty
		do
			db_path := a_path
			initialize_db
		end

	initialize_db
			-- Open database connection and ensure project tracking tables.
		local
			l_file: RAW_FILE
		do
			-- Check if database file exists before trying to open
			create l_file.make_with_name (db_path)
			if not l_file.exists then
				has_error := True
				last_error := "KB database not found: " + db_path
			else
				create db.make (db_path)
				if not is_open then
					has_error := True
					last_error := "Cannot open KB database: " + db_path
				else
					ensure_project_tables
				end
			end
		end

	ensure_project_tables
			-- Create project tracking tables if not exist.
		require
			is_open: is_open
		do
			-- Projects table
			safe_db.execute ("[
				CREATE TABLE IF NOT EXISTS scg_projects (
					id INTEGER PRIMARY KEY,
					name TEXT UNIQUE NOT NULL,
					project_type TEXT NOT NULL,
					path TEXT NOT NULL,
					description TEXT,
					simple_libs TEXT,
					created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
					last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP
				)
			]")

			-- Project classes table (tracks generated classes)
			safe_db.execute ("[
				CREATE TABLE IF NOT EXISTS scg_project_classes (
					id INTEGER PRIMARY KEY,
					project_id INTEGER REFERENCES scg_projects(id),
					class_name TEXT NOT NULL,
					file_path TEXT,
					generation_iteration INTEGER DEFAULT 1,
					is_validated BOOLEAN DEFAULT 0,
					created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
					UNIQUE(project_id, class_name)
				)
			]")

			-- Project generations log (audit trail)
			safe_db.execute ("[
				CREATE TABLE IF NOT EXISTS scg_generations (
					id INTEGER PRIMARY KEY,
					project_id INTEGER REFERENCES scg_projects(id),
					class_name TEXT,
					action TEXT NOT NULL,
					prompt_hash TEXT,
					response_hash TEXT,
					success BOOLEAN,
					notes TEXT,
					created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
				)
			]")
		end

feature -- Access

	db_path: STRING
			-- Path to knowledge base database

	db: detachable SIMPLE_SQL_DATABASE
			-- Database connection (Void if file not found)

feature -- Status

	is_open: BOOLEAN
			-- Is database open?
		do
			Result := attached db as l_db and then l_db.is_open
		end

	has_error: BOOLEAN
			-- Did last operation fail?

	last_error: detachable STRING
			-- Error message from last failure

feature -- Class Queries

	find_class (a_name: STRING): detachable TUPLE [id: INTEGER; library: STRING; name: STRING; description: STRING; is_deferred: BOOLEAN]
			-- Find class by name (case insensitive).
		require
			is_open: is_open
		local
			l_result: SIMPLE_SQL_RESULT
		do
			l_result := safe_db.query_with_args (
				"SELECT id, library, name, description, is_deferred FROM classes WHERE UPPER(name) = ? LIMIT 1",
				<<a_name.as_upper>>
			)
			if not l_result.is_empty and then attached l_result.rows.first as row then
				Result := [
					row_int (row, 1),
					row_str (row, 2),
					row_str (row, 3),
					row_str (row, 4),
					row_int (row, 5) = 1
				]
			end
		end

	get_class_features (a_class_id: INTEGER): ARRAYED_LIST [TUPLE [name: STRING; kind: STRING; signature: STRING; preconditions: STRING; postconditions: STRING]]
			-- Get all features for a class.
		require
			is_open: is_open
			valid_id: a_class_id > 0
		local
			l_result: SIMPLE_SQL_RESULT
		do
			create Result.make (20)
			l_result := safe_db.query_with_args (
				"SELECT name, kind, signature, preconditions, postconditions FROM features WHERE class_id = ? ORDER BY kind, name",
				<<a_class_id>>
			)
			across l_result.rows as row loop
				Result.extend ([
					row_str (row, 1),
					row_str (row, 2),
					row_str (row, 3),
					row_str (row, 4),
					row_str (row, 5)
				])
			end
		end

	get_class_parents (a_class_id: INTEGER): ARRAYED_LIST [STRING]
			-- Get parent class names for a class.
		require
			is_open: is_open
			valid_id: a_class_id > 0
		local
			l_result: SIMPLE_SQL_RESULT
		do
			create Result.make (5)
			l_result := safe_db.query_with_args (
				"SELECT parent_name FROM class_parents WHERE class_id = ? ORDER BY parent_name",
				<<a_class_id>>
			)
			across l_result.rows as row loop
				Result.extend (row_str (row, 1))
			end
		end

feature -- Feature Queries

	find_feature (a_class_name, a_feature_name: STRING): detachable TUPLE [name: STRING; kind: STRING; signature: STRING; description: STRING; preconditions: STRING; postconditions: STRING]
			-- Find feature by class and feature name.
		require
			is_open: is_open
		local
			l_result: SIMPLE_SQL_RESULT
		do
			l_result := safe_db.query_with_args ("[
				SELECT f.name, f.kind, f.signature, f.description, f.preconditions, f.postconditions
				FROM features f
				JOIN classes c ON c.id = f.class_id
				WHERE UPPER(c.name) = ? AND UPPER(f.name) = ?
				LIMIT 1
			]", <<a_class_name.as_upper, a_feature_name.as_upper>>)
			if not l_result.is_empty and then attached l_result.rows.first as row then
				Result := [
					row_str (row, 1),
					row_str (row, 2),
					row_str (row, 3),
					row_str (row, 4),
					row_str (row, 5),
					row_str (row, 6)
				]
			end
		end

	search_features_by_name (a_pattern: STRING; a_limit: INTEGER): ARRAYED_LIST [TUPLE [class_name: STRING; feature_name: STRING; kind: STRING; signature: STRING]]
			-- Search features by name pattern (LIKE search).
		require
			is_open: is_open
			positive_limit: a_limit > 0
		local
			l_result: SIMPLE_SQL_RESULT
			l_like_pattern: STRING
		do
			create Result.make (a_limit)
			l_like_pattern := "%%" + a_pattern.as_upper + "%%"
			l_result := safe_db.query_with_args ("[
				SELECT c.name, f.name, f.kind, f.signature
				FROM features f
				JOIN classes c ON c.id = f.class_id
				WHERE UPPER(f.name) LIKE ?
				ORDER BY c.name, f.name
				LIMIT ?
			]", <<l_like_pattern, a_limit>>)
			across l_result.rows as row loop
				Result.extend ([
					row_str (row, 1),
					row_str (row, 2),
					row_str (row, 3),
					row_str (row, 4)
				])
			end
		end

feature -- Pattern Queries

	get_pattern (a_name: STRING): detachable TUPLE [name: STRING; description: STRING; code: STRING; when_to_use: STRING]
			-- Get design pattern by name.
		require
			is_open: is_open
		local
			l_result: SIMPLE_SQL_RESULT
			l_like_pattern: STRING
		do
			l_like_pattern := "%%" + a_name.as_upper + "%%"
			l_result := safe_db.query_with_args (
				"SELECT name, description, code, when_to_use FROM patterns WHERE UPPER(name) LIKE ? LIMIT 1",
				<<l_like_pattern>>
			)
			if not l_result.is_empty and then attached l_result.rows.first as row then
				Result := [
					row_str (row, 1),
					row_str (row, 2),
					row_str (row, 3),
					row_str (row, 4)
				]
			end
		end

	all_pattern_names: ARRAYED_LIST [STRING]
			-- Get all pattern names.
		require
			is_open: is_open
		local
			l_result: SIMPLE_SQL_RESULT
		do
			create Result.make (20)
			l_result := safe_db.query ("SELECT name FROM patterns ORDER BY name")
			across l_result.rows as row loop
				Result.extend (row_str (row, 1))
			end
		end

feature -- Example Queries

	search_examples (a_query: STRING; a_limit: INTEGER): ARRAYED_LIST [TUPLE [title: STRING; source: STRING; code: STRING; tier: STRING]]
			-- Search examples by title or tags.
		require
			is_open: is_open
			positive_limit: a_limit > 0
		local
			l_result: SIMPLE_SQL_RESULT
			l_pattern: STRING
		do
			create Result.make (a_limit)
			l_pattern := "%%" + a_query + "%%"
			l_result := safe_db.query_with_args (
				"SELECT title, source, code, tier FROM examples WHERE title LIKE ? OR tags LIKE ? ORDER BY tier, title LIMIT ?",
				<<l_pattern, l_pattern, a_limit>>
			)
			across l_result.rows as row loop
				Result.extend ([
					row_str (row, 1),
					row_str (row, 2),
					row_str (row, 3),
					row_str (row, 4)
				])
			end
		end

feature -- Error Code Queries

	get_error_info (a_code: STRING): detachable TUPLE [code: STRING; meaning: STRING; explanation: STRING; fixes: STRING]
			-- Get compiler error info by error code.
		require
			is_open: is_open
		local
			l_result: SIMPLE_SQL_RESULT
		do
			l_result := safe_db.query_with_args (
				"SELECT code, meaning, explanation, fixes FROM errors WHERE UPPER(code) = ? LIMIT 1",
				<<a_code.as_upper>>
			)
			if not l_result.is_empty and then attached l_result.rows.first as row then
				Result := [
					row_str (row, 1),
					row_str (row, 2),
					row_str (row, 3),
					row_str (row, 4)
				]
			end
		end

feature -- Library Queries

	get_library_info (a_name: STRING): detachable TUPLE [name: STRING; description: STRING; uuid: STRING; dependencies: STRING]
			-- Get library info by name.
		require
			is_open: is_open
		local
			l_result: SIMPLE_SQL_RESULT
		do
			l_result := safe_db.query_with_args (
				"SELECT name, description, uuid, dependencies FROM libraries WHERE UPPER(name) = ? LIMIT 1",
				<<a_name.as_upper>>
			)
			if not l_result.is_empty and then attached l_result.rows.first as row then
				Result := [
					row_str (row, 1),
					row_str (row, 2),
					row_str (row, 3),
					row_str (row, 4)
				]
			end
		end

	all_library_names: ARRAYED_LIST [STRING]
			-- Get all library names.
		require
			is_open: is_open
		local
			l_result: SIMPLE_SQL_RESULT
		do
			create Result.make (60)
			l_result := safe_db.query ("SELECT name FROM libraries ORDER BY name")
			across l_result.rows as row loop
				Result.extend (row_str (row, 1))
			end
		end

feature -- Full-Text Search

	search (a_query: STRING; a_limit: INTEGER): ARRAYED_LIST [TUPLE [content_type: STRING; title: STRING; body: STRING]]
			-- FTS5 full-text search across all content.
		require
			is_open: is_open
			positive_limit: a_limit > 0
		local
			l_result: SIMPLE_SQL_RESULT
			l_fts_query: STRING
		do
			create Result.make (a_limit)
			l_fts_query := format_fts_query (a_query)
			l_result := safe_db.query_with_args (
				"SELECT content_type, title, body FROM kb_search WHERE kb_search MATCH ? ORDER BY bm25(kb_search) LIMIT ?",
				<<l_fts_query, a_limit>>
			)
			across l_result.rows as row loop
				Result.extend ([
					row_str (row, 1),
					row_str (row, 2),
					row_str (row, 3)
				])
			end
		end

feature -- Statistics

	stats: TUPLE [classes: INTEGER; features: INTEGER; examples: INTEGER; patterns: INTEGER; libraries: INTEGER]
			-- Database statistics.
		require
			is_open: is_open
		do
			Result := [
				count_table ("classes"),
				count_table ("features"),
				count_table ("examples"),
				count_table ("patterns"),
				count_table ("libraries")
			]
		end

feature -- Prompt Enhancement

	enhance_prompt_with_class_context (a_prompt: STRING; a_class_name: STRING): STRING
			-- Enhance prompt with knowledge about a class.
		require
			is_open: is_open
		local
			l_class: like find_class
			l_features: like get_class_features
			l_parents: ARRAYED_LIST [STRING]
			l_first: BOOLEAN
		do
			create Result.make (a_prompt.count + 2000)
			Result.append (a_prompt)

			l_class := find_class (a_class_name)
			if attached l_class as cls then
				Result.append ("%N%N=== KB CONTEXT: " + a_class_name + " ===%N")
				Result.append ("Library: " + cls.library + "%N")
				Result.append ("Description: " + cls.description + "%N")

				l_parents := get_class_parents (cls.id)
				if not l_parents.is_empty then
					Result.append ("Inherits from: ")
					l_first := True
					across l_parents as ic_p loop
						if not l_first then Result.append (", ") end
						Result.append (ic_p)
						l_first := False
					end
					Result.append ("%N")
				end

				l_features := get_class_features (cls.id)
				if not l_features.is_empty then
					Result.append ("%NFeatures:%N")
					across l_features as ic_f loop
						Result.append ("  " + ic_f.name)
						if not ic_f.signature.is_empty then
							Result.append (": " + ic_f.signature)
						end
						Result.append (" [" + ic_f.kind + "]%N")
					end
				end
				Result.append ("=== END KB CONTEXT ===%N")
			end
		end

	enhance_prompt_with_pattern (a_prompt: STRING; a_pattern_name: STRING): STRING
			-- Enhance prompt with pattern example.
		require
			is_open: is_open
		local
			l_pattern: like get_pattern
		do
			create Result.make (a_prompt.count + 2000)
			Result.append (a_prompt)

			l_pattern := get_pattern (a_pattern_name)
			if attached l_pattern as p then
				Result.append ("%N%N=== KB PATTERN: " + p.name + " ===%N")
				Result.append ("Description: " + p.description + "%N")
				Result.append ("When to use: " + p.when_to_use + "%N")
				Result.append ("%NExample code:%N")
				Result.append (p.code)
				Result.append ("%N=== END KB PATTERN ===%N")
			end
		end

	get_relevant_examples (a_topic: STRING; a_limit: INTEGER): STRING
			-- Get example code snippets relevant to topic.
		require
			is_open: is_open
		local
			l_examples: like search_examples
		do
			create Result.make (2000)
			l_examples := search_examples (a_topic, a_limit)
			if not l_examples.is_empty then
				Result.append ("=== RELEVANT EXAMPLES ===%N")
				across l_examples as ic_ex loop
					Result.append ("%N--- " + ic_ex.title + " (" + ic_ex.tier + ") ---%N")
					Result.append (ic_ex.code)
					Result.append ("%N")
				end
				Result.append ("=== END EXAMPLES ===%N")
			end
		end

feature {NONE} -- Implementation

	default_db_path: STRING
			-- Default database path relative to executable.
		local
			l_env: EXECUTION_ENVIRONMENT
			l_path: PATH
		once
			create l_env
			-- Try to find db relative to executable
			if attached (create {ARGUMENTS_32}).command_name as cmd then
				create l_path.make_from_string (cmd)
				if attached l_path.parent as parent_dir then
					l_path := parent_dir.extended ("data").extended ("scg_kb.db")
					Result := l_path.out
				else
					Result := "data/scg_kb.db"
				end
			else
				Result := "data/scg_kb.db"
			end
		end

	format_fts_query (a_query: STRING): STRING
			-- Format query for FTS5 (add prefix wildcards).
		local
			l_words: LIST [STRING]
		do
			create Result.make (a_query.count + 20)
			l_words := a_query.split (' ')
			across l_words as ic_w loop
				ic_w.left_adjust
				ic_w.right_adjust
				if not ic_w.is_empty then
					if Result.count > 0 then
						Result.append (" AND ")
					end
					Result.append (ic_w)
					Result.append ("*")
				end
			end
			if Result.is_empty then
				Result.append (a_query + "*")
			end
		end

	safe_db: SIMPLE_SQL_DATABASE
			-- Return attached database (precondition: is_open).
		require
			is_open: is_open
		do
			check attached db as l_db then
				Result := l_db
			end
		end

	count_table (a_table: STRING): INTEGER
			-- Count rows in table.
		require
			is_open: is_open
		local
			l_result: SIMPLE_SQL_RESULT
		do
			l_result := safe_db.query ("SELECT COUNT(*) FROM " + a_table)
			if not l_result.is_empty and then attached l_result.rows.first as row then
				Result := row_int (row, 1)
			end
		end

	row_str (a_row: SIMPLE_SQL_ROW; a_index: INTEGER): STRING
			-- Get string value from row.
		do
			if attached a_row.item (a_index) as val then
				Result := val.out
			else
				Result := ""
			end
		end

	row_int (a_row: SIMPLE_SQL_ROW; a_index: INTEGER): INTEGER
			-- Get integer value from row.
		do
			if attached a_row.item (a_index) as val then
				Result := val.out.to_integer
			end
		end

feature -- Project Tracking

	register_project (a_name, a_type, a_path: STRING; a_description: detachable STRING; a_libs: detachable ARRAYED_LIST [STRING])
			-- Register a new project in the tracking database.
		require
			is_open: is_open
			name_valid: not a_name.is_empty
			type_valid: not a_type.is_empty
			path_valid: not a_path.is_empty
		local
			l_libs_json: STRING
			l_first: BOOLEAN
		do
			if attached a_libs as libs and then not libs.is_empty then
				create l_libs_json.make (100)
				l_libs_json.append ("[")
				l_first := True
				across libs as ic loop
					if not l_first then l_libs_json.append (",") end
					l_libs_json.append ("%"" + ic + "%"")
					l_first := False
				end
				l_libs_json.append ("]")
			else
				l_libs_json := "[]"
			end

			safe_db.execute_with_args ("[
				INSERT OR REPLACE INTO scg_projects (name, project_type, path, description, simple_libs)
				VALUES (?, ?, ?, ?, ?)
			]", <<a_name, a_type, a_path, a_description, l_libs_json>>)
		end

	get_project (a_name: STRING): detachable TUPLE [id: INTEGER; name: STRING; project_type: STRING; path: STRING; description: STRING; created_at: STRING]
			-- Get project by name.
		require
			is_open: is_open
		local
			l_result: SIMPLE_SQL_RESULT
		do
			l_result := safe_db.query_with_args (
				"SELECT id, name, project_type, path, description, created_at FROM scg_projects WHERE name = ?",
				<<a_name>>
			)
			if not l_result.is_empty and then attached l_result.rows.first as row then
				Result := [
					row_int (row, 1),
					row_str (row, 2),
					row_str (row, 3),
					row_str (row, 4),
					row_str (row, 5),
					row_str (row, 6)
				]
			end
		end

	list_projects: ARRAYED_LIST [TUPLE [name: STRING; project_type: STRING; path: STRING; created_at: STRING]]
			-- List all tracked projects.
		require
			is_open: is_open
		local
			l_result: SIMPLE_SQL_RESULT
		do
			create Result.make (20)
			l_result := safe_db.query ("SELECT name, project_type, path, created_at FROM scg_projects ORDER BY last_modified DESC")
			across l_result.rows as row loop
				Result.extend ([
					row_str (row, 1),
					row_str (row, 2),
					row_str (row, 3),
					row_str (row, 4)
				])
			end
		end

	register_project_class (a_project_name, a_class_name, a_file_path: STRING)
			-- Register a generated class for a project.
		require
			is_open: is_open
		local
			l_project_id: INTEGER
		do
			l_project_id := get_project_id (a_project_name)
			if l_project_id > 0 then
				safe_db.execute_with_args ("[
					INSERT OR REPLACE INTO scg_project_classes (project_id, class_name, file_path)
					VALUES (?, ?, ?)
				]", <<l_project_id, a_class_name, a_file_path>>)

				-- Update project last_modified
				safe_db.execute_with_args (
					"UPDATE scg_projects SET last_modified = CURRENT_TIMESTAMP WHERE id = ?",
					<<l_project_id>>
				)
			end
		end

	get_project_classes (a_project_name: STRING): ARRAYED_LIST [TUPLE [class_name: STRING; file_path: STRING; is_validated: BOOLEAN]]
			-- Get all classes for a project.
		require
			is_open: is_open
		local
			l_result: SIMPLE_SQL_RESULT
			l_project_id: INTEGER
		do
			create Result.make (10)
			l_project_id := get_project_id (a_project_name)
			if l_project_id > 0 then
				l_result := safe_db.query_with_args (
					"SELECT class_name, file_path, is_validated FROM scg_project_classes WHERE project_id = ? ORDER BY class_name",
					<<l_project_id>>
				)
				across l_result.rows as row loop
					Result.extend ([
						row_str (row, 1),
						row_str (row, 2),
						row_int (row, 3) = 1
					])
				end
			end
		end

	log_generation (a_project_name, a_class_name, a_action: STRING; a_success: BOOLEAN; a_notes: detachable STRING)
			-- Log a generation action for audit trail.
		require
			is_open: is_open
		local
			l_project_id: INTEGER
		do
			l_project_id := get_project_id (a_project_name)
			if l_project_id > 0 then
				safe_db.execute_with_args ("[
					INSERT INTO scg_generations (project_id, class_name, action, success, notes)
					VALUES (?, ?, ?, ?, ?)
				]", <<l_project_id, a_class_name, a_action, bool_to_int (a_success), a_notes>>)
			end
		end

	get_project_history (a_project_name: STRING; a_limit: INTEGER): ARRAYED_LIST [TUPLE [class_name: STRING; action: STRING; success: BOOLEAN; notes: STRING; created_at: STRING]]
			-- Get generation history for a project.
		require
			is_open: is_open
			positive_limit: a_limit > 0
		local
			l_result: SIMPLE_SQL_RESULT
			l_project_id: INTEGER
		do
			create Result.make (a_limit)
			l_project_id := get_project_id (a_project_name)
			if l_project_id > 0 then
				l_result := safe_db.query_with_args (
					"SELECT class_name, action, success, notes, created_at FROM scg_generations WHERE project_id = ? ORDER BY created_at DESC LIMIT ?",
					<<l_project_id, a_limit>>
				)
				across l_result.rows as row loop
					Result.extend ([
						row_str (row, 1),
						row_str (row, 2),
						row_int (row, 3) = 1,
						row_str (row, 4),
						row_str (row, 5)
					])
				end
			end
		end

	project_count: INTEGER
			-- Count of tracked projects.
		require
			is_open: is_open
		do
			Result := count_table ("scg_projects")
		end

feature {NONE} -- Project Tracking Helpers

	get_project_id (a_name: STRING): INTEGER
			-- Get project ID by name.
		local
			l_result: SIMPLE_SQL_RESULT
		do
			l_result := safe_db.query_with_args ("SELECT id FROM scg_projects WHERE name = ?", <<a_name>>)
			if not l_result.is_empty and then attached l_result.rows.first as row then
				Result := row_int (row, 1)
			end
		end

	bool_to_int (a_bool: BOOLEAN): INTEGER
			-- Convert boolean to SQLite integer.
		do
			if a_bool then Result := 1 end
		end

feature -- Cleanup

	close
			-- Close database connection.
		do
			if attached db as l_db and then l_db.is_open then
				l_db.close
			end
		end

end
