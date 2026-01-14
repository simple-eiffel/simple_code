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
	author: "Larry Reid"
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
			target_not_empty: not a_target.is_empty
		do
			ecf_path := a_ecf_path
			target := a_target
			create last_output.make_empty
			create last_error.make_empty
			create working_directory.make_empty

			-- Default EiffelStudio paths (Windows)
			ise_eiffel := "C:\Program Files\Eiffel Software\EiffelStudio 25.02 Standard"
			ise_platform := "win64"
		ensure
			ecf_set: ecf_path.same_string (a_ecf_path)
			target_set: target.same_string (a_target)
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
		end

	compile_test
			-- Finalize with -keep - DBC baked into native code.
		do
			reset_state
			run_ec_with_args ("-batch -config %"" + ecf_path + "%" -target " + target + " -finalize -keep -c_compile")
			if is_compiled then
				verify_binary (f_code_path)
			end
		end

	compile_release
			-- Build BOTH lean (no DBC) and fat (-keep) binaries.
		do
			reset_state

			-- First: Build lean (no DBC)
			if is_verbose then
				print ("--- Building LEAN binary (no DBC) ---%N")
			end
			run_ec_with_args ("-batch -config %"" + ecf_path + "%" -target " + target + " -finalize -c_compile")

			if is_compiled then
				-- Second: Build fat (with DBC via -keep)
				if is_verbose then
					print ("--- Building FAT binary (with DBC) ---%N")
				end
				run_ec_with_args ("-batch -config %"" + ecf_path + "%" -target " + target + " -finalize -keep -c_compile")

				if is_compiled then
					verify_binary (f_code_path)
				end
			end
		end

	compile_freeze
			-- Traditional W_code freeze (legacy - prefer compile_test).
		do
			reset_state
			run_ec_with_args ("-batch -config %"" + ecf_path + "%" -target " + target + " -c_compile")
			if is_compiled then
				verify_binary (w_code_path)
			end
		end

	compile_raw (a_args: STRING)
			-- Pure passthrough - escape hatch for special cases.
		require
			args_not_empty: not a_args.is_empty
		do
			reset_state
			run_ec_with_args (a_args)
		end

feature -- Paths

	eifgens_path: STRING
			-- Path to EIFGENs directory for current target.
		do
			if working_directory.is_empty then
				Result := "EIFGENs/" + target
			else
				Result := working_directory + "/EIFGENs/" + target
			end
		end

	f_code_path: STRING
			-- Path to F_code directory (finalized code).
		do
			Result := eifgens_path + "/F_code"
		end

	w_code_path: STRING
			-- Path to W_code directory (workbench code).
		do
			Result := eifgens_path + "/W_code"
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
		require
			path_not_void: a_path /= Void
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
		end

	run_ec_with_args (a_args: STRING)
			-- Run ec.exe with given arguments string.
		local
			l_proc: SIMPLE_PROCESS
			l_cmd: STRING
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

			if l_proc.was_successful then
				is_compiled := True
			else
				is_compiled := False
				last_error := "Compilation failed with exit code " + last_exit_code.out
				if attached l_proc.last_error as l_err then
					last_error.append ("%N" + l_err.to_string_8)
				end
			end
		end

	run_finish_freezing (a_code_dir: STRING)
			-- Run finish_freezing in the specified code directory.
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
		local
			l_files: SIMPLE_FILES
			l_entries: ARRAYED_LIST [STRING_32]
			i: INTEGER
		do
			create Result.make_empty
			create l_files

			l_entries := l_files.list_files (a_dir)
			from i := 1 until i > l_entries.count loop
				if l_entries.i_th (i).ends_with (".exe") then
					Result := a_dir + "/" + l_entries.i_th (i).to_string_8
				end
				i := i + 1
			end
		end

invariant
	ecf_not_empty: not ecf_path.is_empty
	target_not_empty: not target.is_empty

end
