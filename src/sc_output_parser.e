note
	description: "[
		Parser for EiffelStudio ec.exe output.

		Parses raw stdout/stderr from ec.exe into structured SC_COMPILE_RESULT.

		Recognizes:
		- Degree progress (6 down to 1, then -1 for code generation)
		- System Recompiled / System Melted messages
		- C compilation output
		- Error blocks with codes like VEEN, VUAR, VD71, etc.
		- Warning blocks
		- File paths and line numbers
	]"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	SC_OUTPUT_PARSER

feature -- Parsing

	parse (a_output: STRING; a_error: STRING; a_exit_code: INTEGER): SC_COMPILE_RESULT
			-- Parse compiler output into structured result.
		local
			l_combined: STRING
			l_lines: LIST [STRING]
		do
			create Result.make
			Result.set_raw_output (a_output)
			Result.set_raw_error (a_error)
			Result.set_exit_code (a_exit_code)

			-- Combine output and error for parsing (errors often in stdout)
			create l_combined.make (a_output.count + a_error.count + 1)
			l_combined.append (a_output)
			l_combined.append (a_error)

			-- Split once and reuse for all line-based parsing
			l_lines := l_combined.split ('%N')

			parse_degrees (l_combined, Result)
			parse_compilation_mode (l_combined, Result)
			parse_system_status (l_combined, Result)
			parse_c_compilation (l_combined, Result)
			parse_errors_from_lines (l_lines, Result)
			parse_warnings_from_lines (l_lines, Result)

			-- Determine overall success
			Result.set_is_success (a_exit_code = 0 and not Result.has_errors and Result.is_system_recompiled)
		ensure
			result_not_void: Result /= Void
		end

feature {NONE} -- Degree Parsing

	parse_degrees (a_text: STRING; a_result: SC_COMPILE_RESULT)
			-- Parse degree progress from output.
			-- Tracks the LOWEST degree reached (which means highest completion).
			-- Degree 6 is first (examining), degree 1 is last before code gen.
		local
			l_degree: INTEGER
		do
			l_degree := -1  -- No degrees completed

			-- Check in order from highest to lowest - first match that exists
			-- indicates how far compilation progressed
			if a_text.has_substring (Degree_minus_1_marker) then
				l_degree := 0  -- Code generation complete
			elseif a_text.has_substring (Degree_1_marker) then
				l_degree := 1
			elseif a_text.has_substring (Degree_2_marker) then
				l_degree := 2
			elseif a_text.has_substring (Degree_3_marker) then
				l_degree := 3
			elseif a_text.has_substring (Degree_4_marker) then
				l_degree := 4
			elseif a_text.has_substring (Degree_5_marker) then
				l_degree := 5
			elseif a_text.has_substring (Degree_6_marker) then
				l_degree := 6
			end

			a_result.set_highest_degree_completed (l_degree)
		end

feature {NONE} -- Mode Parsing

	parse_compilation_mode (a_text: STRING; a_result: SC_COMPILE_RESULT)
			-- Detect compilation mode from output.
		do
			if a_text.has_substring (Melting_system_marker) or a_text.has_substring (System_melted_marker) then
				a_result.set_compilation_mode (Mode_melt)
			elseif a_text.has_substring (Freezing_system_marker) or a_text.has_substring (System_frozen_marker) then
				a_result.set_compilation_mode (Mode_freeze)
			elseif a_text.has_substring (Finalizing_system_marker) or a_text.has_substring (System_finalized_marker) then
				a_result.set_compilation_mode (Mode_finalize)
			else
				a_result.set_compilation_mode (Mode_unknown)
			end
		end

feature {NONE} -- Status Parsing

	parse_system_status (a_text: STRING; a_result: SC_COMPILE_RESULT)
			-- Check for successful compilation markers.
		do
			a_result.set_system_recompiled (
				a_text.has_substring (System_recompiled_marker) or
				a_text.has_substring (System_up_to_date_marker)
			)
		end

feature {NONE} -- C Compilation Parsing

	parse_c_compilation (a_text: STRING; a_result: SC_COMPILE_RESULT)
			-- Parse C compilation status.
		do
			-- Check if C compilation was attempted
			a_result.set_c_compilation_attempted (
				a_text.has_substring (Preparing_c_compilation_marker) or
				a_text.has_substring (C_compilation_marker)
			)

			-- Check if C compilation completed
			a_result.set_c_compilation_completed (
				a_text.has_substring (C_compilation_completed_marker)
			)
		end

