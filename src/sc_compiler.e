note
	description: "[
		Eiffel Compiler Wrapper for Simple Ecosystem

		Replicates ec.sh functionality in Eiffel code using SIMPLE_PROCESS.

		MODES:
		  check   - Melt only (fast syntax/type check, no C compile)
		  test    - Finalize with -keep (DBC baked in, for test runners)
		  release - Finalize BOTH lean (no DBC) and fat (-keep) binaries
		  freeze  - Traditional W_code freeze (legacy, avoid)

		USAGE:
		  create compiler.make ("lib.ecf", "lib_tests")
		  compiler.compile_test
		  if compiler.is_compiled then
		    print (compiler.exe_path)
		  else
		    print (compiler.last_error)
		  end

		FLUENT API:
		  create compiler.make ("lib.ecf", "lib_tests")
		  compiler.set_working_directory ("/path/to/project")
		  compiler.set_verbose (True)
		  compiler.compile_test
		]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SC_COMPILER

create
	make

feature {NONE} -- Initialization

	make (a_ecf_path: STRING; a_target: STRING)
			-- Create compiler for `a_ecf_path' with `a_target'.
		require
			ecf_not_empty: not a_ecf_path.is_empty
			ecf_is_ecf_file: a_ecf_path.ends_with (".ecf")
			target_not_empty: not a_target.is_empty
		local
			l_env: SIMPLE_ENV
		do
			ecf_path := a_ecf_path
			target := a_target
			create last_output.make_empty
			create last_error.make_empty
			create working_directory.make_empty

			-- Get EiffelStudio paths from environment variables
			create l_env
			if attached l_env.get ("ISE_EIFFEL") as l_ise then
				ise_eiffel := l_ise.to_string_8
			else
				ise_eiffel := "C:\Program Files\Eiffel Software\EiffelStudio 25.02 Standard"
			end
			if attached l_env.get ("ISE_PLATFORM") as l_plat then
				ise_platform := l_plat.to_string_8
			else
				ise_platform := "win64"
			end
		ensure
			ecf_set: ecf_path.same_string (a_ecf_path)
			target_set: target.same_string (a_target)
			no_compilation_yet: last_result = Void
			initially_not_compiled: not is_compiled
			no_errors_yet: last_error.is_empty
			exit_code_zero: last_exit_code = 0
		end

feature -- Access

	ecf_path: STRING
			-- Path to the ECF configuration file

	target: STRING
			-- Target name to compile

	working_directory: STRING
			-- Working directory for compilation (empty = current directory)

	ise_eiffel: STRING
			-- Path to EiffelStudio installation

	ise_platform: STRING
			-- Platform identifier (e.g., "win64")

	last_output: STRING
			-- Output from last compilation

	last_error: STRING
			-- Error message from last compilation (empty if successful)

	last_exit_code: INTEGER
			-- Exit code from last compilation

	last_result: detachable SC_COMPILE_RESULT
			-- Parsed result from last compilation (Void until first compilation)

feature -- Status

	is_compiled: BOOLEAN
			-- Was last compilation successful?

	is_verbose: BOOLEAN
			-- Print verbose output during compilation?

feature -- Compilation Modes

	compile_check
			-- Melt only - quick syntax/type check, no C compile.
		do
			reset_state
			run_ec_with_args ("-batch -config %"" + ecf_path + "%" -target " + target)
		ensure
			result_available: attached last_result
		end

	compile_test
			-- Finalize with -keep - DBC baked into native code.
		do
			reset_state
			run_ec_with_args ("-batch -config %"" + ecf_path + "%" -target " + target + " -finalize -keep -c_compile")
			if is_compiled then
				verify_binary (f_code_path)
			end
		ensure
			result_available: attached last_result
		end

	compile_release
			-- Build lean (no DBC) then fat (-keep) binary.
			-- Note: Fat binary overwrites lean in F_code. Final binary has DBC.
		do
			reset_state

			-- First: Build lean (no DBC)
			if is_verbose then
				print ("--- Building LEAN binary (no DBC) ---%N")
			end
			run_ec_with_args ("-batch -config %"" + ecf_path + "%" -target " + target + " -finalize -c_compile")

			if is_compiled then
				-- Second: Build fat (with DBC via -keep) - overwrites lean
				if is_verbose then
					print ("--- Building FAT binary (with DBC) ---%N")
				end
				run_ec_with_args ("-batch -config %"" + ecf_path + "%" -target " + target + " -finalize -keep -c_compile")

				if is_compiled then
					verify_binary (f_code_path)
				end
			end
		ensure
			result_available: attached last_result
		end

	compile_freeze
			-- Traditional W_code freeze (legacy - prefer compile_test).
		do
			reset_state
			run_ec_with_args ("-batch -config %"" + ecf_path + "%" -target " + target + " -c_compile")
			if is_compiled then
				verify_binary (w_code_path)
			end
		ensure
			result_available: attached last_result
		end

	compile_raw (a_args: STRING)
			-- Pure passthrough - escape hatch for special cases.
		require
			args_not_empty: not a_args.is_empty
		do
			reset_state
			run_ec_with_args (a_args)
		ensure
			result_available: attached last_result
		end

