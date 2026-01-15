note
	description: "[
		SC_PROJECT_MANAGER - High-level coordinator for project lifecycle.

		Orchestrates project generation, persistence, and deletion.
		Handles both database operations and disk operations together.

		Usage:
			create manager.make ("simple_code_projects.db")

			-- Generate and persist a new project
			project := manager.generate_and_persist (path, "my_lib", libs)

			-- Find existing projects
			project := manager.find_by_path ("/path/to/project")
			all_projects := manager.all_projects

			-- Delete project (optionally from disk too)
			manager.delete_project (project, True)

			-- Cleanup soft-deleted records
			manager.cleanup_deleted_projects
	]"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	SC_PROJECT_MANAGER

create
	make,
	make_memory

feature {NONE} -- Initialization

	make (a_db_path: STRING)
			-- Create manager with file-based database.
		require
			path_not_empty: not a_db_path.is_empty
		do
			create database.make (a_db_path)
			create repository.make (database)
			repository.create_table
			db_path := a_db_path
		ensure
			database_open: database.is_open
			db_path_set: db_path.same_string (a_db_path)
		end

	make_memory
			-- Create manager with in-memory database (for testing).
		do
			create database.make_memory
			create repository.make (database)
			repository.create_table
			db_path := ":memory:"
		ensure
			database_open: database.is_open
		end

feature -- Access

	database: SIMPLE_SQL_DATABASE
			-- Database connection

	repository: SC_PROJECT_REPOSITORY
			-- Project repository

	db_path: STRING
			-- Path to database file (":memory:" for in-memory)

	last_error: detachable STRING
			-- Last error message, if any

feature -- Project Creation

	generate_and_persist (a_path: SIMPLE_PATH; a_name: STRING;
			a_libraries: ARRAYED_LIST [STRING]): detachable SC_PROJECT
			-- Generate a new project and persist it to database.
			-- Returns Void if generation or persistence fails.
		require
			name_not_empty: not a_name.is_empty
		local
			l_generator: SCG_PROJECT_GEN
			l_project: SC_PROJECT
			l_new_id: INTEGER_64
		do
			last_error := Void

			-- Generate the project
			create l_generator.make_with_name (a_path, a_name, a_libraries)

			if l_generator.is_generated then
				-- Create entity from generator
				create l_project.make_from_generator (l_generator)

				-- Persist to database
				l_new_id := repository.insert (l_project)
				if l_new_id > 0 then
					l_project.set_id (l_new_id)
					Result := l_project
				else
					last_error := "Failed to persist project to database"
				end
			else
				if attached l_generator.verification_error as err then
				last_error := "Project generation failed: " + err
			else
				last_error := "Project generation failed"
			end
			end
		ensure
			success_implies_persisted: attached Result implies Result.is_persisted
			failure_has_error: Result = Void implies attached last_error
		end

	persist_existing (a_generator: SCG_PROJECT_GEN): detachable SC_PROJECT
			-- Persist an already-generated project to database.
		require
			generator_completed: a_generator.is_generated
		local
			l_project: SC_PROJECT
			l_new_id: INTEGER_64
		do
			last_error := Void

			create l_project.make_from_generator (a_generator)
			l_new_id := repository.insert (l_project)

			if l_new_id > 0 then
				l_project.set_id (l_new_id)
				Result := l_project
			else
				last_error := "Failed to persist project to database"
			end
		ensure
			success_implies_persisted: attached Result implies Result.is_persisted
		end

feature -- Retrieval

	find_project (a_id: INTEGER_64): detachable SC_PROJECT
			-- Find project by database ID.
		require
			valid_id: a_id > 0
		do
			Result := repository.find_by_id (a_id)
		end

	find_by_uuid (a_uuid: STRING): detachable SC_PROJECT
			-- Find project by UUID.
		require
			uuid_not_empty: not a_uuid.is_empty
		do
			Result := repository.find_by_uuid (a_uuid)
		end

	find_by_path (a_path: STRING): detachable SC_PROJECT
			-- Find project by path.
		require
			path_not_empty: not a_path.is_empty
		do
			Result := repository.find_by_path (a_path)
		end

	all_projects: ARRAYED_LIST [SC_PROJECT]
			-- All active (non-deleted) projects.
		do
			Result := repository.find_active
		ensure
			result_attached: Result /= Void
		end

	all_deleted_projects: ARRAYED_LIST [SC_PROJECT]
			-- All soft-deleted projects.
		do
			Result := repository.find_deleted
		ensure
			result_attached: Result /= Void
		end

	project_count: INTEGER
			-- Number of active projects.
		do
			Result := repository.count_active
		ensure
			non_negative: Result >= 0
		end

