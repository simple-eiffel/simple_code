note
	description: "[
		TOON format prompt loader and renderer for atomic prompts.

		Loads .toon template files and renders them with variable substitution.
		TOON format provides 30-60% token reduction vs JSON for AI prompts.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_TOON_PROMPT

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize prompt loader with default template directory.
		do
			template_dir := "prompts"
			create cached_templates.make (10)
		ensure
			template_dir_set: template_dir.same_string ("prompts")
		end

feature -- Access

	template_dir: STRING
			-- Directory containing .toon template files

feature -- Element change

	set_template_dir (a_dir: STRING)
			-- Set template directory to `a_dir'.
		require
			dir_not_empty: not a_dir.is_empty
		do
			template_dir := a_dir
			cached_templates.wipe_out
		ensure
			template_dir_set: template_dir = a_dir
		end

feature -- Template Loading

	load_template (a_name: STRING): STRING
			-- Load TOON template file by name (without .toon extension).
			-- Returns empty string if template not found.
		require
			name_not_empty: not a_name.is_empty
		local
			l_path: STRING
			l_file: SIMPLE_FILE
		do
			-- Check cache first
			if cached_templates.has (a_name) and then attached cached_templates.item (a_name) as l_cached then
				Result := l_cached
			else
				-- Load from file
				l_path := template_dir + "/" + a_name + ".toon"
				create l_file.make (l_path)
				if l_file.exists then
					if attached l_file.read_all as l_content then
						Result := l_content
						cached_templates.put (Result, a_name)
					else
						Result := ""
					end
				else
					Result := ""
				end
			end
		end

	has_template (a_name: STRING): BOOLEAN
			-- Does template `a_name' exist?
		require
			name_not_empty: not a_name.is_empty
		local
			l_path: STRING
			l_file: SIMPLE_FILE
		do
			if cached_templates.has (a_name) then
				Result := True
			else
				l_path := template_dir + "/" + a_name + ".toon"
				create l_file.make (l_path)
				Result := l_file.exists
			end
		end

feature -- Rendering

	render (a_template: STRING; a_vars: HASH_TABLE [STRING, STRING]): STRING
			-- Replace ${var} placeholders with values from `a_vars'.
		require
			template_not_empty: not a_template.is_empty
		do
			Result := a_template.twin
			across a_vars as ic loop
				Result.replace_substring_all ("${" + @ic.key + "}", ic)
			end
		ensure
			result_exists: Result /= Void
		end

	render_template (a_name: STRING; a_vars: HASH_TABLE [STRING, STRING]): STRING
			-- Load template `a_name' and render with `a_vars'.
		require
			name_not_empty: not a_name.is_empty
		local
			l_template: STRING
		do
			l_template := load_template (a_name)
			if l_template.is_empty then
				Result := ""
			else
				Result := render (l_template, a_vars)
			end
		end

feature -- Convenience

	vars: HASH_TABLE [STRING, STRING]
			-- Create new empty variable table for fluent building.
		do
			create Result.make (10)
		ensure
			result_empty: Result.is_empty
		end

	put_var (a_table: HASH_TABLE [STRING, STRING]; a_value, a_key: STRING): HASH_TABLE [STRING, STRING]
			-- Add variable to table and return table for chaining.
		require
			table_exists: a_table /= Void
			key_not_empty: not a_key.is_empty
		do
			a_table.put (a_value, a_key)
			Result := a_table
		ensure
			variable_added: a_table.has (a_key)
			result_is_table: Result = a_table
		end

feature -- Cache Management

	clear_cache
			-- Clear all cached templates.
		do
			cached_templates.wipe_out
		ensure
			cache_empty: cached_templates.is_empty
		end

	reload_template (a_name: STRING): STRING
			-- Force reload template from disk (bypasses cache).
		require
			name_not_empty: not a_name.is_empty
		do
			cached_templates.remove (a_name)
			Result := load_template (a_name)
		end

feature {NONE} -- Implementation

	cached_templates: HASH_TABLE [STRING, STRING]
			-- Cache of loaded templates keyed by name

invariant
	template_dir_exists: template_dir /= Void
	cached_templates_exists: cached_templates /= Void

end
