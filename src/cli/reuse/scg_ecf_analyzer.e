note
	description: "[
		ECF dependency analyzer for reuse discovery.

		Parses an ECF file to extract:
		- All library dependencies
		- Which libraries are simple_* ecosystem libraries
		- Library locations resolved with environment variables

		Used by SCG_REUSE_DISCOVERER to understand which APIs
		are available for reuse in a project.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_ECF_ANALYZER

create
	make

feature {NONE} -- Initialization

	make
			-- Create ECF analyzer.
		do
			create xml.make
			create last_error.make_empty
			create libraries.make (20)
			create simple_libraries.make (10)
			create ecf_directory.make_empty
		end

feature -- Access

	libraries: ARRAYED_LIST [TUPLE [name: STRING; location: STRING; resolved_path: STRING]]
			-- All library dependencies

	simple_libraries: ARRAYED_LIST [STRING]
			-- Names of simple_* ecosystem libraries found

	last_error: STRING
			-- Error message from last operation

feature -- Status

	is_valid: BOOLEAN
			-- Was last parse successful?

	has_error: BOOLEAN
			-- Did an error occur?
		do
			Result := not last_error.is_empty
		end

	simple_library_count: INTEGER
			-- Number of simple_* libraries found
		do
			Result := simple_libraries.count
		end

feature -- Analysis

	analyze_file (a_ecf_path: STRING)
			-- Analyze ECF file at `a_ecf_path'.
		require
			path_not_empty: not a_ecf_path.is_empty
		local
			l_doc: SIMPLE_XML_DOCUMENT
		do
			reset
			ecf_directory := directory_of (a_ecf_path)

			l_doc := xml.parse_file (a_ecf_path)
			if l_doc.is_valid then
				if attached l_doc.root as l_root then
					parse_system (l_root)
					is_valid := last_error.is_empty
				else
					last_error := "ECF has no root element"
				end
			else
				last_error := "Failed to parse ECF: " + l_doc.error_message
			end
		end

	analyze_string (a_xml: STRING)
			-- Analyze ECF from XML string.
		require
			xml_not_empty: not a_xml.is_empty
		local
			l_doc: SIMPLE_XML_DOCUMENT
		do
			reset
			l_doc := xml.parse (a_xml)
			if l_doc.is_valid then
				if attached l_doc.root as l_root then
					parse_system (l_root)
					is_valid := last_error.is_empty
				else
					last_error := "ECF has no root element"
				end
			else
				last_error := "Failed to parse ECF: " + l_doc.error_message
			end
		end

feature -- Query

	has_library (a_name: STRING): BOOLEAN
			-- Does this ECF reference library named `a_name'?
		require
			name_not_empty: not a_name.is_empty
		do
			Result := across libraries as lib some lib.name.is_case_insensitive_equal (a_name) end
		end

	has_simple_library (a_name: STRING): BOOLEAN
			-- Does this ECF reference simple_* library named `a_name'?
		require
			name_not_empty: not a_name.is_empty
		do
			Result := across simple_libraries as lib some lib.is_case_insensitive_equal (a_name) end
		end

	library_path (a_name: STRING): detachable STRING
			-- Get resolved path for library named `a_name'.
		require
			name_not_empty: not a_name.is_empty
		do
			across libraries as lib loop
				if lib.name.is_case_insensitive_equal (a_name) then
					Result := lib.resolved_path
				end
			end
		end

	all_library_names: ARRAYED_LIST [STRING]
			-- All library names
		do
			create Result.make (libraries.count)
			across libraries as lib loop
				Result.extend (lib.name)
			end
		end

feature -- Output

	as_summary: STRING
			-- Summary of analysis
		do
			create Result.make (200)
			Result.append ("Libraries: ")
			Result.append (libraries.count.out)
			Result.append (" (simple_*: ")
			Result.append (simple_libraries.count.out)
			Result.append (")%N")
			if not simple_libraries.is_empty then
				Result.append ("Simple libraries: ")
				across simple_libraries as lib loop
					if not Result.ends_with (": ") then
						Result.append (", ")
					end
					Result.append (lib)
				end
			end
		end

	simple_libraries_for_prompt: STRING
			-- Format simple_* libraries for prompt injection
		do
			create Result.make (500)
			if not simple_libraries.is_empty then
				Result.append ("=== AVAILABLE SIMPLE_* LIBRARIES ===%N")
				across simple_libraries as lib loop
					Result.append ("- ")
					Result.append (lib)
					Result.append ("%N")
				end
			end
		end

