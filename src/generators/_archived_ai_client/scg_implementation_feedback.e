note
	description: "[
		Feedback from feature implementation attempt.

		When SCG_FEATURE_GEN tries to implement a feature, it may discover:
		- The contract is achievable (success)
		- The contract is too strict (can't be satisfied)
		- The contract is incomplete (missing cases)
		- A helper feature is needed
		- The signature should change

		This feedback flows bottom-up to inform contract refinement.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_IMPLEMENTATION_FEEDBACK

create
	make_success,
	make_contract_issue,
	make_needs_helper,
	make_signature_issue

feature {NONE} -- Initialization

	make_success (a_feature_name: STRING_32; a_implementation: STRING_32)
			-- Feature implemented successfully.
		require
			name_not_empty: not a_feature_name.is_empty
			impl_not_empty: not a_implementation.is_empty
		do
			feature_name := a_feature_name
			feedback_type := Type_success
			implementation := a_implementation
			create issue_description.make_empty
			create suggested_change.make_empty
			create helper_spec.make_empty
		ensure
			is_success: is_success
		end

	make_contract_issue (a_feature_name: STRING_32; a_issue: STRING_32; a_suggested_contract: STRING_32)
			-- Contract cannot be satisfied or is incomplete.
		require
			name_not_empty: not a_feature_name.is_empty
			issue_not_empty: not a_issue.is_empty
		do
			feature_name := a_feature_name
			feedback_type := Type_contract_issue
			issue_description := a_issue
			suggested_change := a_suggested_contract
			create implementation.make_empty
			create helper_spec.make_empty
		ensure
			is_contract_issue: is_contract_issue
		end

	make_needs_helper (a_feature_name: STRING_32; a_helper_name: STRING_32; a_helper_signature: STRING_32)
			-- Implementation needs a helper feature.
		require
			name_not_empty: not a_feature_name.is_empty
			helper_name_not_empty: not a_helper_name.is_empty
		do
			feature_name := a_feature_name
			feedback_type := Type_needs_helper
			helper_spec := a_helper_name + ": " + a_helper_signature
			create implementation.make_empty
			create issue_description.make_empty
			create suggested_change.make_empty
		ensure
			needs_helper: needs_helper
		end

	make_signature_issue (a_feature_name: STRING_32; a_issue: STRING_32; a_suggested_signature: STRING_32)
			-- Signature should change.
		require
			name_not_empty: not a_feature_name.is_empty
			issue_not_empty: not a_issue.is_empty
		do
			feature_name := a_feature_name
			feedback_type := Type_signature_issue
			issue_description := a_issue
			suggested_change := a_suggested_signature
			create implementation.make_empty
			create helper_spec.make_empty
		ensure
			is_signature_issue: is_signature_issue
		end

feature -- Access

	feature_name: STRING_32
			-- Name of the feature this feedback is for

	feedback_type: INTEGER
			-- Type of feedback

	implementation: STRING_32
			-- Successful implementation (if is_success)

	issue_description: STRING_32
			-- Description of the issue (if not success)

	suggested_change: STRING_32
			-- Suggested fix for contract or signature

	helper_spec: STRING_32
			-- Helper feature specification (if needs_helper)

feature -- Status

	is_success: BOOLEAN
			-- Was implementation successful?
		do
			Result := feedback_type = Type_success
		end

	is_contract_issue: BOOLEAN
			-- Is there a contract issue?
		do
			Result := feedback_type = Type_contract_issue
		end

	needs_helper: BOOLEAN
			-- Does implementation need a helper feature?
		do
			Result := feedback_type = Type_needs_helper
		end

	is_signature_issue: BOOLEAN
			-- Is there a signature issue?
		do
			Result := feedback_type = Type_signature_issue
		end

	requires_skeleton_change: BOOLEAN
			-- Does this feedback require changing the skeleton?
		do
			Result := is_contract_issue or is_signature_issue or needs_helper
		end

feature -- Output

	to_string: STRING_32
			-- String representation for logging.
		do
			create Result.make (200)
			Result.append ("[")
			Result.append (feature_name)
			Result.append ("] ")
			inspect feedback_type
			when Type_success then
				Result.append ("SUCCESS")
			when Type_contract_issue then
				Result.append ("CONTRACT ISSUE: ")
				Result.append (issue_description)
			when Type_needs_helper then
				Result.append ("NEEDS HELPER: ")
				Result.append (helper_spec)
			when Type_signature_issue then
				Result.append ("SIGNATURE ISSUE: ")
				Result.append (issue_description)
			else
				Result.append ("UNKNOWN")
			end
		end

feature -- Constants

	Type_success: INTEGER = 1
	Type_contract_issue: INTEGER = 2
	Type_needs_helper: INTEGER = 3
	Type_signature_issue: INTEGER = 4

invariant
	feature_name_exists: feature_name /= Void
	implementation_exists: implementation /= Void
	issue_description_exists: issue_description /= Void
	suggested_change_exists: suggested_change /= Void
	helper_spec_exists: helper_spec /= Void
	success_has_implementation: is_success implies not implementation.is_empty

end
