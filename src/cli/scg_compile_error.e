note
	description: "[
		Structured compile error data for lock-file pipeline.

		Captures individual Eiffel compiler errors for one-at-a-time fixing.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_COMPILE_ERROR

create
	make,
	make_from_json

feature {NONE} -- Initialization

	make (a_code, a_class_name, a_message: STRING_32; a_line: INTEGER)
			-- Create error with `a_code' in `a_class_name' at `a_line'.
		require
			code_not_empty: not a_code.is_empty
			class_name_not_empty: not a_class_name.is_empty
			message_not_empty: not a_message.is_empty
			line_positive: a_line >= 0
		do
			error_code := a_code.twin
			class_name := a_class_name.twin
			message := a_message.twin
			line_number := a_line
		ensure
			error_code_set: error_code.same_string (a_code)
			class_name_set: class_name.same_string (a_class_name)
			message_set: message.same_string (a_message)
			line_number_set: line_number = a_line
		end

	make_from_json (a_json: SIMPLE_JSON_OBJECT)
			-- Create from JSON object.
		require
			json_not_void: a_json /= Void
		do
			if attached a_json.string_item ("code") as s then
				error_code := s.to_string_32
			else
				create error_code.make_empty
			end
			if attached a_json.string_item ("class") as s then
				class_name := s.to_string_32
			else
				create class_name.make_empty
			end
			if attached a_json.string_item ("message") as s then
				message := s.to_string_32
			else
				create message.make_empty
			end
			line_number := a_json.integer_item ("line").to_integer_32
		end

feature -- Access

	error_code: STRING_32
			-- Eiffel error code (e.g., "VJAR", "VMFN", "VD89")

	class_name: STRING_32
			-- Class where error occurred

	message: STRING_32
			-- Full error message

	line_number: INTEGER
			-- Line number in source file

feature -- Status Report

	is_valid: BOOLEAN
			-- Is this a valid error record?
		do
			Result := not error_code.is_empty and not class_name.is_empty
		end

feature -- Conversion

	to_json: SIMPLE_JSON_OBJECT
			-- Convert to JSON object.
		do
			create Result.make
			Result.put_string (error_code, "code").do_nothing
			Result.put_string (class_name, "class").do_nothing
			Result.put_string (message, "message").do_nothing
			Result.put_integer (line_number, "line").do_nothing
		ensure
			result_exists: Result /= Void
		end

	to_display_string: STRING_32
			-- Formatted string for display.
		do
			create Result.make (200)
			Result.append (error_code)
			Result.append ({STRING_32} " in ")
			Result.append (class_name)
			Result.append ({STRING_32} " line ")
			Result.append (line_number.out)
			Result.append ({STRING_32} ": ")
			Result.append (message)
		end

invariant
	error_code_exists: error_code /= Void
	class_name_exists: class_name /= Void
	message_exists: message /= Void

end
