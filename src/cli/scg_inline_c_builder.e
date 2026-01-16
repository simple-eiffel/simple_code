note
	description: "[
		Builder for inline C external features in Eiffel.

		Generates properly formatted inline C externals following
		the Eric Bezault pattern used throughout simple_* ecosystem.

		Handles:
		- Type mapping between Eiffel and C
		- Header includes formatting
		- Argument passing with $ prefix
		- Return value casting
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_INLINE_C_BUILDER

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize builder with type mappings.
		do
			initialize_type_maps
		end

	initialize_type_maps
			-- Set up C to Eiffel type mappings.
		do
			create c_to_eiffel_map.make (20)
			create eiffel_to_c_map.make (20)

			-- Primitive types
			c_to_eiffel_map.put ("INTEGER", "int")
			c_to_eiffel_map.put ("INTEGER", "int32_t")
			c_to_eiffel_map.put ("INTEGER_8", "int8_t")
			c_to_eiffel_map.put ("INTEGER_8", "char")
			c_to_eiffel_map.put ("INTEGER_16", "int16_t")
			c_to_eiffel_map.put ("INTEGER_16", "short")
			c_to_eiffel_map.put ("INTEGER_32", "int32_t")
			c_to_eiffel_map.put ("INTEGER_64", "int64_t")
			c_to_eiffel_map.put ("INTEGER_64", "long long")
			c_to_eiffel_map.put ("NATURAL_8", "uint8_t")
			c_to_eiffel_map.put ("NATURAL_8", "unsigned char")
			c_to_eiffel_map.put ("NATURAL_16", "uint16_t")
			c_to_eiffel_map.put ("NATURAL_16", "unsigned short")
			c_to_eiffel_map.put ("NATURAL_32", "uint32_t")
			c_to_eiffel_map.put ("NATURAL_32", "unsigned int")
			c_to_eiffel_map.put ("NATURAL_64", "uint64_t")
			c_to_eiffel_map.put ("NATURAL_64", "unsigned long long")
			c_to_eiffel_map.put ("REAL_32", "float")
			c_to_eiffel_map.put ("REAL_64", "double")
			c_to_eiffel_map.put ("BOOLEAN", "int")
			c_to_eiffel_map.put ("BOOLEAN", "bool")
			c_to_eiffel_map.put ("CHARACTER_8", "char")
			c_to_eiffel_map.put ("CHARACTER_32", "wchar_t")
			c_to_eiffel_map.put ("POINTER", "void*")
			c_to_eiffel_map.put ("POINTER", "void *")
			c_to_eiffel_map.put ("POINTER", "char*")
			c_to_eiffel_map.put ("POINTER", "char *")

			-- Reverse mapping
			eiffel_to_c_map.put ("EIF_INTEGER", "INTEGER")
			eiffel_to_c_map.put ("EIF_INTEGER_8", "INTEGER_8")
			eiffel_to_c_map.put ("EIF_INTEGER_16", "INTEGER_16")
			eiffel_to_c_map.put ("EIF_INTEGER_32", "INTEGER_32")
			eiffel_to_c_map.put ("EIF_INTEGER_64", "INTEGER_64")
			eiffel_to_c_map.put ("EIF_NATURAL_8", "NATURAL_8")
			eiffel_to_c_map.put ("EIF_NATURAL_16", "NATURAL_16")
			eiffel_to_c_map.put ("EIF_NATURAL_32", "NATURAL_32")
			eiffel_to_c_map.put ("EIF_NATURAL_64", "NATURAL_64")
			eiffel_to_c_map.put ("EIF_REAL_32", "REAL_32")
			eiffel_to_c_map.put ("EIF_REAL_64", "REAL_64")
			eiffel_to_c_map.put ("EIF_BOOLEAN", "BOOLEAN")
			eiffel_to_c_map.put ("EIF_CHARACTER", "CHARACTER_8")
			eiffel_to_c_map.put ("EIF_WIDE_CHAR", "CHARACTER_32")
			eiffel_to_c_map.put ("EIF_POINTER", "POINTER")
			eiffel_to_c_map.put ("EIF_REFERENCE", "ANY")
		end

feature -- Access

	c_to_eiffel_map: HASH_TABLE [STRING, STRING]
			-- Map from C types to Eiffel types

	eiffel_to_c_map: HASH_TABLE [STRING, STRING]
			-- Map from Eiffel types to EIF_* C types

