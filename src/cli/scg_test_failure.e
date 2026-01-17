note
	description: "[
		Structured test failure data for lock-file pipeline.

		Captures individual test failures for one-at-a-time fixing.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_TEST_FAILURE

create
	make,
	make_from_json

feature {NONE} -- Initialization

	make (a_test_class, a_test_name, a_message: STRING_32)
			-- Create failure for `a_test_name' in `a_test_class'.
		require
			test_class_not_empty: not a_test_class.is_empty
			test_name_not_empty: not a_test_name.is_empty
			message_not_empty: not a_message.is_empty
		do
			test_class := a_test_class.twin
			test_name := a_test_name.twin
			message := a_message.twin
			create expected_value.make_empty
			create actual_value.make_empty
		ensure
			test_class_set: test_class.same_string (a_test_class)
			test_name_set: test_name.same_string (a_test_name)
			message_set: message.same_string (a_message)
		end

	make_from_json (a_json: SIMPLE_JSON_OBJECT)
			-- Create from JSON object.
		require
			json_not_void: a_json /= Void
		do
			if attached a_json.string_item ("test_class") as s then
				test_class := s.to_string_32
			else
				create test_class.make_empty
			end
			if attached a_json.string_item ("test_name") as s then
				test_name := s.to_string_32
			else
				create test_name.make_empty
			end
			if attached a_json.string_item ("message") as s then
				message := s.to_string_32
			else
				create message.make_empty
			end
			if attached a_json.string_item ("expected") as s then
				expected_value := s.to_string_32
			else
				create expected_value.make_empty
			end
			if attached a_json.string_item ("actual") as s then
				actual_value := s.to_string_32
			else
				create actual_value.make_empty
			end
		end

feature -- Access

	test_class: STRING_32
			-- Name of test class

	test_name: STRING_32
			-- Name of failing test

	message: STRING_32
			-- Failure message

	expected_value: STRING_32
			-- Expected value (if assertion failure)

	actual_value: STRING_32
			-- Actual value (if assertion failure)

feature -- Element Change

	set_expected_actual (a_expected, a_actual: STRING_32)
			-- Set expected and actual values.
		require
			expected_not_empty: not a_expected.is_empty
			actual_not_empty: not a_actual.is_empty
		do
			expected_value := a_expected.twin
			actual_value := a_actual.twin
		ensure
			expected_set: expected_value.same_string (a_expected)
			actual_set: actual_value.same_string (a_actual)
		end

feature -- Status Report

	is_valid: BOOLEAN
			-- Is this a valid failure record?
		do
			Result := not test_class.is_empty and not test_name.is_empty
		end

	has_expected_actual: BOOLEAN
			-- Does this failure have expected/actual values?
		do
			Result := not expected_value.is_empty and not actual_value.is_empty
		end

feature -- Conversion

	to_json: SIMPLE_JSON_OBJECT
			-- Convert to JSON object.
		do
			create Result.make
			Result.put_string (test_class, "test_class").do_nothing
			Result.put_string (test_name, "test_name").do_nothing
			Result.put_string (message, "message").do_nothing
			if not expected_value.is_empty then
				Result.put_string (expected_value, "expected").do_nothing
			end
			if not actual_value.is_empty then
				Result.put_string (actual_value, "actual").do_nothing
			end
		ensure
			result_exists: Result /= Void
		end

	to_display_string: STRING_32
			-- Formatted string for display.
		do
			create Result.make (300)
			Result.append (test_class)
			Result.append ({STRING_32} ".")
			Result.append (test_name)
			Result.append ({STRING_32} ": ")
			Result.append (message)
			if has_expected_actual then
				Result.append ({STRING_32} "%N  Expected: ")
				Result.append (expected_value)
				Result.append ({STRING_32} "%N  Actual: ")
				Result.append (actual_value)
			end
		end

invariant
	test_class_exists: test_class /= Void
	test_name_exists: test_name /= Void
	message_exists: message /= Void
	expected_value_exists: expected_value /= Void
	actual_value_exists: actual_value /= Void

end
