note
	description: "[
		Individual security finding from SCG_SECURITY_ANALYZER.

		Captures security concerns detected during code specification analysis.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_SECURITY_FINDING

create
	make

feature {NONE} -- Initialization

	make (a_severity: INTEGER; a_category, a_description: STRING)
			-- Create finding with severity, category, and description.
		require
			category_not_empty: not a_category.is_empty
			description_not_empty: not a_description.is_empty
			severity_valid: a_severity >= 0 and a_severity <= 4
		do
			severity := a_severity
			category := a_category
			description := a_description
		ensure
			severity_set: severity = a_severity
			category_set: category = a_category
			description_set: description = a_description
		end

feature -- Access

	severity: INTEGER
			-- Severity level (0=info, 1=low, 2=medium, 3=high, 4=critical)

	category: STRING
			-- Category of finding (e.g., "PROMPT_INJECTION", "AGENTIC_RISK")

	description: STRING
			-- Detailed description of the finding

feature -- Status

	is_critical: BOOLEAN
			-- Is this a critical finding?
		do
			Result := severity >= 4
		end

	is_high_or_above: BOOLEAN
			-- Is this high severity or above?
		do
			Result := severity >= 3
		end

feature -- Output

	as_string: STRING
			-- Human-readable representation.
		do
			create Result.make (200)
			Result.append ("[")
			inspect severity
			when 4 then Result.append ("CRITICAL")
			when 3 then Result.append ("HIGH")
			when 2 then Result.append ("MEDIUM")
			when 1 then Result.append ("LOW")
			else Result.append ("INFO")
			end
			Result.append ("] ")
			Result.append (category)
			Result.append (": ")
			Result.append (description)
		end

invariant
	category_exists: category /= Void
	description_exists: description /= Void
	severity_valid: severity >= 0 and severity <= 4

end
