note
	description: "Test runner application for simple_code"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	TEST_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run the tests.
		do
			print ("Running SIMPLE_CODE tests...%N%N")
			passed := 0
			failed := 0

			create lib_tests
			run_lib_tests

			print ("%N========================%N")
			print ("Results: " + passed.out + " passed, " + failed.out + " failed%N")

			if failed > 0 then
				print ("TESTS FAILED%N")
			else
				print ("ALL TESTS PASSED%N")
			end
		end

feature {NONE} -- Test Runners

	run_lib_tests
			-- Run LIB_TESTS test cases.
		do
			run_test (agent lib_tests.test_version_exists, "test_version_exists")
			run_test_with_setup_teardown (agent lib_tests.test_project_generator, "test_project_generator")
		end

feature {NONE} -- Implementation

	lib_tests: LIB_TESTS

	passed: INTEGER
	failed: INTEGER

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run a single test and update counters.
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				a_test.call (Void)
				print ("  PASS: " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			print ("  FAIL: " + a_name + "%N")
			failed := failed + 1
			l_retried := True
			retry
		end

	run_test_with_setup_teardown (a_test: PROCEDURE; a_name: STRING)
			-- Run a single test with on_prepare/on_clean and update counters.
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				lib_tests.on_prepare
				a_test.call (Void)
				lib_tests.on_clean
				print ("  PASS: " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			lib_tests.on_clean
			print ("  FAIL: " + a_name + "%N")
			failed := failed + 1
			l_retried := True
			retry
		end

end