feature -- Paths

	eifgens_path: STRING
			-- Path to EIFGENs directory for current target.
		do
			if working_directory.is_empty then
				Result := "EIFGENs\" + target
			else
				Result := working_directory + "\EIFGENs\" + target
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	f_code_path: STRING
			-- Path to F_code directory (finalized code).
		do
			Result := eifgens_path + "\F_code"
		ensure
			result_not_empty: not Result.is_empty
		end

	w_code_path: STRING
			-- Path to W_code directory (workbench code).
		do
			Result := eifgens_path + "\W_code"
		ensure
			result_not_empty: not Result.is_empty
		end

	exe_path: STRING
			-- Path to compiled executable (searches F_code first, then W_code).
		do
			Result := find_exe_in (f_code_path)
			if Result.is_empty then
				Result := find_exe_in (w_code_path)
			end
		end

	ec_exe_path: STRING
			-- Full path to ec.exe compiler.
		do
			Result := ise_eiffel + "\studio\spec\" + ise_platform + "\bin\ec.exe"
		end

	finish_freezing_path: STRING
			-- Full path to finish_freezing.exe.
		do
			Result := ise_eiffel + "\studio\spec\" + ise_platform + "\bin\finish_freezing.exe"
		end

feature -- Configuration (Fluent API)

	set_working_directory (a_path: STRING): like Current
			-- Set working directory for compilation.
			-- Pass empty string to use current directory.
		do
			working_directory := a_path
			Result := Current
		ensure
			directory_set: working_directory.same_string (a_path)
			result_is_current: Result = Current
		end

	set_verbose (a_verbose: BOOLEAN): like Current
			-- Enable or disable verbose output.
		do
			is_verbose := a_verbose
			Result := Current
		ensure
			verbose_set: is_verbose = a_verbose
			result_is_current: Result = Current
		end

	set_ise_eiffel (a_path: STRING): like Current
			-- Set EiffelStudio installation path.
		require
			path_not_empty: not a_path.is_empty
		do
			ise_eiffel := a_path
			Result := Current
		ensure
			path_set: ise_eiffel.same_string (a_path)
			result_is_current: Result = Current
		end

	set_ise_platform (a_platform: STRING): like Current
			-- Set platform identifier.
		require
			platform_not_empty: not a_platform.is_empty
		do
			ise_platform := a_platform
			Result := Current
		ensure
			platform_set: ise_platform.same_string (a_platform)
			result_is_current: Result = Current
		end

