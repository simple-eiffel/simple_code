note
	description: "[
		SC_PROJECT - Entity representing a generated Eiffel project.

		Captures all metadata about a project created by SCG_PROJECT_GEN:
		- Identity: uuid, path
		- Metadata: name, libraries
		- Status: is_generated, is_verified, verification_error
		- Timestamps: created_at, updated_at
		- Soft delete: is_deleted, deleted_at

		Factory methods:
		- make_from_generator: Create from SCG_PROJECT_GEN after generation
		- make_from_row: Reconstitute from database row
		- make_new: Create for new project (before generation)
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SC_PROJECT

create
	make_from_generator,
	make_from_row,
	make_new

feature {NONE} -- Initialization

	make_from_generator (a_generator: SCG_PROJECT_GEN)
			-- Create from completed project generator.
		require
			generator_completed: a_generator.is_generated
		local
			l_time: SIMPLE_DATE_TIME
		do
			id := 0
			uuid := a_generator.project_uuid.new_v4_string
			name := a_generator.project_name.twin
			path := a_generator.project_path.to_string.to_string_8
			create libraries.make (a_generator.simple_libs.count)
			across a_generator.simple_libs as lib loop
				libraries.extend (lib.twin)
			end
			is_generated := a_generator.is_generated
			is_verified := a_generator.is_verified
			if attached a_generator.verification_error as err then
				verification_error := err.twin
			end

			-- Set timestamps to now
			create l_time.make_now
			created_at := l_time.to_iso8601
			updated_at := created_at.twin

			is_deleted := False
		ensure
			is_new: is_new
			uuid_set: not uuid.is_empty
			name_set: name.same_string (a_generator.project_name)
			path_set: not path.is_empty
			generated_matches: is_generated = a_generator.is_generated
			verified_matches: is_verified = a_generator.is_verified
			not_deleted: not is_deleted
		end

	make_from_row (a_row: SIMPLE_SQL_ROW)
			-- Reconstitute from database row.
		require
			row_valid: a_row /= Void
		local
			l_libs_json: STRING
		do
			id := a_row.integer_64_value ("id")
			uuid := a_row.string_value ("uuid").to_string_8
			name := a_row.string_value ("name").to_string_8
			path := a_row.string_value ("path").to_string_8

			-- Parse libraries from JSON array
			create libraries.make (5)
			if not a_row.is_null ("libraries_json") then
				l_libs_json := a_row.string_value ("libraries_json").to_string_8
				parse_libraries_json (l_libs_json)
			end

			is_generated := a_row.integer_value ("is_generated") = 1
			is_verified := a_row.integer_value ("is_verified") = 1

			if not a_row.is_null ("verification_error") then
				verification_error := a_row.string_value ("verification_error").to_string_8
			end

			created_at := a_row.string_value ("created_at").to_string_8
			updated_at := a_row.string_value ("updated_at").to_string_8

			is_deleted := a_row.integer_value ("is_deleted") = 1
			if not a_row.is_null ("deleted_at") then
				deleted_at := a_row.string_value ("deleted_at").to_string_8
			end
		ensure
			id_set: id = a_row.integer_64_value ("id")
			is_persisted: not is_new
		end

	make_new (a_name: STRING; a_path: STRING; a_libraries: ARRAYED_LIST [STRING])
			-- Create new project entity (before generation).
		require
			name_not_empty: not a_name.is_empty
			path_not_empty: not a_path.is_empty
		local
			l_uuid: SIMPLE_UUID
			l_time: SIMPLE_DATE_TIME
		do
			id := 0
			create l_uuid.make
			uuid := l_uuid.new_v4_string
			name := a_name.twin
			path := a_path.twin
			create libraries.make (a_libraries.count)
			across a_libraries as lib loop
				libraries.extend (lib.twin)
			end
			is_generated := False
			is_verified := False

			create l_time.make_now
			created_at := l_time.to_iso8601
			updated_at := created_at.twin

			is_deleted := False
		ensure
			is_new: is_new
			name_set: name.same_string (a_name)
			path_set: path.same_string (a_path)
			not_generated: not is_generated
			not_verified: not is_verified
			not_deleted: not is_deleted
		end

feature -- Identity

	id: INTEGER_64
			-- Database primary key (0 if not yet persisted)

	uuid: STRING
			-- Unique identifier from ECF (never changes)

feature -- Project Data

	name: STRING
			-- Project name (used for ECF, class names, etc.)

	path: STRING
			-- Full path to project root directory

	libraries: ARRAYED_LIST [STRING]
			-- List of simple_* library dependencies

