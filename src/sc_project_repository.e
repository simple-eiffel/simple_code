note
	description: "[
		SC_PROJECT_REPOSITORY - Repository for SC_PROJECT persistence.

		Provides CRUD operations for SC_PROJECT entities using SQLite.
		Extends SIMPLE_SQL_REPOSITORY with project-specific queries.

		Schema:
			projects (id, uuid, name, path, libraries_json,
			          is_generated, is_verified, verification_error,
			          created_at, updated_at, is_deleted, deleted_at)

		Usage:
			create db.make ("simple_code.db")
			create repo.make (db)
			repo.create_table

			-- Save project
			new_id := repo.insert (project)

			-- Find by various criteria
			found := repo.find_by_uuid ("...")
			found := repo.find_by_path ("...")
			all_active := repo.find_active
	]"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	SC_PROJECT_REPOSITORY

inherit
	SIMPLE_SQL_REPOSITORY [SC_PROJECT]

create
	make

feature -- Constants

	table_name: STRING_8 = "projects"
			-- <Precursor>

	primary_key_column: STRING_8 = "id"
			-- <Precursor>

feature -- Schema

	create_table
			-- Create the projects table if it doesn't exist.
		do
			database.execute ("[
				CREATE TABLE IF NOT EXISTS projects (
					id INTEGER PRIMARY KEY AUTOINCREMENT,
					uuid TEXT NOT NULL UNIQUE,
					name TEXT NOT NULL,
					path TEXT NOT NULL,
					libraries_json TEXT,
					is_generated INTEGER NOT NULL DEFAULT 0,
					is_verified INTEGER NOT NULL DEFAULT 0,
					verification_error TEXT,
					created_at TEXT NOT NULL,
					updated_at TEXT NOT NULL,
					is_deleted INTEGER NOT NULL DEFAULT 0,
					deleted_at TEXT
				)
			]")
			-- Create indexes for common queries
			database.execute ("CREATE INDEX IF NOT EXISTS idx_projects_uuid ON projects(uuid)")
			database.execute ("CREATE INDEX IF NOT EXISTS idx_projects_path ON projects(path)")
			database.execute ("CREATE INDEX IF NOT EXISTS idx_projects_deleted ON projects(is_deleted)")
		ensure
			table_exists: database.schema.table_exists (table_name)
		end

	drop_table
			-- Drop the projects table if it exists.
		do
			database.execute ("DROP TABLE IF EXISTS projects")
		ensure
			table_gone: not database.schema.table_exists (table_name)
		end

feature -- Query: By UUID

	find_by_uuid (a_uuid: STRING): detachable SC_PROJECT
			-- Find project by UUID, or Void if not found.
		require
			uuid_not_empty: not a_uuid.is_empty
		do
			Result := find_first_where ("uuid = '" + escape_string (a_uuid) + "'")
		end

feature -- Query: By Path

	find_by_path (a_path: STRING): detachable SC_PROJECT
			-- Find project by path, or Void if not found.
		require
			path_not_empty: not a_path.is_empty
		do
			Result := find_first_where ("path = '" + escape_string (a_path) + "'")
		end

	find_by_name (a_name: STRING): ARRAYED_LIST [SC_PROJECT]
			-- Find all projects with given name.
		require
			name_not_empty: not a_name.is_empty
		do
			Result := find_where ("name = '" + escape_string (a_name) + "'")
		ensure
			result_attached: Result /= Void
		end

feature -- Query: Active/Deleted

	find_active: ARRAYED_LIST [SC_PROJECT]
			-- Find all non-deleted projects.
		do
			Result := find_where_ordered ("is_deleted = 0", "name ASC")
		ensure
			result_attached: Result /= Void
			all_active: across Result as p all not p.is_deleted end
		end

	find_deleted: ARRAYED_LIST [SC_PROJECT]
			-- Find all soft-deleted projects.
		do
			Result := find_where_ordered ("is_deleted = 1", "deleted_at DESC")
		ensure
			result_attached: Result /= Void
			all_deleted: across Result as p all p.is_deleted end
		end

	count_active: INTEGER
			-- Number of active (non-deleted) projects.
		do
			Result := count_where ("is_deleted = 0")
		ensure
			non_negative: Result >= 0
		end

	count_deleted: INTEGER
			-- Number of soft-deleted projects.
		do
			Result := count_where ("is_deleted = 1")
		ensure
			non_negative: Result >= 0
		end

