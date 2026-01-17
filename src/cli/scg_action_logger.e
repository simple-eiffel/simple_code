note
	description: "[
		Claude action logger for simple_codegen sessions.

		Tracks all Claude actions during code generation:
		- INSTRUCTED: Following explicit simple_codegen instruction
		- GAP_FILL: Doing something necessary but not specified
		- REBEL: Going against or modifying instructions
		- ERROR_FIX: Correcting mistakes from prior steps
		- DECISION: Made a choice between alternatives
	]"
	author: "Larry Rix"
	date: "$Date$"

class
	SCG_ACTION_LOGGER

create
	make

feature {NONE} -- Initialization

	make (a_session_path: STRING)
			-- Create logger for session at `a_session_path'.
		require
			path_not_empty: not a_session_path.is_empty
		do
			session_path := a_session_path
			log_file_path := a_session_path + "/claude_actions.log"
			create logger.make_to_file (log_file_path)
			logger.set_json_output (True)
			logger.with_field ("session", a_session_path)
		ensure
			session_set: session_path = a_session_path
		end

feature -- Access

	session_path: STRING
			-- Path to session directory

	log_file_path: STRING
			-- Path to action log file

feature -- Categories

	Category_instructed: STRING = "INSTRUCTED"
			-- Following explicit simple_codegen instruction

	Category_gap_fill: STRING = "GAP_FILL"
			-- Doing something necessary but not specified

	Category_rebel: STRING = "REBEL"
			-- Going against or modifying instructions

	Category_error_fix: STRING = "ERROR_FIX"
			-- Correcting mistakes from prior steps

	Category_decision: STRING = "DECISION"
			-- Made a choice between alternatives

feature -- Status

	is_valid_category (a_category: STRING): BOOLEAN
			-- Is `a_category' a valid action category?
		do
			Result := a_category.same_string (Category_instructed) or
				a_category.same_string (Category_gap_fill) or
				a_category.same_string (Category_rebel) or
				a_category.same_string (Category_error_fix) or
				a_category.same_string (Category_decision)
		end

feature -- Logging

	log_action (a_category, a_action: STRING)
			-- Log a Claude action with category.
		require
			valid_category: is_valid_category (a_category)
			action_not_empty: not a_action.is_empty
		local
			l_fields: HASH_TABLE [ANY, STRING]
		do
			create l_fields.make (2)
			l_fields.put (a_category, "category")
			l_fields.put (a_action, "action")
			logger.info_with (a_action, l_fields)
		end

	log_instructed (a_action: STRING)
			-- Log an INSTRUCTED action.
		require
			action_not_empty: not a_action.is_empty
		do
			log_action (Category_instructed, a_action)
		end

	log_gap_fill (a_action: STRING)
			-- Log a GAP_FILL action.
		require
			action_not_empty: not a_action.is_empty
		do
			log_action (Category_gap_fill, a_action)
		end

	log_rebel (a_action: STRING)
			-- Log a REBEL action.
		require
			action_not_empty: not a_action.is_empty
		do
			log_action (Category_rebel, a_action)
		end

	log_error_fix (a_action: STRING)
			-- Log an ERROR_FIX action.
		require
			action_not_empty: not a_action.is_empty
		do
			log_action (Category_error_fix, a_action)
		end

	log_decision (a_action: STRING)
			-- Log a DECISION action.
		require
			action_not_empty: not a_action.is_empty
		do
			log_action (Category_decision, a_action)
		end

feature {NONE} -- Implementation

	logger: SIMPLE_LOGGER
			-- Underlying logger instance

invariant
	session_path_not_empty: not session_path.is_empty
	log_file_path_not_empty: not log_file_path.is_empty
	logger_attached: logger /= Void

end