feature -- Status

	is_generated: BOOLEAN
			-- Was project scaffold successfully generated?

	is_verified: BOOLEAN
			-- Did generated project pass compilation verification?

	verification_error: detachable STRING
			-- Error message if verification failed

feature -- Timestamps

	created_at: STRING
			-- When project was created (ISO 8601)

	updated_at: STRING
			-- When project was last modified (ISO 8601)

feature -- Deletion

	is_deleted: BOOLEAN
			-- Has project been soft-deleted?

	deleted_at: detachable STRING
			-- When project was marked deleted (ISO 8601), Void if not deleted

feature -- Queries

	is_new: BOOLEAN
			-- Has this project not yet been saved to database?
		do
			Result := id = 0
		end

	is_persisted: BOOLEAN
			-- Has this project been saved to database?
		do
			Result := id > 0
		ensure
			definition: Result = (id > 0)
		end

	is_active: BOOLEAN
			-- Is this project active (not deleted)?
		do
			Result := not is_deleted
		end

	libraries_as_json: STRING
			-- Libraries list as JSON array string.
		do
			create Result.make (50)
			Result.append_character ('[')
			across libraries as lib loop
				if not Result.same_string ("[") then
					Result.append_character (',')
				end
				Result.append_character ('"')
				Result.append (lib)
				Result.append_character ('"')
			end
			Result.append_character (']')
		ensure
			valid_json: Result.starts_with ("[") and Result.ends_with ("]")
		end

	ecf_path: STRING
			-- Full path to project ECF file.
		do
			Result := path + "\" + name + ".ecf"
		ensure
			not_empty: not Result.is_empty
			ends_with_ecf: Result.ends_with (".ecf")
		end

feature -- Modification

	set_id (a_id: INTEGER_64)
			-- Set database ID after insert.
		require
			was_new: is_new
			valid_id: a_id > 0
		do
			id := a_id
		ensure
			id_set: id = a_id
			now_persisted: is_persisted
		end

	set_generated (a_value: BOOLEAN)
			-- Set generation status.
		do
			is_generated := a_value
			touch
		ensure
			set: is_generated = a_value
		end

	set_verified (a_value: BOOLEAN; a_error: detachable STRING)
			-- Set verification status with optional error.
		do
			is_verified := a_value
			if attached a_error as err then
				verification_error := err.twin
			else
				verification_error := Void
			end
			touch
		ensure
			verified_set: is_verified = a_value
			error_set: (attached a_error as e) implies (attached verification_error as ve and then ve.same_string (e))
			no_error_if_void: a_error = Void implies verification_error = Void
		end

	mark_deleted
			-- Soft-delete this project.
		local
			l_time: SIMPLE_DATE_TIME
		do
			is_deleted := True
			create l_time.make_now
			deleted_at := l_time.to_iso8601
			touch
		ensure
			deleted: is_deleted
			timestamp_set: attached deleted_at
		end

	unmark_deleted
			-- Remove soft-delete flag.
		do
			is_deleted := False
			deleted_at := Void
			touch
		ensure
			not_deleted: not is_deleted
			no_timestamp: deleted_at = Void
		end

	touch
			-- Update the updated_at timestamp to now.
		local
			l_time: SIMPLE_DATE_TIME
		do
			create l_time.make_now
			updated_at := l_time.to_iso8601
		end

feature {NONE} -- Implementation

	parse_libraries_json (a_json: STRING)
			-- Parse JSON array string into libraries list.
			-- Simple parser for ["lib1","lib2","lib3"] format.
		local
			l_content: STRING
			l_parts: LIST [STRING]
			l_lib: STRING
		do
			libraries.wipe_out
			if a_json.count > 2 then
				-- Remove brackets
				l_content := a_json.substring (2, a_json.count - 1)
				l_parts := l_content.split (',')
				across l_parts as part loop
					l_lib := part.twin
					l_lib.left_adjust
					l_lib.right_adjust
					-- Remove quotes
					if l_lib.count >= 2 and then l_lib.item (1) = '"' then
						l_lib := l_lib.substring (2, l_lib.count - 1)
					end
					if not l_lib.is_empty then
						libraries.extend (l_lib)
					end
				end
			end
		end

invariant
	uuid_not_empty: not uuid.is_empty
	name_not_empty: not name.is_empty
	path_not_empty: not path.is_empty
	libraries_attached: libraries /= Void
	created_at_not_empty: not created_at.is_empty
	updated_at_not_empty: not updated_at.is_empty
	id_non_negative: id >= 0
	deleted_implies_timestamp: is_deleted implies attached deleted_at
	not_deleted_implies_no_timestamp: not is_deleted implies deleted_at = Void
	verification_error_semantics: (not is_verified and is_generated) implies True -- error may or may not be present

end
