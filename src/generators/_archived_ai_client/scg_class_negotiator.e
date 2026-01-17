note
	description: "[
		Orchestrates top-down/bottom-up negotiation for class generation.

		The generation process iterates between specification and implementation:

		1. TOP-DOWN: Generate class skeleton (signatures + contracts)
		2. BOTTOM-UP: Try implementing each feature, collect feedback
		3. RECONCILE: Adjust skeleton based on feedback
		4. ITERATE: Repeat until stabilized (no feedback changes)
		5. FINALIZE: Assemble complete class, validate

		This reflects the reality that contracts written top-down may not
		be implementable bottom-up - negotiation finds the stable point.

		Usage:
			create negotiator.make (system_spec, class_spec, ai_client)
			if negotiator.is_negotiated then
				complete_class := negotiator.final_class_text
			end
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_CLASS_NEGOTIATOR

create
	make

feature {NONE} -- Initialization

	make (a_system_spec, a_class_spec: STRING_32; a_ai: AI_CLIENT)
			-- Negotiate class generation.
		require
			system_spec_not_empty: not a_system_spec.is_empty
			class_spec_not_empty: not a_class_spec.is_empty
			ai_not_void: a_ai /= Void
		do
			system_spec := a_system_spec
			class_spec := a_class_spec
			ai_client := a_ai
			create final_class_text.make_empty
			create last_error.make_empty
			create negotiation_log.make (20)
			create feedback_history.make (10)

			negotiate
		ensure
			specs_stored: system_spec = a_system_spec and class_spec = a_class_spec
		end

feature -- Status

	is_negotiated: BOOLEAN
			-- Did negotiation succeed?

	has_error: BOOLEAN
			-- Did negotiation fail?
		do
			Result := not last_error.is_empty
		end

	iterations_used: INTEGER
			-- Number of iterations until stabilization

feature -- Access

	system_spec: STRING_32
			-- System specification

	class_spec: STRING_32
			-- Class specification

	ai_client: AI_CLIENT
			-- AI client for generation

	final_class_text: STRING_32
			-- Final negotiated class text

	current_skeleton: detachable SCG_CLASS_SKELETON
			-- Current skeleton being negotiated

	last_error: STRING_32
			-- Error message if negotiation failed

	negotiation_log: ARRAYED_LIST [STRING_32]
			-- Log of negotiation rounds

	feedback_history: ARRAYED_LIST [ARRAYED_LIST [SCG_IMPLEMENTATION_FEEDBACK]]
			-- Feedback from each iteration

feature -- Constants

	Max_iterations: INTEGER = 5
			-- Maximum negotiation iterations before giving up

