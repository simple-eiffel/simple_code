note
	description: "[
		Test Result Data Object for EQA test execution.

		Stores information about a single test execution:
		- Test class and name
		- Pass/fail status
		- Failure message
		- Stack trace (for failures)
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_TEST_RESULT

create
	make

feature {NONE} -- Initialization

	make (a_class, a_test: STRING_32; a_passed: BOOLEAN; a_message: STRING_32)
			-- Create test result.
		require
			class_not_empty: not a_class.is_empty
			test_not_empty: not a_test.is_empty
		do
			class_name := a_class
			test_name := a_test
			passed := a_passed
			message := a_message
			create stack_trace.make_empty
		ensure
			class_set: class_name = a_class
			test_set: test_name = a_test
			passed_set: passed = a_passed
			message_set: message = a_message
		end

feature -- Access

	class_name: STRING_32
			-- Test class name

	test_name: STRING_32
			-- Test feature name

	passed: BOOLEAN
			-- Did test pass?

	message: STRING_32
			-- Failure message (empty if passed)

	stack_trace: STRING_32
			-- Stack trace for failures

feature -- Status

	failed: BOOLEAN
			-- Did test fail?
		do
			Result := not passed
		ensure
			definition: Result = not passed
		end

	full_name: STRING_32
			-- Full test name (CLASS.test)
		do
			create Result.make (class_name.count + test_name.count + 1)
			Result.append (class_name)
			Result.append ({STRING_32} ".")
			Result.append (test_name)
		ensure
			not_empty: not Result.is_empty
		end

feature -- Modification

	append_to_stack_trace (a_line: STRING)
			-- Add line to stack trace.
		require
			line_not_void: a_line /= Void
		do
			stack_trace.append_string_general (a_line)
			stack_trace.append ({STRING_32} "%N")
		ensure
			trace_extended: stack_trace.count > old stack_trace.count
		end

	set_stack_trace (a_trace: STRING_32)
			-- Set entire stack trace.
		do
			stack_trace := a_trace
		ensure
			trace_set: stack_trace = a_trace
		end

feature -- Output

	to_string: STRING_32
			-- String representation.
		do
			create Result.make (100)
			if passed then
				Result.append ({STRING_32} "[PASS] ")
			else
				Result.append ({STRING_32} "[FAIL] ")
			end
			Result.append (full_name)
			if not message.is_empty then
				Result.append ({STRING_32} ": ")
				Result.append (message)
			end
		end

invariant
	class_name_exists: class_name /= Void
	test_name_exists: test_name /= Void
	message_exists: message /= Void
	stack_trace_exists: stack_trace /= Void

end
