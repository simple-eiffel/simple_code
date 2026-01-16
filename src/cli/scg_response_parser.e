note
	description: "[
		Parser for Claude's JSON-structured responses.

		Handles three response types:
		- system_spec: System architecture decomposition
		- class_code: Generated Eiffel class
		- refinement: Refined/fixed class code

		Extracts structured data and updates session state.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_RESPONSE_PARSER

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize parser.
		do
			create last_error.make_empty
			create response_type.make_empty
			create parsed_classes.make (10)
		ensure
			last_error_empty: last_error.is_empty
		end

feature -- Status

	is_success: BOOLEAN
			-- Was last parse successful?

feature -- Access

	response_type: STRING_32
			-- Type of parsed response (system_spec, class_code, refinement)

	parsed_class_name: detachable STRING_32
			-- Class name from class_code or refinement response

	parsed_code: detachable STRING_32
			-- Code from class_code or refinement response

	parsed_classes: ARRAYED_LIST [SCG_SESSION_CLASS_SPEC]
			-- Classes from system_spec response

	parsed_notes: detachable STRING_32
			-- Notes from response (if any)

	last_error: STRING_32
			-- Error message from failed parse

feature -- Parsing

	parse (a_response: STRING_32; a_session: SCG_SESSION)
			-- Parse Claude's response and update session.
			-- Uses SIMPLE_JSON first, falls back to regex extraction for large code fields.
		require
			response_not_empty: not a_response.is_empty
			session_valid: a_session.is_valid
		local
			l_json_text: STRING_32
			l_json: SIMPLE_JSON
		do
			-- Reset state
			is_success := False
			last_error.wipe_out
			response_type.wipe_out
			parsed_class_name := Void
			parsed_code := Void
			parsed_notes := Void
			parsed_classes.wipe_out

			-- Extract JSON from response (may be wrapped in ```json ... ```)
			l_json_text := extract_json (a_response)

			if l_json_text.is_empty then
				last_error := "No JSON found in response"
			else
				create l_json
				if attached l_json.parse (l_json_text) as l_value then
					if l_value.is_object then
						parse_json_object (l_value, a_session, l_json)
					else
						last_error := "Response is not a JSON object"
					end
				else
					-- JSON parsing failed - try fallback extraction for class_code/refinement
					parse_fallback (l_json_text, a_session)
					if not is_success then
						last_error := "Invalid JSON: " + l_json.errors_as_string + "%N(Fallback extraction also failed)"
					end
				end
			end
		end

	parse_fallback (a_json_text: STRING_32; a_session: SCG_SESSION)
			-- Fallback parser using regex/string extraction when SIMPLE_JSON fails.
			-- Handles class_code and refinement responses with large code fields.
		local
			l_type, l_class_name, l_code: detachable STRING_32
		do
			-- Extract type
			l_type := extract_field (a_json_text, "type")

			if attached l_type as l_t then
				response_type := l_t

				if l_t.is_case_insensitive_equal ("class_code") or l_t.is_case_insensitive_equal ("refinement") then
					-- Extract class_name
					l_class_name := extract_field (a_json_text, "class_name")

					-- Extract code (special handling for large multiline strings)
					l_code := extract_code_field (a_json_text)

					if attached l_class_name as l_cn and then attached l_code as l_c then
						if not l_cn.is_empty and not l_c.is_empty then
							parsed_class_name := l_cn
							parsed_code := unescape_json_string (l_c)
							parsed_notes := extract_field (a_json_text, "notes")

							-- Update session
							if attached parsed_code as l_pc then
								a_session.mark_class_generated (l_cn, l_pc)
							end
							is_success := True
						end
					end
				end
			end
		end

	extract_field (a_json_text: STRING_32; a_field_name: STRING): detachable STRING_32
			-- Extract simple string field value from JSON text.
		local
			l_pattern: STRING_32
			l_start, l_end: INTEGER
		do
			-- Look for "field_name": "value"
			l_pattern := "%"" + a_field_name + "%": %""
			l_start := a_json_text.substring_index (l_pattern, 1)
			if l_start > 0 then
				l_start := l_start + l_pattern.count
				-- Find closing quote (handle escaped quotes)
				l_end := find_string_end (a_json_text, l_start)
				if l_end > l_start then
					Result := a_json_text.substring (l_start, l_end - 1)
				end
			end
		end

	extract_code_field (a_json_text: STRING_32): detachable STRING_32
			-- Extract the "code" field which may contain large multiline content.
		local
			l_pattern: STRING_32
			l_start, l_end: INTEGER
		do
			-- Look for "code": "
			l_pattern := "%"code%": %""
			l_start := a_json_text.substring_index (l_pattern, 1)
			if l_start > 0 then
				l_start := l_start + l_pattern.count
				-- Find closing quote (handle escaped quotes and newlines)
				l_end := find_string_end (a_json_text, l_start)
				if l_end > l_start then
					Result := a_json_text.substring (l_start, l_end - 1)
				end
			end
		end

	find_string_end (a_text: STRING_32; a_start: INTEGER): INTEGER
			-- Find end of JSON string starting at a_start (position of closing quote).
		local
			i: INTEGER
			c: CHARACTER_32
		do
			from i := a_start until i > a_text.count or Result > 0 loop
				c := a_text.item (i)
				if c = '"' then
					-- Check if it's escaped
					if i > 1 and then a_text.item (i - 1) = '\' then
						-- Check if the backslash itself is escaped
						if i > 2 and then a_text.item (i - 2) = '\' then
							-- Escaped backslash followed by quote - this is end of string
							Result := i
						end
						-- Otherwise skip this escaped quote
					else
						Result := i
					end
				end
				i := i + 1
			end
		end