feature -- Type Mapping

	map_c_to_eiffel (a_c_type: STRING): STRING
			-- Map C type to Eiffel type.
		require
			type_not_empty: not a_c_type.is_empty
		do
			if c_to_eiffel_map.has (a_c_type) and then attached c_to_eiffel_map.item (a_c_type) as l_type then
				Result := l_type
			else
				-- Default: assume it's a pointer
				Result := "POINTER"
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	map_eiffel_to_c (a_eiffel_type: STRING): STRING
			-- Map Eiffel type to C type for return casting.
		require
			type_not_empty: not a_eiffel_type.is_empty
		do
			if eiffel_to_c_map.has (a_eiffel_type) and then attached eiffel_to_c_map.item (a_eiffel_type) as l_type then
				Result := l_type
			else
				-- Default based on common types
				if a_eiffel_type.is_case_insensitive_equal ("INTEGER") then
					Result := "EIF_INTEGER"
				elseif a_eiffel_type.is_case_insensitive_equal ("BOOLEAN") then
					Result := "EIF_BOOLEAN"
				elseif a_eiffel_type.is_case_insensitive_equal ("POINTER") then
					Result := "EIF_POINTER"
				elseif a_eiffel_type.is_case_insensitive_equal ("REAL_64") then
					Result := "EIF_REAL_64"
				else
					Result := "EIF_REFERENCE"
				end
			end
		ensure
			result_not_empty: not Result.is_empty
		end