feature {NONE} -- Parsing

	parse_system (a_system: SIMPLE_XML_ELEMENT)
			-- Parse <system> element.
		require
			system_not_void: a_system /= Void
		do
			-- Parse all targets
			across a_system.elements ("target") as ic loop
				parse_target (ic)
			end
		end

	parse_target (a_target: SIMPLE_XML_ELEMENT)
			-- Parse <target> element.
		require
			target_not_void: a_target /= Void
		do
			-- Parse libraries in this target
			across a_target.elements ("library") as ic loop
				parse_library (ic)
			end
		end

	parse_library (a_lib: SIMPLE_XML_ELEMENT)
			-- Parse <library> element.
		require
			lib_not_void: a_lib /= Void
		local
			l_name, l_location, l_resolved: STRING
		do
			l_name := ""
			l_location := ""

			if attached a_lib.attr ("name") as n then
				l_name := n
			end
			if attached a_lib.attr ("location") as loc then
				l_location := loc
				l_resolved := resolve_path (loc)
			else
				l_resolved := ""
			end

			if not l_name.is_empty then
				libraries.extend ([l_name, l_location, l_resolved])

				-- Check if it's a simple_* library
				if is_simple_library (l_name, l_location) then
					if not simple_libraries.has (l_name) then
						simple_libraries.extend (l_name)
					end
				end
			end
		end

feature {NONE} -- Helpers

	is_simple_library (a_name, a_location: STRING): BOOLEAN
			-- Is this a simple_* ecosystem library?
		do
			-- Check by name prefix
			if a_name.starts_with ("simple_") then
				Result := True
			-- Check by location containing SIMPLE_EIFFEL or simple_
			elseif a_location.has_substring ("SIMPLE_EIFFEL") or
			       a_location.has_substring ("simple_") then
				Result := True
			end
		end

	resolve_path (a_path: STRING): STRING
			-- Resolve environment variables in path.
		local
			l_start, l_end: INTEGER
			l_var_name: STRING
			l_var_value: detachable STRING
		do
			Result := a_path.twin

			-- Expand $VAR syntax
			from
				l_start := Result.index_of ('$', 1)
			until
				l_start = 0
			loop
				-- Find end of variable name
				from
					l_end := l_start + 1
				until
					l_end > Result.count or else
					Result [l_end] = '\' or else
					Result [l_end] = '/'
				loop
					l_end := l_end + 1
				end

				l_var_name := Result.substring (l_start + 1, l_end - 1)
				l_var_value := get_env (l_var_name)

				if attached l_var_value as lv and then not lv.is_empty then
					Result.replace_substring (lv, l_start, l_end - 1)
				end

				l_start := Result.index_of ('$', l_start + 1)
			end

			-- Handle relative paths
			if Result.starts_with (".\") or Result.starts_with ("./") then
				if not ecf_directory.is_empty then
					Result := ecf_directory + Result.substring (3, Result.count)
				end
			end

			-- Normalize separators
			Result.replace_substring_all ("\", "/")
		end

	get_env (a_name: STRING): detachable STRING
			-- Get environment variable value.
		local
			l_exec: EXECUTION_ENVIRONMENT
		do
			create l_exec
			if attached l_exec.get (a_name) as val then
				Result := val
			end
		end

	directory_of (a_path: STRING): STRING
			-- Extract directory from file path.
		local
			l_pos: INTEGER
		do
			l_pos := a_path.last_index_of ('\', a_path.count)
			if l_pos = 0 then
				l_pos := a_path.last_index_of ('/', a_path.count)
			end
			if l_pos > 0 then
				Result := a_path.substring (1, l_pos)
			else
				create Result.make_empty
			end
		end

	reset
			-- Reset analyzer state.
		do
			libraries.wipe_out
			simple_libraries.wipe_out
			last_error.wipe_out
			ecf_directory.wipe_out
			is_valid := False
		end

feature {NONE} -- Implementation

	xml: SIMPLE_XML
			-- XML parser

	ecf_directory: STRING
			-- Directory containing the ECF file

invariant
	libraries_exists: libraries /= Void
	simple_libraries_exists: simple_libraries /= Void

end
