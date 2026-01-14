note
	description: "Placeholder test class for simple_code"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	LIB_TESTS

inherit
	TEST_SET_BASE

feature -- Test

	test_version_exists
			-- Verify version constants exist
		local
			l_constants: SC_CONSTANTS
		do
			create l_constants
			assert ("version_major_valid", l_constants.version_major >= 0)
			assert ("version_string_not_empty", not l_constants.version_string.is_empty)
		end

end
