note
	description: "Test cases for SC_PROJECT persistence and lifecycle"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	TEST_SC_PROJECT

inherit
	TEST_SET_BASE
		redefine
			on_prepare,
			on_clean
		end

feature -- Setup/Teardown

	prepare
			-- Ensure clean state before tests.
		local
			l_dir: SIMPLE_FILE
			l_db_file: SIMPLE_FILE
			l_ok: BOOLEAN
		do
			-- Clean up test project directory
			create l_dir.make (test_project_path)
			if l_dir.exists then
				l_ok := l_dir.delete_directory_recursive
			end

			-- Clean up test database
			create l_db_file.make (test_db_path)
			if l_db_file.exists then
				l_ok := l_db_file.delete
			end
		end

	cleanup
			-- Clean up after tests.
		local
			l_dir: SIMPLE_FILE
			l_db_file: SIMPLE_FILE
			l_ok: BOOLEAN
		do
			-- Clean up test project directory
			create l_dir.make (test_project_path)
			if l_dir.exists then
				l_ok := l_dir.delete_directory_recursive
			end

			-- Clean up test database
			create l_db_file.make (test_db_path)
			if l_db_file.exists then
				l_ok := l_db_file.delete
			end
		end

feature {NONE} -- Events

	on_prepare
			-- Ensure clean state before tests.
		do
			prepare
		end

	on_clean
			-- Clean up after tests.
		do
			cleanup
		end

feature -- Test: SC_PROJECT Entity

	test_project_from_generator
			-- Test creating SC_PROJECT from SCG_PROJECT_GEN.
		local
			l_gen: SCG_PROJECT_GEN
			l_path: SIMPLE_PATH
			l_libs: ARRAYED_LIST [STRING]
			l_project: SC_PROJECT
		do
			-- Generate a project
			create l_path.make_from (test_project_path)
			create l_libs.make (2)
			l_libs.extend ("simple_file")
			l_libs.extend ("simple_json")
			create l_gen.make_with_name (l_path, test_project_name, l_libs)

			-- Create entity from generator
			create l_project.make_from_generator (l_gen)

			-- Verify entity state
			assert ("is_new", l_project.is_new)
			assert ("not_persisted", not l_project.is_persisted)
			assert ("uuid_not_empty", not l_project.uuid.is_empty)
			assert ("name_matches", l_project.name.same_string (test_project_name))
			assert ("path_set", not l_project.path.is_empty)
			assert ("libraries_count", l_project.libraries.count = 2)
			assert ("has_simple_file", has_library (l_project.libraries, "simple_file"))
			assert ("has_simple_json", has_library (l_project.libraries, "simple_json"))
			assert ("is_generated", l_project.is_generated)
			assert ("is_verified", l_project.is_verified)
			assert ("not_deleted", not l_project.is_deleted)
			assert ("created_at_set", not l_project.created_at.is_empty)
			assert ("updated_at_set", not l_project.updated_at.is_empty)
		end

	test_project_libraries_json
			-- Test libraries JSON serialization.
		local
			l_libs: ARRAYED_LIST [STRING]
			l_project: SC_PROJECT
			l_json: STRING
		do
			create l_libs.make (3)
			l_libs.extend ("simple_file")
			l_libs.extend ("simple_json")
			l_libs.extend ("simple_sql")
			create l_project.make_new (test_project_name, test_project_path, l_libs)

			l_json := l_project.libraries_as_json

			assert ("json_starts_bracket", l_json.starts_with ("["))
			assert ("json_ends_bracket", l_json.ends_with ("]"))
			assert ("json_has_simple_file", l_json.has_substring ("%"simple_file%""))
			assert ("json_has_simple_json", l_json.has_substring ("%"simple_json%""))
			assert ("json_has_simple_sql", l_json.has_substring ("%"simple_sql%""))
		end

