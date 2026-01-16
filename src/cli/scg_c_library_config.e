note
	description: "[
		ECF Configuration Generator for C/C++ Libraries.

		Generates proper ECF snippets for integrating external C/C++ libraries:
		- external_include for header paths
		- external_library for .lib/.a files
		- external_object for .obj/.o files
		- Platform-specific conditions

		Supports:
		- Windows (.lib, .dll)
		- Linux (.a, .so)
		- macOS (.a, .dylib)
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_C_LIBRARY_CONFIG

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize library configuration.
		do
			create include_paths.make (5)
			create library_paths.make (5)
			create libraries.make (5)
			create object_files.make (5)
			create defines.make (5)
			target_platform := Platform_all
		end

feature -- Access

	include_paths: ARRAYED_LIST [STRING]
			-- Header include paths

	library_paths: ARRAYED_LIST [STRING]
			-- Library search paths

	libraries: ARRAYED_LIST [STRING]
			-- Library names (without path or extension)

	object_files: ARRAYED_LIST [STRING]
			-- Object files to link

	defines: ARRAYED_LIST [STRING]
			-- Preprocessor defines

	target_platform: STRING
			-- Target platform (windows, unix, all)

feature -- Configuration

	add_include_path (a_path: STRING)
			-- Add header include path.
		require
			path_not_empty: not a_path.is_empty
		do
			include_paths.extend (a_path)
		ensure
			added: include_paths.has (a_path)
		end

	add_library_path (a_path: STRING)
			-- Add library search path.
		require
			path_not_empty: not a_path.is_empty
		do
			library_paths.extend (a_path)
		ensure
			added: library_paths.has (a_path)
		end

	add_library (a_name: STRING)
			-- Add library to link (name without extension).
		require
			name_not_empty: not a_name.is_empty
		do
			libraries.extend (a_name)
		ensure
			added: libraries.has (a_name)
		end

	add_object_file (a_path: STRING)
			-- Add object file to link.
		require
			path_not_empty: not a_path.is_empty
		do
			object_files.extend (a_path)
		ensure
			added: object_files.has (a_path)
		end

	add_define (a_define: STRING)
			-- Add preprocessor define.
		require
			define_not_empty: not a_define.is_empty
		do
			defines.extend (a_define)
		ensure
			added: defines.has (a_define)
		end

	set_platform (a_platform: STRING)
			-- Set target platform.
		require
			valid_platform: a_platform.is_case_insensitive_equal (Platform_windows) or
			                a_platform.is_case_insensitive_equal (Platform_unix) or
			                a_platform.is_case_insensitive_equal (Platform_all)
		do
			target_platform := a_platform
		ensure
			platform_set: target_platform = a_platform
		end

