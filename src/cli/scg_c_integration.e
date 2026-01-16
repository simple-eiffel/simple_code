note
	description: "[
		C/C++ Integration Facade for Eiffel Code Generation.

		Provides knowledge and patterns for:
		- Inline C externals (Eric Bezault pattern)
		- External C/C++ library integration
		- Win32 API wrapping
		- Memory management across language boundary
		- ECF configuration for C libraries

		Key Principles:
		1. ALL C code goes in inline externals - NO separate .c files
		2. Use MANAGED_POINTER for memory that crosses boundaries
		3. Wrap C functions with Eiffel contracts
		4. Handle NULL checks with void safety patterns
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_C_INTEGRATION

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize C integration helper.
		do
			create inline_c_builder.make
			create library_config.make
		end

feature -- Access

	inline_c_builder: SCG_INLINE_C_BUILDER
			-- Helper for building inline C externals

	library_config: SCG_C_LIBRARY_CONFIG
			-- Helper for ECF library configuration

feature -- Inline C Patterns

	inline_c_template (a_eiffel_name: STRING; a_return_type: STRING; a_c_code: STRING; a_includes: detachable ARRAYED_LIST [STRING]): STRING
			-- Generate inline C external template.
		require
			name_not_empty: not a_eiffel_name.is_empty
			code_not_empty: not a_c_code.is_empty
		do
			Result := inline_c_builder.build_inline_external (a_eiffel_name, a_return_type, a_c_code, a_includes)
		ensure
			result_not_empty: not Result.is_empty
		end

	inline_c_with_args_template (a_eiffel_name: STRING; a_args: ARRAYED_LIST [TUPLE [name: STRING; eiffel_type: STRING; c_type: STRING]]; a_return_type: STRING; a_c_code: STRING; a_includes: detachable ARRAYED_LIST [STRING]): STRING
			-- Generate inline C external with arguments.
		require
			name_not_empty: not a_eiffel_name.is_empty
			code_not_empty: not a_c_code.is_empty
		do
			Result := inline_c_builder.build_inline_external_with_args (a_eiffel_name, a_args, a_return_type, a_c_code, a_includes)
		ensure
			result_not_empty: not Result.is_empty
		end

feature -- Type Mapping

	c_to_eiffel_type (a_c_type: STRING): STRING
			-- Map C type to Eiffel type.
		require
			type_not_empty: not a_c_type.is_empty
		do
			Result := inline_c_builder.map_c_to_eiffel (a_c_type)
		end

	eiffel_to_c_type (a_eiffel_type: STRING): STRING
			-- Map Eiffel type to C type.
		require
			type_not_empty: not a_eiffel_type.is_empty
		do
			Result := inline_c_builder.map_eiffel_to_c (a_eiffel_type)
		end