feature -- Test: Persistence

	test_project_persistence
			-- Test saving and loading project from database.
		local
			l_manager: SC_PROJECT_MANAGER
			l_gen: SCG_PROJECT_GEN
			l_path: SIMPLE_PATH
			l_libs: ARRAYED_LIST [STRING]
			l_project: detachable SC_PROJECT
			l_found: detachable SC_PROJECT
			l_saved_id: INTEGER_64
			l_saved_uuid: STRING
		do
			-- Create manager with in-memory database
			create l_manager.make_memory

			-- Generate a project
			create l_path.make_from (test_project_path)
			create l_libs.make (2)
			l_libs.extend ("simple_file")
			l_libs.extend ("simple_json")
			create l_gen.make_with_name (l_path, test_project_name, l_libs)

			-- Persist project
			l_project := l_manager.persist_existing (l_gen)

			assert ("project_created", attached l_project)
			if attached l_project as proj then
				assert ("is_persisted", proj.is_persisted)
				assert ("id_positive", proj.id > 0)
				l_saved_id := proj.id
				l_saved_uuid := proj.uuid.twin

				-- Find by ID
				l_found := l_manager.find_project (l_saved_id)
				assert ("found_by_id", attached l_found)
				if attached l_found as f then
					assert ("id_matches", f.id = l_saved_id)
					assert ("uuid_matches", f.uuid.same_string (l_saved_uuid))
					assert ("name_matches", f.name.same_string (test_project_name))
					assert ("libraries_restored", f.libraries.count = 2)
				end

				-- Find by UUID
				l_found := l_manager.find_by_uuid (l_saved_uuid)
				assert ("found_by_uuid", attached l_found)

				-- Find by path
				l_found := l_manager.find_by_path (proj.path)
				assert ("found_by_path", attached l_found)
			end
		end

	test_project_soft_delete
			-- Test soft-delete functionality.
		local
			l_manager: SC_PROJECT_MANAGER
			l_gen: SCG_PROJECT_GEN
			l_path: SIMPLE_PATH
			l_libs: ARRAYED_LIST [STRING]
			l_project: detachable SC_PROJECT
			l_deleted: ARRAYED_LIST [SC_PROJECT]
			l_active: ARRAYED_LIST [SC_PROJECT]
		do
			create l_manager.make_memory

			-- Generate and persist project
			create l_path.make_from (test_project_path)
			create l_libs.make (1)
			l_libs.extend ("simple_file")
			create l_gen.make_with_name (l_path, test_project_name, l_libs)
			l_project := l_manager.persist_existing (l_gen)

			assert ("project_created", attached l_project)
			if attached l_project as proj then
				-- Verify initial state
				l_active := l_manager.all_projects
				assert ("one_active", l_active.count = 1)

				l_deleted := l_manager.all_deleted_projects
				assert ("none_deleted", l_deleted.count = 0)

				-- Soft delete (don't remove from disk for this test)
				assert ("delete_success", l_manager.delete_project (proj, False))
				assert ("project_marked_deleted", proj.is_deleted)
				assert ("deleted_at_set", attached proj.deleted_at)

				-- Verify deleted lists
				l_active := l_manager.all_projects
				assert ("none_active_after_delete", l_active.count = 0)

				l_deleted := l_manager.all_deleted_projects
				assert ("one_deleted", l_deleted.count = 1)

				-- Restore project
				assert ("restore_success", l_manager.restore_project (proj))
				assert ("project_not_deleted", not proj.is_deleted)

				l_active := l_manager.all_projects
				assert ("one_active_after_restore", l_active.count = 1)
			end
		end

	test_project_cleanup_deleted
			-- Test purging soft-deleted projects.
		local
			l_manager: SC_PROJECT_MANAGER
			l_gen: SCG_PROJECT_GEN
			l_path: SIMPLE_PATH
			l_libs: ARRAYED_LIST [STRING]
			l_project: detachable SC_PROJECT
			l_purged: INTEGER
		do
			create l_manager.make_memory

			-- Generate and persist project
			create l_path.make_from (test_project_path)
			create l_libs.make (1)
			l_libs.extend ("simple_file")
			create l_gen.make_with_name (l_path, test_project_name, l_libs)
			l_project := l_manager.persist_existing (l_gen)

			if attached l_project as proj then
				-- Soft delete
				assert ("delete_success", l_manager.delete_project (proj, False))

				-- Purge deleted
				l_purged := l_manager.cleanup_deleted_projects
				assert ("one_purged", l_purged = 1)

				-- Verify gone
				assert ("count_zero", l_manager.project_count = 0)
				assert ("project_not_found", l_manager.find_project (proj.id) = Void)
			end
		end

	test_project_disk_deletion
			-- Test removing project from disk.
		local
			l_manager: SC_PROJECT_MANAGER
			l_gen: SCG_PROJECT_GEN
			l_path: SIMPLE_PATH
			l_libs: ARRAYED_LIST [STRING]
			l_project: detachable SC_PROJECT
			l_dir: SIMPLE_FILE
		do
			create l_manager.make_memory

			-- Generate and persist project
			create l_path.make_from (test_project_path)
			create l_libs.make (1)
			l_libs.extend ("simple_file")
			create l_gen.make_with_name (l_path, test_project_name, l_libs)
			l_project := l_manager.persist_existing (l_gen)

			if attached l_project as proj then
				-- Verify project exists on disk
				assert ("exists_on_disk", l_manager.project_exists_on_disk (proj))
				assert ("ecf_exists", l_manager.ecf_exists_on_disk (proj))

				-- Delete with disk removal
				assert ("delete_with_disk", l_manager.delete_project (proj, True))

				-- Verify removed from disk
				create l_dir.make (test_project_path)
				assert ("not_on_disk", not l_dir.exists)
			end
		end

	test_project_full_lifecycle
			-- Test complete project lifecycle: generate → persist → retrieve → delete.
		local
			l_manager: SC_PROJECT_MANAGER
			l_path: SIMPLE_PATH
			l_libs: ARRAYED_LIST [STRING]
			l_project: detachable SC_PROJECT
			l_found: detachable SC_PROJECT
		do
			create l_manager.make_memory

			-- Setup libraries
			create l_path.make_from (test_project_path)
			create l_libs.make (2)
			l_libs.extend ("simple_file")
			l_libs.extend ("simple_sql")

			-- Generate and persist in one call
			l_project := l_manager.generate_and_persist (l_path, test_project_name, l_libs)

			assert ("project_created", attached l_project)
			if attached l_project as proj then
				-- Verify persisted
				assert ("is_persisted", proj.is_persisted)
				assert ("is_generated", proj.is_generated)
				assert ("is_verified", proj.is_verified)

				-- Verify can be found
				l_found := l_manager.find_by_path (proj.path)
				assert ("found_by_path", attached l_found)

				-- Verify on disk
				assert ("on_disk", l_manager.project_exists_on_disk (proj))

				-- Hard delete with disk removal
				assert ("hard_delete", l_manager.hard_delete (proj, True))

				-- Verify gone from DB
				assert ("not_in_db", l_manager.find_project (proj.id) = Void)

				-- Verify gone from disk
				assert ("not_on_disk", not l_manager.project_exists_on_disk (proj))
			end
		end

feature {NONE} -- Test Helpers

	has_library (a_libs: ARRAYED_LIST [STRING]; a_name: STRING): BOOLEAN
			-- Does `a_libs' contain a string equal to `a_name'?
		do
			across a_libs as lib loop
				if lib.same_string (a_name) then
					Result := True
				end
			end
		end

feature {NONE} -- Test Constants

	test_project_name: STRING = "test_generated_project"
			-- Name of test project

	test_project_path: STRING
			-- Path where test project will be generated
		once
			Result := "D:/prod/simple_code/testing/temp_test_project"
		end

	test_db_path: STRING
			-- Path to test database file
		once
			Result := "D:/prod/simple_code/testing/test_projects.db"
		end

end