feature {NONE} -- Negotiation

	negotiate
			-- Run the top-down/bottom-up negotiation loop.
		local
			l_feedback: ARRAYED_LIST [SCG_IMPLEMENTATION_FEEDBACK]
			l_has_issues: BOOLEAN
			l_stabilized: BOOLEAN
		do
			log_action ("=== Starting negotiation ===")
			create l_feedback.make (10) -- Initialize to ensure attached

			-- Phase 1: Initial top-down skeleton
			log_action ("Phase 1: Generating initial skeleton (top-down)")
			generate_initial_skeleton

			if has_error then
				log_action ("ERROR: Initial skeleton generation failed")
			else
				-- Phase 2-4: Iterate until stable
				from
					iterations_used := 0
					l_stabilized := False
				until
					l_stabilized or iterations_used >= Max_iterations or has_error
				loop
					iterations_used := iterations_used + 1
					log_action ("--- Iteration " + iterations_used.out + " ---")

					-- Bottom-up: Try implementing features
					log_action ("Trying feature implementations (bottom-up)")
					l_feedback := try_implementations

					-- Check for issues
					l_has_issues := has_issues_in_feedback (l_feedback)
					feedback_history.extend (l_feedback)

					if l_has_issues then
						-- Reconcile: Adjust skeleton based on feedback
						log_action ("Issues found, reconciling skeleton")
						reconcile_skeleton (l_feedback)
					else
						-- Stabilized!
						l_stabilized := True
						log_action ("Stabilized after " + iterations_used.out + " iterations")
					end
				end

				if l_stabilized then
					-- Phase 5: Finalize
					log_action ("Phase 5: Assembling final class")
					assemble_final_class (l_feedback)
					is_negotiated := not has_error
				elseif iterations_used >= Max_iterations then
					last_error := "Failed to stabilize after " + Max_iterations.out + " iterations"
					log_action ("ERROR: " + last_error)
					-- Still try to assemble what we have
					assemble_final_class (l_feedback)
					is_negotiated := not final_class_text.is_empty
				end
			end

			log_action ("=== Negotiation " + (if is_negotiated then "succeeded" else "failed" end) + " ===")
		end

	generate_initial_skeleton
			-- Generate initial class skeleton (top-down).
		local
			l_skeleton: SCG_CLASS_SKELETON
		do
			create l_skeleton.make (system_spec, class_spec, ai_client)
			current_skeleton := l_skeleton

			if l_skeleton.has_error then
				last_error := l_skeleton.last_error
			else
				log_action ("Skeleton generated with " + l_skeleton.feature_specs.count.out + " features")
			end
		end

	try_implementations: ARRAYED_LIST [SCG_IMPLEMENTATION_FEEDBACK]
			-- Try implementing each feature, collect feedback.
		local
			l_gen: SCG_FEATURE_GEN
			l_context: STRING_32
			l_feedback: SCG_IMPLEMENTATION_FEEDBACK
		do
			create Result.make (10)

			if attached current_skeleton as skel then
				-- Build context (all feature signatures)
				l_context := build_class_context (skel)

				-- Try each feature
				across skel.feature_specs as ic loop
					log_action ("  Trying: " + ic.name)

					create l_gen.make (ic, l_context, ai_client)

					if l_gen.is_generated then
						-- Analyze the implementation for potential issues
						l_feedback := analyze_implementation (ic, l_gen)
					else
						-- Generation failed - create feedback about the issue
						create l_feedback.make_contract_issue (
							ic.name,
							"Implementation failed: " + l_gen.last_error,
							""
						)
					end

					Result.extend (l_feedback)
					log_action ("    -> " + l_feedback.to_string)
				end
			end
		end

	analyze_implementation (a_spec: SCG_FEATURE_SPEC; a_gen: SCG_FEATURE_GEN): SCG_IMPLEMENTATION_FEEDBACK
			-- Analyze generated implementation for potential issues.
		local
			l_impl: STRING_32
		do
			l_impl := a_gen.implementation_text

			-- Check if implementation seems to satisfy contracts
			-- (This is a heuristic - real validation is compilation)

			if a_gen.needs_helpers then
				-- Needs helper features
				create Result.make_needs_helper (
					a_spec.name,
					"helper_" + a_spec.name,
					"detected from implementation"
				)
			elseif l_impl.has_substring ("-- TODO") or l_impl.has_substring ("check False") then
				-- Implementation is incomplete
				create Result.make_contract_issue (
					a_spec.name,
					"Implementation incomplete or placeholder detected",
					""
				)
			elseif l_impl.count < 10 then
				-- Implementation suspiciously short
				create Result.make_contract_issue (
					a_spec.name,
					"Implementation too short - may not satisfy contracts",
					""
				)
			else
				-- Looks good
				create Result.make_success (a_spec.name, l_impl)
			end
		end

	has_issues_in_feedback (a_feedback: ARRAYED_LIST [SCG_IMPLEMENTATION_FEEDBACK]): BOOLEAN
			-- Does any feedback indicate issues?
		do
			across a_feedback as ic until Result loop
				Result := ic.requires_skeleton_change
			end
		end

	reconcile_skeleton (a_feedback: ARRAYED_LIST [SCG_IMPLEMENTATION_FEEDBACK])
			-- Adjust skeleton based on implementation feedback.
		local
			l_issues: ARRAYED_LIST [SCG_IMPLEMENTATION_FEEDBACK]
			l_prompt: STRING_32
			l_response: AI_RESPONSE
		do
			-- Collect all issues
			create l_issues.make (5)
			across a_feedback as ic loop
				if ic.requires_skeleton_change then
					l_issues.extend (ic)
				end
			end

			if not l_issues.is_empty and attached current_skeleton as skel then
				-- Ask AI to reconcile
				l_prompt := build_reconciliation_prompt (skel.class_text, l_issues)
				l_response := ai_client.ask_with_system (reconciliation_system_prompt, l_prompt)

				if l_response.is_success then
					-- Parse new skeleton
					create current_skeleton.make (system_spec, class_spec, ai_client)
					-- Note: In a full implementation, we'd parse the AI's adjusted skeleton
					-- For now, regenerate with adjusted prompt
					log_action ("Skeleton adjusted based on " + l_issues.count.out + " issues")
				else
					log_action ("WARNING: Reconciliation failed, using previous skeleton")
				end
			end
		end

	build_reconciliation_prompt (a_skeleton: STRING_32; a_issues: ARRAYED_LIST [SCG_IMPLEMENTATION_FEEDBACK]): STRING_32
			-- Build prompt to reconcile skeleton with implementation feedback.
		do
			create Result.make (2000)
			Result.append ("Adjust this Eiffel class skeleton based on implementation feedback.%N%N")

			Result.append ("=== CURRENT SKELETON ===%N")
			Result.append (a_skeleton)
			Result.append ("%N%N")

			Result.append ("=== IMPLEMENTATION FEEDBACK ===%N")
			across a_issues as ic loop
				Result.append ("- ")
				Result.append (ic.to_string)
				Result.append ("%N")
				if not ic.suggested_change.is_empty then
					Result.append ("  Suggested: ")
					Result.append (ic.suggested_change)
					Result.append ("%N")
				end
			end

			Result.append ("%N=== TASK ===%N")
			Result.append ("Adjust contracts/signatures to address the issues.%N")
			Result.append ("Keep placeholder bodies: do check False then end end%N")
			Result.append ("Output adjusted skeleton in ```eiffel ... ``` markers.%N")
		end

	reconciliation_system_prompt: STRING_32
			-- System prompt for reconciliation.
		once
			Result := {STRING_32} "[