feature {NONE} -- Implementation

	reset_state
			-- Reset compilation state before new compilation.
		do
			is_compiled := False
			last_output.wipe_out
			last_error.wipe_out
			last_exit_code := 0
			last_result := Void
		ensure
			not_compiled: not is_compiled
			output_cleared: last_output.is_empty
			error_cleared: last_error.is_empty
			exit_code_zero: last_exit_code = 0
			no_result: last_result = Void
		end

	run_ec_with_args (a_args: STRING)
			-- Run ec.exe with given arguments string.
		require
			args_not_empty: not a_args.is_empty
		local
			l_proc: SIMPLE_PROCESS
			l_cmd: STRING
			l_proc_error: STRING
			l_parser: SC_OUTPUT_PARSER
		do
			create l_cmd.make (256)
			l_cmd.append_character ('%"')
			l_cmd.append (ec_exe_path)
			l_cmd.append ("%" ")
			l_cmd.append (a_args)

			if is_verbose then
				print ("Running: " + l_cmd + "%N")
			end

			create l_proc.make

			if working_directory.is_empty then
				l_proc.execute (l_cmd)
			else
				l_proc.execute_in_directory (l_cmd, working_directory)
			end

			last_exit_code := l_proc.exit_code

			if attached l_proc.output as l_out then
				last_output := l_out.to_string_8
			else
				last_output.wipe_out
			end

			-- Capture process error separately
			create l_proc_error.make_empty
			if attached l_proc.last_error as l_err then
				l_proc_error := l_err.to_string_8
			end

			-- Parse output into structured result
			create l_parser
			last_result := l_parser.parse (last_output, l_proc_error, last_exit_code)

			if l_proc.was_successful then
				is_compiled := True
			else
				is_compiled := False
				last_error := "Compilation failed with exit code " + last_exit_code.out
				if not l_proc_error.is_empty then
					last_error.append ("%N" + l_proc_error)
				end
			end
		ensure
			result_created: attached last_result
			result_exit_code_matches: attached last_result as r implies r.exit_code = last_exit_code
			failure_has_error: not is_compiled implies not last_error.is_empty
		end

	run_finish_freezing (a_code_dir: STRING)
			-- Run finish_freezing in the specified code directory.
			-- Note: Called manually for freeze scenarios requiring separate C compilation.
		require
			dir_not_empty: not a_code_dir.is_empty
		local
			l_proc: SIMPLE_PROCESS
			l_cmd: STRING
		do
			create l_cmd.make (256)
			l_cmd.append_character ('%"')
			l_cmd.append (finish_freezing_path)
			l_cmd.append ("%" -silent")

			if is_verbose then
				print ("Running finish_freezing in: " + a_code_dir + "%N")
			end

			create l_proc.make
			l_proc.execute_in_directory (l_cmd, a_code_dir)

			if not l_proc.was_successful then
				is_compiled := False
				last_error := "finish_freezing failed with exit code " + l_proc.exit_code.out
			end
		end

	verify_binary (a_code_path: STRING)
			-- Verify that a binary was built in `a_code_path'.
		require
			path_not_empty: not a_code_path.is_empty
		local
			l_dir: SIMPLE_FILE
			l_exe: STRING
		do
			create l_dir.make (a_code_path)

			if not l_dir.exists then
				is_compiled := False
				last_error := "ERROR: " + a_code_path + " does not exist - compilation failed!"
			else
				l_exe := find_exe_in (a_code_path)
				if l_exe.is_empty then
					is_compiled := False
					last_error := "ERROR: No .exe found in " + a_code_path
				elseif is_verbose then
					print ("Built: " + l_exe + "%N")
				end
			end
		end

	find_exe_in (a_dir: STRING): STRING
			-- Find first .exe file in `a_dir'. Returns empty string if none found.
		require
			dir_not_empty: not a_dir.is_empty
		local
			l_files: SIMPLE_FILES
			l_entries: ARRAYED_LIST [STRING_32]
			i: INTEGER
			l_found: BOOLEAN
		do
			create Result.make_empty
			create l_files

			l_entries := l_files.list_files (a_dir)
			from i := 1 until i > l_entries.count or l_found loop
				if l_entries.i_th (i).ends_with (".exe") then
					Result := a_dir + "\" + l_entries.i_th (i).to_string_8
					l_found := True
				end
				i := i + 1
			end
		end

invariant
	-- Configuration validity
	ecf_path_valid: not ecf_path.is_empty and ecf_path.ends_with (".ecf")
	target_not_empty: not target.is_empty
	ise_eiffel_not_empty: not ise_eiffel.is_empty
	ise_platform_not_empty: not ise_platform.is_empty

	-- Compilation state consistency: if we have a result, exit codes must match
	result_exit_code_consistent: attached last_result as r implies r.exit_code = last_exit_code

	-- Error state semantics: failure implies error message exists
	failure_implies_error: (attached last_result and not is_compiled) implies not last_error.is_empty

	-- Success state semantics: success implies no error message
	success_implies_no_error: is_compiled implies last_error.is_empty

end