feature {NONE} -- JSON Parsing

	parse_json_object (a_value: SIMPLE_JSON_VALUE; a_session: SCG_SESSION; a_json: SIMPLE_JSON)
			-- Parse JSON object based on its type field.
		require
			is_object: a_value.is_object
		local
			l_type: detachable STRING_32
		do
			l_type := a_json.query_string (a_value, "$.type")

			if attached l_type as l_t then
				response_type := l_t

				if l_t.is_case_insensitive_equal ("system_spec") then
					parse_system_spec (a_value, a_session, a_json)
				elseif l_t.is_case_insensitive_equal ("class_code") then
					parse_class_code (a_value, a_session, a_json)
				elseif l_t.is_case_insensitive_equal ("refinement") then
					parse_refinement (a_value, a_session, a_json)
				else
					last_error := "Unknown response type: " + l_t
				end
			else
				last_error := "Missing 'type' field in response"
			end
		end

	parse_system_spec (a_value: SIMPLE_JSON_VALUE; a_session: SCG_SESSION; a_json: SIMPLE_JSON)
			-- Parse system_spec response.
		local
			l_class_spec: SCG_SESSION_CLASS_SPEC
			l_name, l_desc: STRING_32
			l_features: ARRAYED_LIST [STRING_32]
			l_class_obj: SIMPLE_JSON_VALUE
			l_classes_arr: SIMPLE_JSON_ARRAY
			i: INTEGER
		do
			-- Get classes array
			if a_value.as_object.has_key ("classes") then
				if attached a_value.as_object.item ("classes") as l_classes_val then
					if l_classes_val.is_array then
						l_classes_arr := l_classes_val.as_array
						from i := 1 until i > l_classes_arr.count loop
							l_class_obj := l_classes_arr.item (i)
							if l_class_obj.is_object then
								-- Extract class info
								l_name := ""
								l_desc := ""

								if attached a_json.query_string (l_class_obj, "$.name") as l_n then
									l_name := l_n
								end
								if attached a_json.query_string (l_class_obj, "$.description") as l_d then
									l_desc := l_d
								end

								-- Extract features using helper
								l_features := extract_feature_names (l_class_obj, a_json)

								if not l_name.is_empty then
									create l_class_spec.make (l_name, l_desc, l_features)
									parsed_classes.extend (l_class_spec)
									a_session.add_class_spec (l_name, l_desc, l_features)
								end
							end
							i := i + 1
						end

						if parsed_classes.count > 0 then
							is_success := True
						else
							last_error := "No classes found in system_spec"
						end
					else
						last_error := "'classes' is not an array"
					end
				end
			else
				last_error := "Missing 'classes' field in system_spec"
			end
		end

	extract_feature_names (a_class_obj: SIMPLE_JSON_VALUE; a_json: SIMPLE_JSON): ARRAYED_LIST [STRING_32]
			-- Extract feature names from class object.
		local
			l_feat_obj: SIMPLE_JSON_VALUE
			l_feats_arr: SIMPLE_JSON_ARRAY
			i: INTEGER
		do
			create Result.make (5)
			if a_class_obj.as_object.has_key ("features") then
				if attached a_class_obj.as_object.item ("features") as l_feats then
					if l_feats.is_array then
						l_feats_arr := l_feats.as_array
						from i := 1 until i > l_feats_arr.count loop
							l_feat_obj := l_feats_arr.item (i)
							if l_feat_obj.is_object then
								if attached a_json.query_string (l_feat_obj, "$.name") as l_fn then
									Result.extend (l_fn)
								end
							end
							i := i + 1
						end
					end
				end
			end
		ensure
			result_exists: Result /= Void
		end

	parse_class_code (a_value: SIMPLE_JSON_VALUE; a_session: SCG_SESSION; a_json: SIMPLE_JSON)
			-- Parse class_code response.
		local
			l_unescaped: STRING_32
		do
			parsed_class_name := a_json.query_string (a_value, "$.class_name")
			parsed_code := a_json.query_string (a_value, "$.code")
			parsed_notes := a_json.query_string (a_value, "$.notes")

			if attached parsed_class_name as l_name and then attached parsed_code as l_code then
				if not l_name.is_empty and not l_code.is_empty then
					-- Unescape the code
					l_unescaped := unescape_json_string (l_code)
					parsed_code := l_unescaped

					-- Mark class as generated in session
					a_session.mark_class_generated (l_name, l_unescaped)
					is_success := True
				else
					last_error := "Empty class_name or code"
				end
			else
				last_error := "Missing class_name or code field"
			end
		end

	parse_refinement (a_value: SIMPLE_JSON_VALUE; a_session: SCG_SESSION; a_json: SIMPLE_JSON)
			-- Parse refinement response.
		local
			l_unescaped: STRING_32
		do
			parsed_class_name := a_json.query_string (a_value, "$.class_name")
			parsed_code := a_json.query_string (a_value, "$.code")

			if attached parsed_class_name as l_name and then attached parsed_code as l_code then
				if not l_name.is_empty and not l_code.is_empty then
					-- Unescape the code
					l_unescaped := unescape_json_string (l_code)
					parsed_code := l_unescaped

					-- Update class in session
					a_session.mark_class_generated (l_name, l_unescaped)
					is_success := True
				else
					last_error := "Empty class_name or code in refinement"
				end
			else
				last_error := "Missing class_name or code in refinement"
			end
		end