feature {NONE} -- Error Parsing

	parse_errors_from_lines (a_lines: LIST [STRING]; a_result: SC_COMPILE_RESULT)
			-- Parse error blocks from pre-split lines.
		local
			l_line: STRING
			i: INTEGER
			l_error: detachable SC_COMPILE_ERROR
			l_in_error_block: BOOLEAN
			l_error_text: STRING
		do
			create l_error_text.make_empty

			from i := 1 until i > a_lines.count loop
				l_line := a_lines.i_th (i)

				-- Detect start of error block
				if is_error_code_line (l_line) then
					-- Save previous error if any (and not already saved)
					if attached l_error as le and l_in_error_block then
						le.set_raw_text (l_error_text)
						a_result.add_error (le)
					end
					-- Start new error
					l_error := parse_error_line (l_line)
					l_in_error_block := True
					create l_error_text.make (256)
					l_error_text.append (l_line)
					l_error_text.append_character ('%N')
				elseif l_in_error_block and attached l_error as le then
					-- Continue accumulating error details
					l_error_text.append (l_line)
					l_error_text.append_character ('%N')

					-- Extract additional details from error block
					parse_error_details (l_line, le)

					-- Check for end of error block (blank line or new section)
					if l_line.is_empty or l_line.starts_with (Degree_marker_prefix) then
						le.set_raw_text (l_error_text)
						a_result.add_error (le)
						l_error := Void
						l_in_error_block := False
					end
				end

				i := i + 1
			end

			-- Save last error only if still in block (not already saved)
			if l_in_error_block and attached l_error as le then
				le.set_raw_text (l_error_text)
				a_result.add_error (le)
			end
		end

	is_error_code_line (a_line: STRING): BOOLEAN
			-- Does this line start an error block?
		do
			-- Match patterns like "Error code: VEEN" or "VEEN error"
			Result := a_line.has_substring (Error_code_marker) or
					  a_line.has_substring (Syntax_error_marker) or
					  a_line.has_substring (Validity_error_marker) or
					  (a_line.count >= 4 and then is_validity_code (a_line.substring (1, 4)))
		end

	is_validity_code (a_text: STRING): BOOLEAN
			-- Is this a validity error code (4 chars starting with V)?
		do
			Result := a_text.count >= 4 and then
					  a_text.item (1) = 'V' and then
					  a_text.item (2).is_upper and then
					  a_text.item (3).is_upper and then
					  (a_text.item (4).is_upper or a_text.item (4).is_digit)
		end

	parse_error_line (a_line: STRING): SC_COMPILE_ERROR
			-- Parse error code from line.
		local
			l_code: STRING
			l_pos: INTEGER
		do
			create Result.make
			create l_code.make_empty

			-- Try "Error code: XXXX" format
			l_pos := a_line.substring_index (Error_code_marker, 1)
			if l_pos > 0 then
				l_code := extract_word_after (a_line, l_pos + Error_code_marker.count)
			else
				-- Try to find validity code at start
				if a_line.count >= 4 and then is_validity_code (a_line.substring (1, 4)) then
					l_code := a_line.substring (1, 4)
				end
			end

			Result.set_error_code (l_code)
		ensure
			result_attached: Result /= Void
		end

	parse_error_details (a_line: STRING; a_error: SC_COMPILE_ERROR)
			-- Extract additional details from error block line.
		local
			l_pos: INTEGER
			l_class: STRING
			l_feature: STRING
			l_line_num: INTEGER
		do
			-- Look for class name: "Class: CLASS_NAME" or "in class CLASS_NAME"
			l_pos := a_line.substring_index ("Class:", 1)
			if l_pos > 0 then
				l_class := extract_word_after (a_line, l_pos + 6)
				if not l_class.is_empty then
					a_error.set_class_name (l_class.as_upper)
				end
			elseif a_line.has_substring ("in class") then
				l_pos := a_line.substring_index ("in class", 1)
				l_class := extract_word_after (a_line, l_pos + 8)
				if not l_class.is_empty then
					a_error.set_class_name (l_class.as_upper)
				end
			end

			-- Look for feature name: "Feature: feature_name" or "in feature `name'"
			l_pos := a_line.substring_index ("Feature:", 1)
			if l_pos > 0 then
				l_feature := extract_word_after (a_line, l_pos + 8)
				if not l_feature.is_empty then
					a_error.set_feature_name (l_feature)
				end
			elseif a_line.has_substring ("feature `") then
				l_pos := a_line.substring_index ("feature `", 1)
				l_feature := extract_quoted_identifier (a_line, l_pos + 9)
				if not l_feature.is_empty then
					a_error.set_feature_name (l_feature)
				end
			end

			-- Look for line number: "Line: 123" or "(line 123)"
			l_pos := a_line.substring_index ("Line:", 1)
			if l_pos > 0 then
				l_line_num := extract_integer_after (a_line, l_pos + 5)
				if l_line_num > 0 then
					a_error.set_line_number (l_line_num)
				end
			elseif a_line.has_substring ("(line") then
				l_pos := a_line.substring_index ("(line", 1)
				l_line_num := extract_integer_after (a_line, l_pos + 5)
				if l_line_num > 0 then
					a_error.set_line_number (l_line_num)
				end
			end

			-- Look for file path (contains .e extension)
			if a_line.has_substring (".e") then
				l_pos := find_file_path_start (a_line)
				if l_pos > 0 then
					a_error.set_file_path (extract_file_path (a_line, l_pos))
				end
			end

			-- Capture message lines (lines that don't start with known prefixes)
			if not a_line.is_empty and then
			   not a_line.starts_with ("Error") and then
			   not a_line.starts_with ("Class:") and then
			   not a_line.starts_with ("Feature:") and then
			   not a_line.starts_with ("Line:") and then
			   a_error.message.is_empty then
				a_error.set_message (a_line.twin)
			end
		end

feature {NONE} -- Warning Parsing

	parse_warnings_from_lines (a_lines: LIST [STRING]; a_result: SC_COMPILE_RESULT)
			-- Parse warning blocks from pre-split lines.
		local
			l_line: STRING
			i: INTEGER
			l_warning: SC_COMPILE_ERROR
		do
			from i := 1 until i > a_lines.count loop
				l_line := a_lines.i_th (i)

				if l_line.has_substring (Warning_marker) or l_line.has_substring (Warning_marker_lower) then
					create l_warning.make
					l_warning.set_is_warning (True)
					l_warning.set_error_code (Warning_code)
					l_warning.set_message (l_line)
					l_warning.set_raw_text (l_line)
					a_result.add_warning (l_warning)
				elseif l_line.has_substring (Obsolete_marker) then
					create l_warning.make
					l_warning.set_is_warning (True)
					l_warning.set_error_code (Obsolete_code)
					l_warning.set_message (l_line)
					l_warning.set_raw_text (l_line)
					a_result.add_warning (l_warning)
				end

				i := i + 1
			end
		end

feature {NONE} -- String Helpers

	extract_word_after (a_text: STRING; a_pos: INTEGER): STRING
			-- Extract word starting at position, skipping whitespace.
			-- Returns empty string if position invalid.
		local
			l_start, l_end: INTEGER
		do
			create Result.make_empty

			if a_pos >= 1 and a_pos <= a_text.count then
				-- Skip whitespace
				from l_start := a_pos until l_start > a_text.count or else not a_text.item (l_start).is_space loop
					l_start := l_start + 1
				end

				if l_start <= a_text.count then
					-- Find end of word
					from l_end := l_start until l_end > a_text.count or else not is_identifier_char (a_text.item (l_end)) loop
						l_end := l_end + 1
					end

					if l_end > l_start then
						Result := a_text.substring (l_start, l_end - 1)
					end
				end
			end
		ensure
			result_attached: Result /= Void
		end

	extract_quoted_identifier (a_text: STRING; a_pos: INTEGER): STRING
			-- Extract identifier until closing quote or apostrophe.
			-- Returns empty string if position invalid.
		local
			l_end: INTEGER
		do
			create Result.make_empty

			if a_pos >= 1 and a_pos <= a_text.count then
				from l_end := a_pos until l_end > a_text.count or else (a_text.item (l_end) = '%'' or a_text.item (l_end) = '`') loop
					l_end := l_end + 1
				end

				if l_end > a_pos then
					Result := a_text.substring (a_pos, l_end - 1)
				end
			end
		ensure
			result_attached: Result /= Void
		end

	extract_integer_after (a_text: STRING; a_pos: INTEGER): INTEGER
			-- Extract integer starting at position.
			-- Returns 0 if position invalid or no integer found.
		local
			l_start, l_end: INTEGER
			l_num_str: STRING
		do
			if a_pos >= 1 and a_pos <= a_text.count then
				-- Skip whitespace
				from l_start := a_pos until l_start > a_text.count or else not a_text.item (l_start).is_space loop
					l_start := l_start + 1
				end

				if l_start <= a_text.count and then a_text.item (l_start).is_digit then
					from l_end := l_start until l_end > a_text.count or else not a_text.item (l_end).is_digit loop
						l_end := l_end + 1
					end

					l_num_str := a_text.substring (l_start, l_end - 1)
					if l_num_str.is_integer then
						Result := l_num_str.to_integer
					end
				end
			end
		end

	find_file_path_start (a_line: STRING): INTEGER
			-- Find start of file path in line (looks for drive letter or slash).
			-- Returns 0 if no path found.
		local
			i: INTEGER
			l_found: BOOLEAN
		do
			-- Look for Windows path (C:\...)
			from i := 1 until i > a_line.count - 2 or l_found loop
				if a_line.item (i).is_alpha and then
				   a_line.item (i + 1) = ':' and then
				   a_line.item (i + 2) = '\' then
					Result := i
					l_found := True
				end
				i := i + 1
			end

			-- Look for Unix path (/...) if no Windows path found
			if not l_found then
				from i := 1 until i > a_line.count or l_found loop
					if a_line.item (i) = '/' and then
					   (i = 1 or else a_line.item (i - 1).is_space) then
						Result := i
						l_found := True
					end
					i := i + 1
				end
			end
		end

	extract_file_path (a_line: STRING; a_start: INTEGER): STRING
			-- Extract file path starting at position.
		local
			l_end: INTEGER
		do
			from l_end := a_start until l_end > a_line.count or else is_path_terminator (a_line.item (l_end)) loop
				l_end := l_end + 1
			end

			Result := a_line.substring (a_start, l_end - 1)
		end

	is_identifier_char (c: CHARACTER): BOOLEAN
			-- Is character valid in identifier?
		do
			Result := c.is_alpha or c.is_digit or c = '_'
		end

	is_path_terminator (c: CHARACTER): BOOLEAN
			-- Is character a path terminator?
		do
			Result := c.is_space or c = '(' or c = ')' or c = ':' or c = '%N' or c = '%R'
		end

feature {NONE} -- Constants: Degree Markers

	Degree_marker_prefix: STRING = "Degree"
	Degree_6_marker: STRING = "Degree 6"
	Degree_5_marker: STRING = "Degree 5"
	Degree_4_marker: STRING = "Degree 4"
	Degree_3_marker: STRING = "Degree 3"
	Degree_2_marker: STRING = "Degree 2"
	Degree_1_marker: STRING = "Degree 1"
	Degree_minus_1_marker: STRING = "Degree -1"

feature {NONE} -- Constants: Compilation Mode Markers

	Melting_system_marker: STRING = "Melting System"
	System_melted_marker: STRING = "System Melted"
	Freezing_system_marker: STRING = "Freezing System"
	System_frozen_marker: STRING = "System Frozen"
	Finalizing_system_marker: STRING = "Finalizing System"
	System_finalized_marker: STRING = "System Finalized"

	Mode_melt: STRING = "melt"
	Mode_freeze: STRING = "freeze"
	Mode_finalize: STRING = "finalize"
	Mode_unknown: STRING = "unknown"

feature {NONE} -- Constants: Status Markers

	System_recompiled_marker: STRING = "System Recompiled"
	System_up_to_date_marker: STRING = "System is up to date"

feature {NONE} -- Constants: C Compilation Markers

	Preparing_c_compilation_marker: STRING = "Preparing C compilation"
	C_compilation_marker: STRING = "C compilation"
	C_compilation_completed_marker: STRING = "C compilation completed"

feature {NONE} -- Constants: Error Markers

	Error_code_marker: STRING = "Error code:"
	Syntax_error_marker: STRING = "Syntax error"
	Validity_error_marker: STRING = "Validity error"

feature {NONE} -- Constants: Warning Markers

	Warning_marker: STRING = "Warning:"
	Warning_marker_lower: STRING = "warning:"
	Obsolete_marker: STRING = "Obsolete"
	Warning_code: STRING = "WARNING"
	Obsolete_code: STRING = "OBSOLETE"

end