feature -- Common Patterns

	win32_api_pattern: STRING
			-- Pattern for wrapping Win32 API calls.
		once
			create Result.make (500)
			Result.append ("  feature_name (a_arg: TYPE): RETURN_TYPE%N")
			Result.append ("      -- Description of Win32 API wrapper.%N")
			Result.append ("    require%N")
			Result.append ("      valid_arg: -- precondition%N")
			Result.append ("    external%N")
			Result.append ("      %"C inline use <windows.h>%"%N")
			Result.append ("    alias%N")
			Result.append ("      %"[ // Cast, call Win32Function, return (EIF_TYPE)result; ]%"%N")
			Result.append ("    ensure%N")
			Result.append ("      -- postcondition%N")
			Result.append ("    end%N")
		end

	memory_allocation_pattern: STRING
			-- Pattern for C memory allocation with Eiffel management.
		once
			create Result.make (800)
			Result.append ("  allocate_buffer (a_size: INTEGER): MANAGED_POINTER%N")
			Result.append ("      -- Allocate C buffer of `a_size' bytes.%N")
			Result.append ("    require%N")
			Result.append ("      positive_size: a_size > 0%N")
			Result.append ("    do%N")
			Result.append ("      create Result.make (a_size)%N")
			Result.append ("    ensure%N")
			Result.append ("      allocated: Result /= Void%N")
			Result.append ("      correct_size: Result.count = a_size%N")
			Result.append ("    end%N%N")
			Result.append ("  c_allocate (a_size: INTEGER): POINTER%N")
			Result.append ("      -- Allocate via C malloc.%N")
			Result.append ("    external%N")
			Result.append ("      %"C inline use <stdlib.h>%"%N")
			Result.append ("    alias%N")
			Result.append ("      %"return malloc((size_t)$a_size);%"%N")
			Result.append ("    end%N%N")
			Result.append ("  c_free (a_ptr: POINTER)%N")
			Result.append ("      -- Free C-allocated memory.%N")
			Result.append ("    external%N")
			Result.append ("      %"C inline use <stdlib.h>%"%N")
			Result.append ("    alias%N")
			Result.append ("      %"free($a_ptr);%"%N")
			Result.append ("    end%N")
		end

	string_conversion_pattern: STRING
			-- Pattern for string conversion between Eiffel and C.
		once
			create Result.make (800)
			Result.append ("  -- Eiffel STRING to C char*%N")
			Result.append ("  eiffel_string_to_c (a_string: STRING): POINTER%N")
			Result.append ("    local%N")
			Result.append ("      l_c_string: C_STRING%N")
			Result.append ("    do%N")
			Result.append ("      create l_c_string.make (a_string)%N")
			Result.append ("      Result := l_c_string.item%N")
			Result.append ("    end%N%N")
			Result.append ("  -- C char* to Eiffel STRING%N")
			Result.append ("  c_string_to_eiffel (a_ptr: POINTER): STRING%N")
			Result.append ("    local%N")
			Result.append ("      l_c_string: C_STRING%N")
			Result.append ("    do%N")
			Result.append ("      create l_c_string.make_by_pointer (a_ptr)%N")
			Result.append ("      Result := l_c_string.string%N")
			Result.append ("    end%N%N")
			Result.append ("  -- Wide strings: use WEL_STRING for LPWSTR%N")
		end

	callback_pattern: STRING
			-- Pattern for C callbacks to Eiffel.
		once
			create Result.make (500)
			Result.append ("  callback_agent: detachable PROCEDURE [TUPLE [arg: INTEGER]]%N%N")
			Result.append ("  set_callback (a_agent: PROCEDURE [TUPLE [arg: INTEGER]])%N")
			Result.append ("    do%N")
			Result.append ("      callback_agent := a_agent%N")
			Result.append ("    ensure%N")
			Result.append ("      callback_set: callback_agent = a_agent%N")
			Result.append ("    end%N%N")
			Result.append ("  -- For C callbacks, see WEL library patterns%N")
		end

	error_handling_pattern: STRING
			-- Pattern for C error handling in Eiffel.
		once
			create Result.make (600)
			Result.append ("  last_c_error: INTEGER%N%N")
			Result.append ("  c_get_errno: INTEGER%N")
			Result.append ("    external%N")
			Result.append ("      %"C inline use <errno.h>%"%N")
			Result.append ("    alias%N")
			Result.append ("      %"return errno;%"%N")
			Result.append ("    end%N%N")
			Result.append ("  win32_get_last_error: INTEGER%N")
			Result.append ("    external%N")
			Result.append ("      %"C inline use <windows.h>%"%N")
			Result.append ("    alias%N")
			Result.append ("      %"return (EIF_INTEGER)GetLastError();%"%N")
			Result.append ("    end%N")
		end

feature -- Integration Checklist

	integration_checklist: STRING
			-- Checklist for C/C++ integration.
		once
			create Result.make (1500)
			Result.append ("=== C/C++ INTEGRATION CHECKLIST ===%N%N")
			Result.append ("BEFORE STARTING:%N")
			Result.append ("[ ] Identify all C functions to wrap%N")
			Result.append ("[ ] Document memory ownership (who allocates, who frees)%N")
			Result.append ("[ ] List all required headers%N")
			Result.append ("[ ] Check platform compatibility (Windows/Linux/Mac)%N%N")
			Result.append ("ECF CONFIGURATION:%N")
			Result.append ("[ ] Add external_include for header paths%N")
			Result.append ("[ ] Add external_library for .lib/.a files%N")
			Result.append ("[ ] Add external_object for .obj/.o files (if needed)%N")
			Result.append ("[ ] Set correct platform conditions%N%N")
			Result.append ("INLINE C EXTERNALS:%N")
			Result.append ("[ ] Use 'external %"C inline use <header.h>%"' pattern%N")
			Result.append ("[ ] NO separate .c files - all C in Eiffel externals%N")
			Result.append ("[ ] Include all needed headers in 'use' clause%N")
			Result.append ("[ ] Cast Eiffel types to C types explicitly%N%N")
			Result.append ("TYPE MAPPING:%N")
			Result.append ("[ ] INTEGER -> int, EIF_INTEGER%N")
			Result.append ("[ ] INTEGER_64 -> long long, EIF_INTEGER_64%N")
			Result.append ("[ ] REAL_64 -> double, EIF_REAL_64%N")
			Result.append ("[ ] POINTER -> void*, EIF_POINTER%N")
			Result.append ("[ ] BOOLEAN -> int (0/1), EIF_BOOLEAN%N")
			Result.append ("[ ] STRING -> char* via C_STRING%N")
			Result.append ("[ ] STRING_32 -> wchar_t* via WEL_STRING (Windows)%N%N")
			Result.append ("MEMORY MANAGEMENT:%N")
			Result.append ("[ ] Use MANAGED_POINTER for Eiffel-owned buffers%N")
			Result.append ("[ ] Pair every malloc with free%N")
			Result.append ("[ ] Document who owns allocated memory%N")
			Result.append ("[ ] Use dispose pattern for C resources%N%N")
			Result.append ("CONTRACTS:%N")
			Result.append ("[ ] Preconditions: validate pointers not null%N")
			Result.append ("[ ] Preconditions: validate buffer sizes%N")
			Result.append ("[ ] Postconditions: check return values%N")
			Result.append ("[ ] Handle C errors (errno, GetLastError)%N%N")
			Result.append ("TESTING:%N")
			Result.append ("[ ] Test with assertions enabled (-keep)%N")
			Result.append ("[ ] Test memory with valgrind/Dr. Memory%N")
			Result.append ("[ ] Test on all target platforms%N")
		end

feature -- Documentation

	eric_bezault_pattern_doc: STRING
			-- Documentation of Eric Bezault's inline C pattern.
		once
			create Result.make (1200)
			Result.append ("=== ERIC BEZAULT INLINE C PATTERN ===%N%N")
			Result.append ("The simple_* ecosystem follows Eric Bezault's pattern for C integration:%N")
			Result.append ("ALL C code goes in inline externals - NO separate .c files.%N%N")
			Result.append ("PATTERN:%N")
			Result.append ("  feature_name (a_arg1: TYPE1; a_arg2: TYPE2): RETURN_TYPE%N")
			Result.append ("    external%N")
			Result.append ("      %"C inline use <header1.h>, <header2.h>%"%N")
			Result.append ("    alias%N")
			Result.append ("      %"[ // C code; access args with $a_arg1; return (EIF_TYPE)val; ]%"%N")
			Result.append ("    end%N%N")
			Result.append ("WHY THIS PATTERN:%N")
			Result.append ("1. Single source of truth - C code in Eiffel file%N")
			Result.append ("2. No build system complexity - no .c compilation%N")
			Result.append ("3. Type checking at Eiffel level%N")
			Result.append ("4. Contracts wrap C calls%N")
			Result.append ("5. Portable across platforms%N%N")
			Result.append ("HEADER INCLUDES:%N")
			Result.append ("- System headers: use <stdio.h>%N")
			Result.append ("- Local headers: use %"myheader.h%"%N")
			Result.append ("- Multiple: use <h1.h>, <h2.h>, %"local.h%"%N%N")
			Result.append ("ACCESSING EIFFEL VALUES IN C:%N")
			Result.append ("- Simple types: $a_name -> the value%N")
			Result.append ("- Objects: $a_object -> EIF_REFERENCE%N")
			Result.append ("- Strings: via C_STRING class%N")
			Result.append ("- Arrays: via SPECIAL or MANAGED_POINTER%N%N")
			Result.append ("RETURNING VALUES:%N")
			Result.append ("- Cast to EIF_* type: return (EIF_INTEGER)c_value;%N")
			Result.append ("- For void: no return statement needed%N")
			Result.append ("- For pointers: return (EIF_POINTER)ptr;%N")
		end

invariant
	inline_c_builder_exists: inline_c_builder /= Void
	library_config_exists: library_config /= Void

end