feature -- ECF Generation

	generate_ecf_snippet: STRING
			-- Generate ECF XML snippet for external settings.
		do
			create Result.make (1000)

			-- Start external_include section
			if not include_paths.is_empty then
				across include_paths as ic loop
					Result.append (generate_external_include (ic))
				end
			end

			-- External library paths and libraries
			if not library_paths.is_empty or not libraries.is_empty then
				across libraries as ic loop
					Result.append (generate_external_library (ic))
				end
			end

			-- Object files
			if not object_files.is_empty then
				across object_files as ic loop
					Result.append (generate_external_object (ic))
				end
			end
		end

	generate_external_include (a_path: STRING): STRING
			-- Generate external_include element.
		require
			path_not_empty: not a_path.is_empty
		do
			create Result.make (200)
			Result.append ("%T%T<external_include location=%"")
			Result.append (escape_xml (a_path))
			Result.append ("%"")
			if not target_platform.is_case_insensitive_equal (Platform_all) then
				Result.append (">%N")
				Result.append (generate_platform_condition)
				Result.append ("%T%T</external_include>%N")
			else
				Result.append ("/>%N")
			end
		end

	generate_external_library (a_name: STRING): STRING
			-- Generate external_library element with platform-specific extension.
		require
			name_not_empty: not a_name.is_empty
		do
			create Result.make (400)

			if target_platform.is_case_insensitive_equal (Platform_windows) or
			   target_platform.is_case_insensitive_equal (Platform_all) then
				-- Windows library
				Result.append ("%T%T<external_library location=%"")
				if not library_paths.is_empty then
					Result.append (escape_xml (library_paths.first))
					Result.append ("/")
				end
				Result.append (a_name)
				Result.append (".lib%">%N")
				Result.append ("%T%T%T<condition>%N")
				Result.append ("%T%T%T%T<platform value=%"windows%"/>%N")
				Result.append ("%T%T%T</condition>%N")
				Result.append ("%T%T</external_library>%N")
			end

			if target_platform.is_case_insensitive_equal (Platform_unix) or
			   target_platform.is_case_insensitive_equal (Platform_all) then
				-- Unix/Linux library
				Result.append ("%T%T<external_library location=%"-l")
				Result.append (a_name)
				Result.append ("%">%N")
				Result.append ("%T%T%T<condition>%N")
				Result.append ("%T%T%T%T<platform excluded_value=%"windows%"/>%N")
				Result.append ("%T%T%T</condition>%N")
				Result.append ("%T%T</external_library>%N")
			end
		end

	generate_external_object (a_path: STRING): STRING
			-- Generate external_object element.
		require
			path_not_empty: not a_path.is_empty
		do
			create Result.make (200)
			Result.append ("%T%T<external_object location=%"")
			Result.append (escape_xml (a_path))
			Result.append ("%"")
			if not target_platform.is_case_insensitive_equal (Platform_all) then
				Result.append (">%N")
				Result.append (generate_platform_condition)
				Result.append ("%T%T</external_object>%N")
			else
				Result.append ("/>%N")
			end
		end

	generate_platform_condition: STRING
			-- Generate platform condition XML.
		do
			create Result.make (100)
			Result.append ("%T%T%T<condition>%N")
			if target_platform.is_case_insensitive_equal (Platform_windows) then
				Result.append ("%T%T%T%T<platform value=%"windows%"/>%N")
			elseif target_platform.is_case_insensitive_equal (Platform_unix) then
				Result.append ("%T%T%T%T<platform excluded_value=%"windows%"/>%N")
			end
			Result.append ("%T%T%T</condition>%N")
		end

feature -- Full ECF Template

	generate_c_library_ecf (a_lib_name: STRING; a_root_class: STRING): STRING
			-- Generate complete ECF for a C library wrapper.
		require
			name_not_empty: not a_lib_name.is_empty
			root_not_empty: not a_root_class.is_empty
		do
			create Result.make (2000)
			Result.append ("<?xml version=%"1.0%" encoding=%"ISO-8859-1%"?>%N")
			Result.append ("<system xmlns=%"http://www.eiffel.com/developers/xml/configuration-1-23-0%"%N")
			Result.append ("    name=%"")
			Result.append (a_lib_name)
			Result.append ("%" uuid=%"")
			Result.append (generate_uuid)
			Result.append ("%" library_target=%"")
			Result.append (a_lib_name)
			Result.append ("%">%N")
			Result.append ("%T<target name=%"")
			Result.append (a_lib_name)
			Result.append ("%">%N")
			Result.append ("%T%T<root all_classes=%"true%"/>%N")
			Result.append ("%T%T<option warning=%"warning%">%N")
			Result.append ("%T%T%T<assertions precondition=%"true%" postcondition=%"true%" check=%"true%"/>%N")
			Result.append ("%T%T</option>%N")
			Result.append ("%T%T<capability>%N")
			Result.append ("%T%T%T<concurrency support=%"scoop%"/>%N")
			Result.append ("%T%T%T<void_safety support=%"all%"/>%N")
			Result.append ("%T%T</capability>%N")
			Result.append ("%T%T<library name=%"base%" location=%"$ISE_LIBRARY\library\base\base.ecf%"/>%N")

			-- Add external includes and libraries
			Result.append (generate_ecf_snippet)

			Result.append ("%T%T<cluster name=%"src%" location=%".\src\%" recursive=%"true%"/>%N")
			Result.append ("%T</target>%N")
			Result.append ("</system>%N")
		end

feature -- Documentation

	ecf_c_integration_doc: STRING
			-- Documentation for ECF C integration elements.
		once
			Result := "[
=== ECF C/C++ INTEGRATION ELEMENTS ===

EXTERNAL_INCLUDE - Add header search paths:
  <external_include location="path/to/headers"/>
  <external_include location="$(MY_LIB)/include"/>

EXTERNAL_LIBRARY - Link libraries:
  Windows: <external_library location="path/lib.lib"/>
  Unix: <external_library location="-lmylib"/>
  With path: <external_library location="-L/path -lmylib"/>

EXTERNAL_OBJECT - Link object files:
  <external_object location="path/to/file.obj"/>

PLATFORM CONDITIONS:
  <condition>
    <platform value="windows"/>  -- Windows only
  </condition>

  <condition>
    <platform excluded_value="windows"/>  -- Unix/Mac only
  </condition>

ENVIRONMENT VARIABLES:
  Use $(VAR_NAME) or $VAR_NAME syntax
  Common: $ISE_LIBRARY, $ISE_EIFFEL, $SIMPLE_EIFFEL

EXAMPLE - SQLite integration:
  <external_include location="$(SQLITE_DIR)/include"/>
  <external_library location="$(SQLITE_DIR)/lib/sqlite3.lib">
    <condition>
      <platform value="windows"/>
    </condition>
  </external_library>
  <external_library location="-lsqlite3">
    <condition>
      <platform excluded_value="windows"/>
    </condition>
  </external_library>
]"
		end

feature {NONE} -- Implementation

	escape_xml (a_str: STRING): STRING
			-- Escape XML special characters.
		do
			create Result.make (a_str.count + 10)
			Result.append (a_str)
			Result.replace_substring_all ("&", "&amp;")
			Result.replace_substring_all ("<", "&lt;")
			Result.replace_substring_all (">", "&gt;")
			Result.replace_substring_all ("%"", "&quot;")
		end

	generate_uuid: STRING
			-- Generate a placeholder UUID.
		do
			Result := "00000000-0000-0000-0000-000000000000"
			-- In real implementation, use SIMPLE_UUID
		end

feature -- Platform Constants

	Platform_windows: STRING = "windows"
	Platform_unix: STRING = "unix"
	Platform_all: STRING = "all"

invariant
	include_paths_exists: include_paths /= Void
	library_paths_exists: library_paths /= Void
	libraries_exists: libraries /= Void
	object_files_exists: object_files /= Void
	defines_exists: defines /= Void

end
