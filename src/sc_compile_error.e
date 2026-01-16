note
	description: "[
		Individual compilation error or warning from EiffelStudio.

		Common error codes:
		- VEEN: Unknown identifier
		- VUAR: Wrong number of actuals
		- VKCN: Function used as instruction
		- VJAR: Type mismatch in assignment
		- VD71: Duplicate class
		- VTCT: Unknown class type
		- VTAT: Type mismatch in attachment
		- VWEQ: Incompatible types in equality
		- VAPE: Precondition not satisfied
		- VDRD: Deferred feature not implemented
		- ECMA: ECMA standard violation
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SC_COMPILE_ERROR

create
	make,
	make_with_details

feature {NONE} -- Initialization

	make
			-- Create empty error.
		do
			create error_code.make_empty
			create class_name.make_empty
			create feature_name.make_empty
			create file_path.make_empty
			create message.make_empty
			create raw_text.make_empty
		end

	make_with_details (a_code: STRING; a_class: STRING; a_message: STRING)
			-- Create error with basic details.
		do
			make
			error_code := a_code
			class_name := a_class
			message := a_message
		end

feature -- Access

	error_code: STRING
			-- Error code (e.g., "VEEN", "VUAR", "VD71")

	class_name: STRING
			-- Class where error occurred (uppercase)

	feature_name: STRING
			-- Feature where error occurred (if applicable)

	file_path: STRING
			-- Full path to source file

	line_number: INTEGER
			-- Line number in source file (0 if unknown)

	message: STRING
			-- Error message text

	raw_text: STRING
			-- Raw error text as output by compiler

feature -- Status

	is_warning: BOOLEAN
			-- Is this a warning rather than an error?

	is_syntax_error: BOOLEAN
			-- Is this a syntax error?
		do
			Result := error_code.starts_with ("SYN") or error_code.starts_with ("SYNTAX")
		end

	is_validity_error: BOOLEAN
			-- Is this a validity error (4-char code starting with V)?
			-- Covers type errors (VJAR, VTAT), unknown identifiers (VEEN), etc.
		do
			Result := error_code.count = 4 and then error_code.item (1) = 'V'
		end

	is_configuration_error: BOOLEAN
			-- Is this a configuration/ECF error (VD prefix)?
		do
			Result := error_code.count = 4 and then error_code.starts_with ("VD")
		end

feature -- Common Error Predicates

	is_unknown_identifier: BOOLEAN
			-- VEEN: Unknown identifier
		do
			Result := error_code.same_string ("VEEN")
		end

	is_wrong_actuals: BOOLEAN
			-- VUAR: Wrong number of arguments
		do
			Result := error_code.same_string ("VUAR")
		end

	is_function_as_instruction: BOOLEAN
			-- VKCN: Function call cannot be used as instruction
		do
			Result := error_code.same_string ("VKCN")
		end

	is_type_mismatch: BOOLEAN
			-- VJAR: Type mismatch in assignment
		do
			Result := error_code.same_string ("VJAR")
		end

	is_duplicate_class: BOOLEAN
			-- VD71: Duplicate class in universe
		do
			Result := error_code.same_string ("VD71")
		end

	is_unknown_class: BOOLEAN
			-- VTCT: Unknown class type
		do
			Result := error_code.same_string ("VTCT")
		end

feature -- Output

	one_line_summary: STRING
			-- Single line summary
		do
			create Result.make (128)
			Result.append (error_code)
			if not class_name.is_empty then
				Result.append (" in ")
				Result.append (class_name)
				if not feature_name.is_empty then
					Result.append (".")
					Result.append (feature_name)
				end
			end
			if line_number > 0 then
				Result.append (" (line ")
				Result.append (line_number.out)
				Result.append (")")
			end
			if not message.is_empty then
				Result.append (": ")
				if message.count > 60 then
					Result.append (message.substring (1, 60))
					Result.append ("...")
				else
					Result.append (message)
				end
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	full_description: STRING
			-- Multi-line description
		do
			create Result.make (512)
			Result.append ("Error: ")
			Result.append (error_code)
			Result.append ("%N")
			if not class_name.is_empty then
				Result.append ("Class: ")
				Result.append (class_name)
				Result.append ("%N")
			end
			if not feature_name.is_empty then
				Result.append ("Feature: ")
				Result.append (feature_name)
				Result.append ("%N")
			end
			if not file_path.is_empty then
				Result.append ("File: ")
				Result.append (file_path)
				if line_number > 0 then
					Result.append (":")
					Result.append (line_number.out)
				end
				Result.append ("%N")
			end
			if not message.is_empty then
				Result.append ("Message: ")
				Result.append (message)
				Result.append ("%N")
			end
		ensure
			result_not_empty: not Result.is_empty
		end

feature {SC_OUTPUT_PARSER} -- Modification (for parser)

	set_error_code (a_code: STRING)
		do
			error_code := a_code
		ensure
			code_set: error_code = a_code
		end

	set_class_name (a_class: STRING)
		do
			class_name := a_class
		ensure
			class_set: class_name = a_class
		end

	set_feature_name (a_feature: STRING)
		do
			feature_name := a_feature
		ensure
			feature_set: feature_name = a_feature
		end

	set_file_path (a_path: STRING)
		do
			file_path := a_path
		ensure
			path_set: file_path = a_path
		end

	set_line_number (a_line: INTEGER)
		require
			line_non_negative: a_line >= 0
		do
			line_number := a_line
		ensure
			line_set: line_number = a_line
		end

	set_message (a_message: STRING)
		do
			message := a_message
		ensure
			message_set: message = a_message
		end

	set_raw_text (a_text: STRING)
		do
			raw_text := a_text
		ensure
			text_set: raw_text = a_text
		end

	set_is_warning (a_value: BOOLEAN)
		do
			is_warning := a_value
		ensure
			warning_set: is_warning = a_value
		end

invariant
	line_non_negative: line_number >= 0

end