feature -- Query: Status

	find_verified: ARRAYED_LIST [SC_PROJECT]
			-- Find all verified projects.
		do
			Result := find_where ("is_verified = 1 AND is_deleted = 0")
		ensure
			result_attached: Result /= Void
			all_verified: across Result as p all p.is_verified end
		end

	find_unverified: ARRAYED_LIST [SC_PROJECT]
			-- Find all generated but unverified projects.
		do
			Result := find_where ("is_generated = 1 AND is_verified = 0 AND is_deleted = 0")
		ensure
			result_attached: Result /= Void
		end

feature -- Command: Soft Delete

	mark_deleted (a_project: SC_PROJECT): BOOLEAN
			-- Mark project as soft-deleted.
		require
			project_persisted: a_project.is_persisted
		local
			l_columns: HASH_TABLE [detachable ANY, STRING_8]
			l_time: SIMPLE_DATE_TIME
		do
			create l_columns.make (3)
			l_columns.put (1, "is_deleted")
			create l_time.make_now
			l_columns.put (l_time.to_iso8601, "deleted_at")
			l_columns.put (l_time.to_iso8601, "updated_at")
			Result := update_where (l_columns, "id = " + a_project.id.out) = 1
			if Result then
				a_project.mark_deleted
			end
		ensure
			marked_if_success: Result implies a_project.is_deleted
		end

	unmark_deleted (a_project: SC_PROJECT): BOOLEAN
			-- Remove soft-delete flag from project.
		require
			project_persisted: a_project.is_persisted
			project_deleted: a_project.is_deleted
		local
			l_columns: HASH_TABLE [detachable ANY, STRING_8]
			l_time: SIMPLE_DATE_TIME
		do
			create l_columns.make (3)
			l_columns.put (0, "is_deleted")
			l_columns.put (Void, "deleted_at")
			create l_time.make_now
			l_columns.put (l_time.to_iso8601, "updated_at")
			Result := update_where (l_columns, "id = " + a_project.id.out) = 1
			if Result then
				a_project.unmark_deleted
			end
		ensure
			unmarked_if_success: Result implies not a_project.is_deleted
		end

	purge_deleted: INTEGER
			-- Permanently delete all soft-deleted projects from database.
			-- Returns number of records purged.
		do
			Result := delete_where ("is_deleted = 1")
		ensure
			non_negative: Result >= 0
			none_deleted: count_deleted = 0
		end

feature {NONE} -- Implementation

	row_to_entity (a_row: SIMPLE_SQL_ROW): SC_PROJECT
			-- <Precursor>
		do
			create Result.make_from_row (a_row)
		end

	entity_to_columns (a_entity: SC_PROJECT): HASH_TABLE [detachable ANY, STRING_8]
			-- <Precursor>
		do
			create Result.make (11)
			Result.put (a_entity.uuid, "uuid")
			Result.put (a_entity.name, "name")
			Result.put (a_entity.path, "path")
			Result.put (a_entity.libraries_as_json, "libraries_json")
			Result.put (boolean_to_int (a_entity.is_generated), "is_generated")
			Result.put (boolean_to_int (a_entity.is_verified), "is_verified")
			Result.put (a_entity.verification_error, "verification_error")
			Result.put (a_entity.created_at, "created_at")
			Result.put (a_entity.updated_at, "updated_at")
			Result.put (boolean_to_int (a_entity.is_deleted), "is_deleted")
			Result.put (a_entity.deleted_at, "deleted_at")
		end

	entity_id (a_entity: SC_PROJECT): INTEGER_64
			-- <Precursor>
		do
			Result := a_entity.id
		end

	boolean_to_int (a_value: BOOLEAN): INTEGER
			-- Convert boolean to SQLite integer (0/1).
		do
			if a_value then
				Result := 1
			else
				Result := 0
			end
		ensure
			correct: (a_value and Result = 1) or (not a_value and Result = 0)
		end

	escape_string (a_str: STRING): STRING
			-- Escape single quotes for SQL.
		do
			Result := a_str.twin
			Result.replace_substring_all ("'", "''")
		end

end
