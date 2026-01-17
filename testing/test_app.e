note
	description: "Test runner application for simple_code"
	author: "Larry Rix"
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

			run_lib_tests
			run_scg_project_gen_tests
			run_sc_project_tests

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
			print ("--- LIB_TESTS ---%N")
			create lib_tests
			run_test (agent lib_tests.test_version_exists, "test_version_exists")
			run_test (agent lib_tests.test_sc_compiler_paths, "test_sc_compiler_paths")
		end

	run_scg_project_gen_tests
			-- Run TEST_SCG_PROJECT_GEN test cases.
		do
			print ("%N--- TEST_SCG_PROJECT_GEN ---%N")
			create scg_project_gen_tests
			run_test_with_setup_gen (agent scg_project_gen_tests.test_project_generator, "test_project_generator")
		end

	run_sc_project_tests
			-- Run TEST_SC_PROJECT test cases.
		do
			print ("%N--- TEST_SC_PROJECT ---%N")
			create sc_project_tests
			run_test_with_setup_proj (agent sc_project_tests.test_project_from_generator, "test_project_from_generator")
			run_test_with_setup_proj (agent sc_project_tests.test_project_libraries_json, "test_project_libraries_json")
			run_test_with_setup_proj (agent sc_project_tests.test_project_persistence, "test_project_persistence")
			run_test_with_setup_proj (agent sc_project_tests.test_project_soft_delete, "test_project_soft_delete")
			run_test_with_setup_proj (agent sc_project_tests.test_project_cleanup_deleted, "test_project_cleanup_deleted")
			run_test_with_setup_proj (agent sc_project_tests.test_project_disk_deletion, "test_project_disk_deletion")
			run_test_with_setup_proj (agent sc_project_tests.test_project_full_lifecycle, "test_project_full_lifecycle")
		end

feature {NONE} -- Implementation

	lib_tests: LIB_TESTS
	scg_project_gen_tests: TEST_SCG_PROJECT_GEN
	sc_project_tests: TEST_SC_PROJECT

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

	run_test_with_setup_gen (a_test: PROCEDURE; a_name: STRING)
			-- Run a single generator test with prepare/cleanup.
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				scg_project_gen_tests.prepare
				a_test.call (Void)
				scg_project_gen_tests.cleanup
				print ("  PASS: " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			scg_project_gen_tests.cleanup
			print ("  FAIL: " + a_name + "%N")
			failed := failed + 1
			l_retried := True
			retry
		end

	run_test_with_setup_proj (a_test: PROCEDURE; a_name: STRING)
			-- Run a single project test with prepare/cleanup.
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				sc_project_tests.prepare
				a_test.call (Void)
				sc_project_tests.cleanup
				print ("  PASS: " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			sc_project_tests.cleanup
			print ("  FAIL: " + a_name + "%N")
			failed := failed + 1
			l_retried := True
			retry
		end

end
