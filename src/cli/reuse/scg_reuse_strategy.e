note
	description: "[
		Reuse strategy enumeration for code generation.

		Defines the possible reuse recommendations when generating new code:
		- Use_existing: Class/feature exists and can be used as-is
		- Inherit_from: Extend existing class (is-a relationship)
		- Compose_with: Use existing class as component (has-a relationship)
		- Write_fresh: No suitable reuse, generate new code
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_REUSE_STRATEGY

create
	make_use_existing,
	make_inherit_from,
	make_compose_with,
	make_write_fresh

feature {NONE} -- Initialization

	make_use_existing
			-- Create USE_EXISTING strategy.
		do
			value := Use_existing
		ensure
			is_use_existing: is_use_existing
		end

	make_inherit_from
			-- Create INHERIT_FROM strategy.
		do
			value := Inherit_from
		ensure
			is_inherit_from: is_inherit_from
		end

	make_compose_with
			-- Create COMPOSE_WITH strategy.
		do
			value := Compose_with
		ensure
			is_compose_with: is_compose_with
		end

	make_write_fresh
			-- Create WRITE_FRESH strategy.
		do
			value := Write_fresh
		ensure
			is_write_fresh: is_write_fresh
		end

feature -- Access

	value: INTEGER
			-- Numeric value of strategy

	name: STRING
			-- Human-readable name of strategy
		do
			inspect value
			when Use_existing then
				Result := "USE_EXISTING"
			when Inherit_from then
				Result := "INHERIT_FROM"
			when Compose_with then
				Result := "COMPOSE_WITH"
			when Write_fresh then
				Result := "WRITE_FRESH"
			else
				Result := "UNKNOWN"
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	description: STRING
			-- Description of what this strategy means
		do
			inspect value
			when Use_existing then
				Result := "Use existing class/feature as-is"
			when Inherit_from then
				Result := "Inherit from existing class and extend (is-a)"
			when Compose_with then
				Result := "Compose with existing class as component (has-a)"
			when Write_fresh then
				Result := "No reuse available, generate fresh code"
			else
				Result := "Unknown strategy"
			end
		ensure
			result_not_empty: not Result.is_empty
		end

feature -- Status report

	is_use_existing: BOOLEAN
			-- Is this USE_EXISTING strategy?
		do
			Result := value = Use_existing
		end

	is_inherit_from: BOOLEAN
			-- Is this INHERIT_FROM strategy?
		do
			Result := value = Inherit_from
		end

	is_compose_with: BOOLEAN
			-- Is this COMPOSE_WITH strategy?
		do
			Result := value = Compose_with
		end

	is_write_fresh: BOOLEAN
			-- Is this WRITE_FRESH strategy?
		do
			Result := value = Write_fresh
		end

	suggests_reuse: BOOLEAN
			-- Does this strategy suggest reusing existing code?
		do
			Result := value /= Write_fresh
		end

	priority: INTEGER
			-- Priority for display (lower = better reuse)
		do
			inspect value
			when Use_existing then
				Result := 1
			when Inherit_from then
				Result := 2
			when Compose_with then
				Result := 3
			when Write_fresh then
				Result := 4
			else
				Result := 5
			end
		ensure
			valid_range: Result >= 1 and Result <= 5
		end

feature -- Comparison

	is_equal_strategy (other: SCG_REUSE_STRATEGY): BOOLEAN
			-- Is this strategy equal to `other'?
		require
			other_not_void: other /= Void
		do
			Result := value = other.value
		ensure
			symmetric: Result implies other.is_equal_strategy (Current)
		end

feature -- Constants

	Use_existing: INTEGER = 1
			-- Use class/feature as-is

	Inherit_from: INTEGER = 2
			-- Inherit and extend (is-a)

	Compose_with: INTEGER = 3
			-- Use as component (has-a)

	Write_fresh: INTEGER = 4
			-- No reuse, generate new

invariant
	valid_value: value >= Use_existing and value <= Write_fresh

end
