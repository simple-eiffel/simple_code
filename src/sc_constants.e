note
	description: "Constants and version information for simple_code"
	author: "Larry Reid"
	date: "$Date$"
	revision: "$Revision$"

class
	SC_CONSTANTS

feature -- Version

	version_major: INTEGER = 0
			-- Major version number

	version_minor: INTEGER = 0
			-- Minor version number

	version_patch: INTEGER = 1
			-- Patch version number

	version_string: STRING = "0.0.1"
			-- Full version string

feature -- Library Info

	library_name: STRING = "simple_code"
			-- Library identifier

	library_description: STRING = "AI-Powered Code Assistant Integration for Eiffel"
			-- Library description

end