Expert Eiffel architect. Adjust class skeletons based on implementation feedback.
Make contracts achievable while preserving intent.
Add helper signatures if needed.
STRING_32 concat: use {STRING_32} "text" + var (NOT "text" + var).
Output: ```eiffel adjusted skeleton only.
]"
		end

	assemble_final_class (a_final_feedback: ARRAYED_LIST [SCG_IMPLEMENTATION_FEEDBACK])
			-- Assemble the final class from skeleton and implementations.
		local
			l_assembler: SCG_FEATURE_ASSEMBLER
		do
			if attached current_skeleton as skel then
				create l_assembler.make (skel.class_text)

				-- Add successful implementations
				across a_final_feedback as ic loop
					if ic.is_success then
						l_assembler.add_implementation (ic.feature_name, ic.implementation)
					end
				end

				final_class_text := l_assembler.assemble
				log_action ("Assembled class (" + final_class_text.count.out + " chars)")
			end
		end

	build_class_context (a_skeleton: SCG_CLASS_SKELETON): STRING_32
			-- Build context string with all feature signatures.
		do
			create Result.make (1000)
			Result.append ("CLASS: ")
			Result.append (a_skeleton.class_name)
			Result.append ("%N%N")
			Result.append ("FEATURES:%N")

			across a_skeleton.feature_specs as ic loop
				Result.append (ic.to_context_string)
				Result.append ("%N")
			end
		end

	log_action (a_message: STRING_32)
			-- Log an action.
		do
			negotiation_log.extend (a_message)
		end

feature -- Output

	log_as_string: STRING_32
			-- Return negotiation log as string.
		do
			create Result.make (2000)
			across negotiation_log as ic loop
				Result.append (ic)
				Result.append ("%N")
			end
		end

invariant
	system_spec_exists: system_spec /= Void
	class_spec_exists: class_spec /= Void
	final_class_text_exists: final_class_text /= Void
	last_error_exists: last_error /= Void
	negotiation_log_exists: negotiation_log /= Void
	feedback_history_exists: feedback_history /= Void
	negotiated_has_text: is_negotiated implies not final_class_text.is_empty

end