feature -- Deletion

	delete_project (a_project: SC_PROJECT; a_remove_from_disk: BOOLEAN): BOOLEAN
			-- Soft-delete project in database.
			-- If `a_remove_from_disk' is True, also delete from disk.
		require
			project_persisted: a_project.is_persisted
		do
			last_error := Void

			-- Mark as deleted in database
			Result := repository.mark_deleted (a_project)

			if Result and a_remove_from_disk then
				-- Also remove from disk
				if not remove_project_from_disk (a_project) then
					last_error := "Project marked deleted but disk removal failed"
					-- Still return True since DB operation succeeded
				end
			end
		ensure
			marked_deleted_if_success: Result implies a_project.is_deleted
		end

	restore_project (a_project: SC_PROJECT): BOOLEAN
			-- Remove soft-delete flag from project.
		require
			project_persisted: a_project.is_persisted
			project_deleted: a_project.is_deleted
		do
			Result := repository.unmark_deleted (a_project)
		ensure
			restored_if_success: Result implies not a_project.is_deleted
		end

	cleanup_deleted_projects: INTEGER
			-- Permanently remove all soft-deleted projects from database.
			-- Returns number of records purged.
		do
			Result := repository.purge_deleted
		ensure
			non_negative: Result >= 0
		end

	hard_delete (a_project: SC_PROJECT; a_remove_from_disk: BOOLEAN): BOOLEAN
			-- Permanently delete project from database.
			-- If `a_remove_from_disk' is True, also delete from disk.
		require
			project_persisted: a_project.is_persisted
		do
			last_error := Void

			if a_remove_from_disk then
				if not remove_project_from_disk (a_project) then
					last_error := "Disk removal failed"
				end
			end

			Result := repository.delete (a_project.id)
		end

feature -- Disk Operations

	remove_project_from_disk (a_project: SC_PROJECT): BOOLEAN
			-- Recursively delete project directory from disk.
		local
			l_dir: SIMPLE_FILE
		do
			create l_dir.make (a_project.path)
			if l_dir.exists then
				Result := l_dir.delete_directory_recursive
			else
				-- Directory doesn't exist - consider this success
				Result := True
			end
		end

	project_exists_on_disk (a_project: SC_PROJECT): BOOLEAN
			-- Does project directory still exist on disk?
		local
			l_dir: SIMPLE_FILE
		do
			create l_dir.make (a_project.path)
			Result := l_dir.is_directory
		end

	ecf_exists_on_disk (a_project: SC_PROJECT): BOOLEAN
			-- Does project ECF file exist on disk?
		local
			l_file: SIMPLE_FILE
		do
			create l_file.make (a_project.ecf_path)
			Result := l_file.is_file
		end

feature -- Synchronization

	sync_with_disk: ARRAYED_LIST [SC_PROJECT]
			-- Find all projects where disk state doesn't match DB state.
			-- Returns projects that exist in DB but not on disk.
		local
			l_all: ARRAYED_LIST [SC_PROJECT]
		do
			create Result.make (5)
			l_all := all_projects
			across l_all as p loop
				if not project_exists_on_disk (p) then
					Result.extend (p)
				end
			end
		ensure
			result_attached: Result /= Void
		end

feature -- Status

	has_error: BOOLEAN
			-- Did the last operation cause an error?
		do
			Result := attached last_error
		end

invariant
	database_open: database.is_open
	repository_attached: repository /= Void
	db_path_not_empty: not db_path.is_empty

end