feature -- Code Generation

	build_inline_external (a_name: STRING; a_return_type: STRING; a_c_code: STRING; a_includes: detachable ARRAYED_LIST [STRING]): STRING
			-- Build inline C external without arguments.
		require
			name_not_empty: not a_name.is_empty
			code_not_empty: not a_c_code.is_empty
		do
			create Result.make (500)
			Result.append ("%T")
			Result.append (a_name)

			if a_return_type.is_empty or a_return_type.is_case_insensitive_equal ("void") then
				Result.append ("%N")
			else
				Result.append (": ")
				Result.append (a_return_type)
				Result.append ("%N")
			end

			Result.append ("%T%T%T-- [Description]%N")
			Result.append ("%T%Texternal%N")
			Result.append ("%T%T%T%"C inline ")
			Result.append (format_includes (a_includes))
			Result.append ("%"%N")
			Result.append ("%T%Talias%N")
			Result.append ("%T%T%T%"[%N")
			Result.append ("%T%T%T%T")
			Result.append (a_c_code)
			Result.append ("%N%T%T%T]%"%N")
			Result.append ("%T%Tend%N")
		ensure
			result_not_empty: not Result.is_empty
		end

	build_inline_external_with_args (a_name: STRING; a_args: ARRAYED_LIST [TUPLE [name: STRING; eiffel_type: STRING; c_type: STRING]]; a_return_type: STRING; a_c_code: STRING; a_includes: detachable ARRAYED_LIST [STRING]): STRING
			-- Build inline C external with arguments.
		require
			name_not_empty: not a_name.is_empty
			code_not_empty: not a_c_code.is_empty
		local
			l_first: BOOLEAN
		do
			create Result.make (800)
			Result.append ("%T")
			Result.append (a_name)

			-- Arguments
			if not a_args.is_empty then
				Result.append (" (")
				l_first := True
				across a_args as ic loop
					if not l_first then
						Result.append ("; ")
					end
					l_first := False
					Result.append (ic.name)
					Result.append (": ")
					Result.append (ic.eiffel_type)
				end
				Result.append (")")
			end

			-- Return type
			if a_return_type.is_empty or a_return_type.is_case_insensitive_equal ("void") then
				Result.append ("%N")
			else
				Result.append (": ")
				Result.append (a_return_type)
				Result.append ("%N")
			end

			Result.append ("%T%T%T-- [Description]%N")
			Result.append ("%T%Texternal%N")
			Result.append ("%T%T%T%"C inline ")
			Result.append (format_includes (a_includes))
			Result.append ("%"%N")
			Result.append ("%T%Talias%N")
			Result.append ("%T%T%T%"[%N")
			Result.append ("%T%T%T%T")
			Result.append (a_c_code)
			Result.append ("%N%T%T%T]%"%N")
			Result.append ("%T%Tend%N")
		ensure
			result_not_empty: not Result.is_empty
		end

	build_win32_wrapper (a_eiffel_name, a_win32_function: STRING; a_args: ARRAYED_LIST [TUPLE [name: STRING; eiffel_type: STRING; c_type: STRING]]; a_return_type, a_c_return_type: STRING): STRING
			-- Build wrapper for Win32 API function.
		require
			name_not_empty: not a_eiffel_name.is_empty
			function_not_empty: not a_win32_function.is_empty
		local
			l_includes: ARRAYED_LIST [STRING]
			l_c_code: STRING
			l_first: BOOLEAN
		do
			create l_includes.make (1)
			l_includes.extend ("<windows.h>")

			-- Build C code
			create l_c_code.make (200)

			-- Variable declarations and casts
			across a_args as ic loop
				l_c_code.append (ic.c_type)
				l_c_code.append (" l_")
				l_c_code.append (ic.name)
				l_c_code.append (" = (")
				l_c_code.append (ic.c_type)
				l_c_code.append (")$")
				l_c_code.append (ic.name)
				l_c_code.append (";%N%T%T%T%T")
			end

			-- Call
			if not a_return_type.is_empty and not a_return_type.is_case_insensitive_equal ("void") then
				l_c_code.append (a_c_return_type)
				l_c_code.append (" result = ")
			end
			l_c_code.append (a_win32_function)
			l_c_code.append ("(")
			l_first := True
			across a_args as ic loop
				if not l_first then
					l_c_code.append (", ")
				end
				l_first := False
				l_c_code.append ("l_")
				l_c_code.append (ic.name)
			end
			l_c_code.append (");%N%T%T%T%T")

			-- Return
			if not a_return_type.is_empty and not a_return_type.is_case_insensitive_equal ("void") then
				l_c_code.append ("return (")
				l_c_code.append (map_eiffel_to_c (a_return_type))
				l_c_code.append (")result;")
			end

			Result := build_inline_external_with_args (a_eiffel_name, a_args, a_return_type, l_c_code, l_includes)
		ensure
			result_not_empty: not Result.is_empty
		end

feature {NONE} -- Implementation

	format_includes (a_includes: detachable ARRAYED_LIST [STRING]): STRING
			-- Format includes for 'use' clause.
		local
			l_first: BOOLEAN
		do
			create Result.make (50)
			Result.append ("use ")
			if attached a_includes as l_inc and then not l_inc.is_empty then
				l_first := True
				across l_inc as ic loop
					if not l_first then
						Result.append (", ")
					end
					l_first := False
					Result.append (ic)
				end
			else
				Result.append ("<stdlib.h>")
			end
		end

feature -- Common Patterns

	simple_getter_pattern (a_struct_ptr: STRING; a_field: STRING; a_c_type: STRING; a_eiffel_type: STRING): STRING
			-- Generate getter for C struct field.
		require
			ptr_not_empty: not a_struct_ptr.is_empty
			field_not_empty: not a_field.is_empty
		local
			l_c_code: STRING
		do
			create l_c_code.make (50)
			l_c_code.append ("return (")
			l_c_code.append (map_eiffel_to_c (a_eiffel_type))
			l_c_code.append (")((")
			l_c_code.append (a_c_type)
			l_c_code.append ("*)$")
			l_c_code.append (a_struct_ptr)
			l_c_code.append (")->")
			l_c_code.append (a_field)
			l_c_code.append (";")

			Result := build_inline_external (a_field, a_eiffel_type, l_c_code, Void)
		end

	simple_setter_pattern (a_struct_ptr: STRING; a_field: STRING; a_c_type: STRING; a_value_type: STRING): STRING
			-- Generate setter for C struct field.
		require
			ptr_not_empty: not a_struct_ptr.is_empty
			field_not_empty: not a_field.is_empty
		local
			l_c_code: STRING
			l_args: ARRAYED_LIST [TUPLE [name: STRING; eiffel_type: STRING; c_type: STRING]]
		do
			create l_args.make (1)
			l_args.extend (["a_value", a_value_type, a_c_type])

			create l_c_code.make (50)
			l_c_code.append ("((")
			l_c_code.append (a_c_type)
			l_c_code.append ("*)$")
			l_c_code.append (a_struct_ptr)
			l_c_code.append (")->")
			l_c_code.append (a_field)
			l_c_code.append (" = $a_value;")

			Result := build_inline_external_with_args ("set_" + a_field, l_args, "", l_c_code, Void)
		end

invariant
	c_to_eiffel_map_exists: c_to_eiffel_map /= Void
	eiffel_to_c_map_exists: eiffel_to_c_map /= Void

end