feature {NONE} -- Helpers

	extract_json (a_text: STRING_32): STRING_32
			-- Extract JSON from text that may be wrapped in ```json ... ```.
		local
			l_start, l_end: INTEGER
		do
			-- Try to find ```json marker
			l_start := a_text.substring_index ("```json", 1)
			if l_start > 0 then
				l_start := a_text.index_of ('%N', l_start) + 1
				l_end := a_text.substring_index ("```", l_start)
				if l_end > l_start then
					Result := a_text.substring (l_start, l_end - 1)
				else
					Result := a_text.substring (l_start, a_text.count)
				end
			else
				-- Try plain ``` marker
				l_start := a_text.substring_index ("```", 1)
				if l_start > 0 then
					l_start := a_text.index_of ('%N', l_start) + 1
					l_end := a_text.substring_index ("```", l_start)
					if l_end > l_start then
						Result := a_text.substring (l_start, l_end - 1)
					else
						Result := a_text.substring (l_start, a_text.count)
					end
				else
					-- Try finding JSON object directly
					l_start := a_text.index_of ('{', 1)
					if l_start > 0 then
						l_end := find_matching_brace (a_text, l_start)
						if l_end > l_start then
							Result := a_text.substring (l_start, l_end)
						else
							Result := a_text.substring (l_start, a_text.count)
						end
					else
						create Result.make_empty
					end
				end
			end

			Result.left_adjust
			Result.right_adjust
		ensure
			result_not_void: Result /= Void
		end

	find_matching_brace (a_text: STRING_32; a_start: INTEGER): INTEGER
			-- Find position of closing brace matching opening brace at a_start.
		local
			i, l_depth: INTEGER
			l_in_string: BOOLEAN
			c: CHARACTER_32
		do
			l_depth := 0
			from i := a_start until i > a_text.count or (l_depth = 0 and i > a_start) loop
				c := a_text.item (i)
				if l_in_string then
					if c = '"' and (i = 1 or else a_text.item (i - 1) /= '\') then
						l_in_string := False
					end
				else
					if c = '"' then
						l_in_string := True
					elseif c = '{' then
						l_depth := l_depth + 1
					elseif c = '}' then
						l_depth := l_depth - 1
						if l_depth = 0 then
							Result := i
						end
					end
				end
				i := i + 1
			end
		end

	unescape_json_string (a_str: STRING_32): STRING_32
			-- Unescape JSON string escapes (\n, \t, \\, \").
		local
			i: INTEGER
			c: CHARACTER_32
		do
			create Result.make (a_str.count)
			from i := 1 until i > a_str.count loop
				c := a_str.item (i)
				if c = '\' and i < a_str.count then
					inspect a_str.item (i + 1)
					when 'n' then
						Result.append_character ('%N')
						i := i + 1
					when 't' then
						Result.append_character ('%T')
						i := i + 1
					when '\' then
						Result.append_character ('\')
						i := i + 1
					when '"' then
						Result.append_character ('"')
						i := i + 1
					else
						Result.append_character (c)
					end
				else
					Result.append_character (c)
				end
				i := i + 1
			end
		end

invariant
	last_error_exists: last_error /= Void
	response_type_exists: response_type /= Void
	parsed_classes_exists: parsed_classes /= Void

end
