note
	description: "[
		Parsed compilation result from EiffelStudio ec.exe.

		Provides structured access to:
		- Raw output and error strings
		- Compilation progress (degrees completed)
		- Individual errors with codes, locations, messages
		- Warnings
		- Compilation mode and C compilation status
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SC_COMPILE_RESULT

create
	make

feature {NONE} -- Initialization

	make
			-- Create empty result.
		do
			create raw_output.make_empty
			create raw_error.make_empty
			create errors.make (0)
			create warnings.make (0)
			create compilation_mode.make_empty
			highest_degree_completed := -1
		ensure
			not_success: not is_success
			no_errors: errors.is_empty
			no_warnings: warnings.is_empty
		end

feature -- Raw Data

	raw_output: STRING
			-- Raw stdout from ec.exe

	raw_error: STRING
			-- Raw stderr from ec.exe

feature -- Status

	is_success: BOOLEAN
			-- Did compilation complete successfully?

	exit_code: INTEGER
			-- Process exit code

	highest_degree_completed: INTEGER
			-- Highest degree that completed (6=examining, 5=parsing, 4=inheritance, 3=types, 2=bytecode, 1=metadata, 0=done)
			-- -1 means no degrees completed

	is_system_recompiled: BOOLEAN
			-- Was "System Recompiled" message seen?

	is_c_compilation_completed: BOOLEAN
			-- Did C compilation complete?

	is_c_compilation_attempted: BOOLEAN
			-- Was C compilation attempted?

feature -- Compilation Info

	compilation_mode: STRING
			-- Detected mode: "melt", "freeze", "finalize", or "unknown"

feature -- Errors

	errors: ARRAYED_LIST [SC_COMPILE_ERROR]
			-- List of compilation errors

	warnings: ARRAYED_LIST [SC_COMPILE_ERROR]
			-- List of compilation warnings

	has_errors: BOOLEAN
			-- Are there any errors?
		do
			Result := not errors.is_empty
		end

	has_warnings: BOOLEAN
			-- Are there any warnings?
		do
			Result := not warnings.is_empty
		end

	error_count: INTEGER
			-- Number of errors
		do
			Result := errors.count
		end

	warning_count: INTEGER
			-- Number of warnings
		do
			Result := warnings.count
		end

	first_error: detachable SC_COMPILE_ERROR
			-- First error, if any
		do
			if not errors.is_empty then
				Result := errors.first
			end
		end

	errors_by_code (a_code: STRING): ARRAYED_LIST [SC_COMPILE_ERROR]
			-- All errors with given error code (e.g., "VEEN", "VUAR")
		require
			code_not_empty: not a_code.is_empty
		do
			create Result.make (5)
			across errors as err loop
				if err.error_code.same_string (a_code) then
					Result.extend (err)
				end
			end
		ensure
			result_attached: Result /= Void
		end

	errors_in_class (a_class: STRING): ARRAYED_LIST [SC_COMPILE_ERROR]
			-- All errors in given class
		require
			class_not_empty: not a_class.is_empty
		local
			l_upper: STRING
		do
			l_upper := a_class.as_upper
			create Result.make (5)
			across errors as err loop
				if err.class_name.same_string (l_upper) then
					Result.extend (err)
				end
			end
		ensure
			result_attached: Result /= Void
		end

feature -- Summary

	summary: STRING
			-- Human-readable summary of result
		do
			create Result.make (256)
			if is_success then
				Result.append ("Compilation successful")
				if is_system_recompiled then
					Result.append (" (System Recompiled)")
				end
				if is_c_compilation_completed then
					Result.append (" + C compilation")
				end
			else
				Result.append ("Compilation failed")
				if not errors.is_empty then
					Result.append (" with " + error_count.out + " error(s)")
				end
			end
			if not warnings.is_empty then
				Result.append (", " + warning_count.out + " warning(s)")
			end
			Result.append (" [Mode: " + compilation_mode + ", Degree: " + highest_degree_completed.out + "]")
		ensure
			result_not_empty: not Result.is_empty
		end

	error_summary: STRING
			-- Summary of all errors
		do
			create Result.make (512)
			across errors as err loop
				Result.append (err.one_line_summary)
				Result.append_character ('%N')
			end
		ensure
			result_attached: Result /= Void
		end

feature {SC_OUTPUT_PARSER} -- Modification (for parser)

	set_raw_output (a_output: STRING)
		do
			raw_output := a_output
		ensure
			output_set: raw_output = a_output
		end

	set_raw_error (a_error: STRING)
		do
			raw_error := a_error
		ensure
			error_set: raw_error = a_error
		end

	set_is_success (a_value: BOOLEAN)
		do
			is_success := a_value
		ensure
			success_set: is_success = a_value
		end

	set_exit_code (a_code: INTEGER)
		do
			exit_code := a_code
		ensure
			code_set: exit_code = a_code
		end

	set_highest_degree_completed (a_degree: INTEGER)
		do
			highest_degree_completed := a_degree
		ensure
			degree_set: highest_degree_completed = a_degree
		end

	set_system_recompiled (a_value: BOOLEAN)
		do
			is_system_recompiled := a_value
		ensure
			recompiled_set: is_system_recompiled = a_value
		end

	set_c_compilation_completed (a_value: BOOLEAN)
		do
			is_c_compilation_completed := a_value
		ensure
			completed_set: is_c_compilation_completed = a_value
		end

	set_c_compilation_attempted (a_value: BOOLEAN)
		do
			is_c_compilation_attempted := a_value
		ensure
			attempted_set: is_c_compilation_attempted = a_value
		end

	set_compilation_mode (a_mode: STRING)
		do
			compilation_mode := a_mode
		ensure
			mode_set: compilation_mode = a_mode
		end

	add_error (a_error: SC_COMPILE_ERROR)
		do
			errors.extend (a_error)
		ensure
			error_added: errors.has (a_error)
			count_increased: errors.count = old errors.count + 1
		end

	add_warning (a_warning: SC_COMPILE_ERROR)
		do
			warnings.extend (a_warning)
		ensure
			warning_added: warnings.has (a_warning)
			count_increased: warnings.count = old warnings.count + 1
		end

invariant
	degree_valid: highest_degree_completed >= -1 and highest_degree_completed <= 6
	error_count_consistent: error_count = errors.count
	warning_count_consistent: warning_count = warnings.count

end
