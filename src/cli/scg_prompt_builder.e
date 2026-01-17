note
	description: "[
		Prompt builder for Claude-in-the-Loop code generation.

		Constructs structured prompts for each phase of generation:
		- System design: Initial architecture decomposition
		- Class scaffold: Class skeleton with contracts
		- Class implement: Full implementation
		- Refinement: Fix specific issues

		All prompts request JSON-structured output for easy parsing.
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_PROMPT_BUILDER

create
	make,
	make_with_reuse

feature {NONE} -- Initialization

	make (a_session: SCG_SESSION)
			-- Create prompt builder for `a_session'.
		require
			session_valid: a_session.is_valid
		do
			session := a_session
		ensure
			session_set: session = a_session
		end

	make_with_reuse (a_session: SCG_SESSION; a_kb: SCG_KB; a_ecf_path: STRING)
			-- Create prompt builder with reuse discovery enabled.
		require
			session_valid: a_session.is_valid
			kb_open: a_kb.is_open
			ecf_path_not_empty: not a_ecf_path.is_empty
		do
			session := a_session
			create reuse_discoverer.make_with_kb (a_kb, a_ecf_path)
		ensure
			session_set: session = a_session
			reuse_enabled: is_reuse_enabled
		end

feature -- Access

	session: SCG_SESSION
			-- Session this builder works with

	reuse_discoverer: detachable SCG_REUSE_DISCOVERER
			-- Reuse discoverer for searching existing code (optional)

	security_analyzer: detachable SCG_SECURITY_ANALYZER
			-- Security analyzer for threat analysis (optional - "Security Hat")

feature -- Status

	is_reuse_enabled: BOOLEAN
			-- Is reuse discovery enabled?
		do
			Result := attached reuse_discoverer
		end

	is_security_enabled: BOOLEAN
			-- Is security analysis enabled ("Security Hat" on)?
		do
			Result := attached security_analyzer
		end

feature -- Element change

	enable_reuse_discovery (a_kb: SCG_KB; a_ecf_path: STRING)
			-- Enable reuse discovery with knowledge base and ECF path.
		require
			kb_open: a_kb.is_open
			ecf_path_not_empty: not a_ecf_path.is_empty
		do
			create reuse_discoverer.make_with_kb (a_kb, a_ecf_path)
		ensure
			reuse_enabled: is_reuse_enabled
		end

	disable_reuse_discovery
			-- Disable reuse discovery.
		do
			reuse_discoverer := Void
		ensure
			reuse_disabled: not is_reuse_enabled
		end

	enable_security_analysis
			-- Enable security analysis ("put on Security Hat").
			-- Activates 2026 threat landscape analysis including:
			-- - Agentic AI risks (attacks on/by agents)
			-- - Prompt injection defense (OWASP LLM #1)
			-- - Identity/authentication risks
			-- - Post-quantum cryptography considerations
			-- - Data exfiltration prevention
		do
			create security_analyzer.make
		ensure
			security_enabled: is_security_enabled
		end

	disable_security_analysis
			-- Disable security analysis ("remove Security Hat").
		do
			security_analyzer := Void
		ensure
			security_disabled: not is_security_enabled
		end

feature -- Prompt Generation

	build_system_design_prompt: STRING_32
			-- Build the initial system design prompt.
		do
			create Result.make (2000)
			Result.append (system_design_template)
		end

	build_next_prompt: STRING_32
			-- Build the next appropriate prompt based on session state.
		do
			if session.state.is_case_insensitive_equal (session.State_initialized) then
				Result := build_system_design_prompt
			elseif session.state.is_case_insensitive_equal (session.State_spec_received) then
				Result := build_first_class_prompt
			elseif session.state.is_case_insensitive_equal (session.State_generating) then
				Result := build_next_class_prompt
			else
				Result := build_system_design_prompt
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	build_first_class_prompt: STRING_32
			-- Build prompt for generating the first pending class.
		local
			l_class: detachable SCG_SESSION_CLASS_SPEC
		do
			-- Find first non-generated class
			across session.class_specs as ic until attached l_class loop
				if not ic.is_generated then
					l_class := ic
				end
			end

			if attached l_class as l_c then
				Result := build_class_prompt (l_c)
			else
				Result := "All classes have been generated."
			end
		end

	build_next_class_prompt: STRING_32
			-- Build prompt for next pending class.
		do
			Result := build_first_class_prompt
		end

	build_class_prompt (a_spec: SCG_SESSION_CLASS_SPEC): STRING_32
			-- Build prompt to generate class from `a_spec'.
		require
			spec_not_generated: not a_spec.is_generated
		local
			l_reuse_result: SCG_REUSE_RESULT
		do
			create Result.make (3000)
			Result.append ("Generate the Eiffel class: " + a_spec.name + "%N%N")

			Result.append ("=== SESSION INFO ===%N")
			Result.append ("Session: " + session.session_name + "%N%N")

			-- Inject reuse analysis: prefer fresh discovery, fallback to session cache
			if attached reuse_discoverer as l_disc then
				-- Fresh discovery with current KB and ECF state
				l_reuse_result := l_disc.discover_for_class (a_spec)
				if l_reuse_result.has_candidates or not l_reuse_result.api_summary.is_empty then
					Result.append (l_reuse_result.prompt_enhancement.to_string_32)
					Result.append ("%N")
				end
			elseif session.has_reuse_analysis then
				-- Fallback: use session's cached reuse analysis
				Result.append (session.get_reuse_prompt_enhancement)
				Result.append ("%N")
			end

			-- Inject security analysis ("Security Hat" mode)
			if attached security_analyzer as l_sec then
				l_sec.analyze_class_spec (a_spec)
				if not l_sec.findings.is_empty or not l_sec.recommendations.is_empty then
					Result.append (l_sec.as_prompt_enhancement.to_string_32)
					Result.append ("%N")
				end
			end

			Result.append ("=== CLASS SPECIFICATION ===%N")
			Result.append ("Class name: " + a_spec.name + "%N")
			Result.append ("Description: " + a_spec.description + "%N")

			if not a_spec.features.is_empty then
				Result.append ("Features to implement:%N")
				across a_spec.features as ic loop
					Result.append ("  - " + ic + "%N")
				end
			end

			Result.append ("%N")
			Result.append (class_generation_instructions)
			Result.append ("%N")
			Result.append (json_output_format_class_with_session (session.session_name))
		end

	build_refinement_prompt (a_class_name: STRING_32; a_issues: ARRAYED_LIST [STRING_32]; a_code: STRING_32): STRING_32
			-- Build prompt to refine class with specific issues.
		require
			name_not_empty: not a_class_name.is_empty
			has_issues: not a_issues.is_empty
			code_not_empty: not a_code.is_empty
		do
			create Result.make (3000)
			Result.append ("The class " + a_class_name + " has the following issues:%N%N")

			across a_issues as ic loop
				Result.append ("- " + ic + "%N")
			end

			Result.append ("%N=== CURRENT CODE ===%N")
			Result.append (a_code)
			Result.append ("%N%N")

			Result.append ("Please fix these issues and output the corrected class.%N")
			Result.append (json_output_format_refinement)
		end

	build_test_prompt (a_class_name: STRING_32; a_code: STRING_32): STRING_32
			-- Build prompt to generate tests for a class.
		require
			name_not_empty: not a_class_name.is_empty
			code_not_empty: not a_code.is_empty
		do
			create Result.make (4000)
			Result.append ("Generate comprehensive tests for the Eiffel class: " + a_class_name + "%N%N")

			Result.append ("=== CLASS UNDER TEST ===%N")
			Result.append (a_code)
			Result.append ("%N%N")

			Result.append (test_generation_template)
		end

	build_single_class_prompt (a_class_name, a_description: STRING_32; a_features: detachable ARRAYED_LIST [STRING_32]): STRING_32
			-- Build prompt for generating a single class (class-level scope).
		require
			name_not_empty: not a_class_name.is_empty
		do
			create Result.make (3000)
			Result.append ("Generate a single Eiffel class based on this specification:%N%N")
			Result.append ("=== CLASS SPECIFICATION ===%N")
			Result.append ("Class name: " + a_class_name + "%N")
			if not a_description.is_empty then
				Result.append ("Description: " + a_description + "%N")
			end
			if attached a_features as l_feats and then not l_feats.is_empty then
				Result.append ("Features to implement:%N")
				across l_feats as ic loop
					Result.append ("  - " + ic + "%N")
				end
			end
			Result.append ("%N")
			Result.append (class_generation_instructions)
			Result.append ("%N")
			Result.append (json_output_format_class)
		end

	build_feature_prompt (a_class_name, a_feature_name, a_feature_type, a_description: STRING_32; a_existing_code: detachable STRING_32): STRING_32
			-- Build prompt for generating/modifying a single feature (feature-level scope).
		require
			class_not_empty: not a_class_name.is_empty
			feature_not_empty: not a_feature_name.is_empty
		do
			create Result.make (3000)
			if attached a_existing_code as l_code then
				Result.append ("Modify the feature '" + a_feature_name + "' in class " + a_class_name + "%N%N")
				Result.append ("=== EXISTING CLASS ===%N")
				Result.append (l_code)
				Result.append ("%N%N")
			else
				Result.append ("Add a new feature to class " + a_class_name + "%N%N")
			end

			Result.append ("=== FEATURE SPECIFICATION ===%N")
			Result.append ("Feature name: " + a_feature_name + "%N")
			Result.append ("Type: " + a_feature_type + " (command/query)%N")
			if not a_description.is_empty then
				Result.append ("Description: " + a_description + "%N")
			end

			Result.append ("%N=== FEATURE REQUIREMENTS ===%N")
			Result.append ("1. Follow Specification Hat: write contracts FIRST%N")
			Result.append ("2. Use proper naming: a_ for args, l_ for locals%N")
			Result.append ("3. Command-Query Separation: no side effects in queries%N")
			Result.append ("4. Complete postconditions (not just true, but COMPLETE)%N%N")

			Result.append (json_output_format_feature)
		end

feature {NONE} -- Templates

	system_design_template: STRING_32
			-- Template for initial system design prompt.
		do
			create Result.make (10000)
			Result.append (user_manual_reminder)
			Result.append ({STRING_32} "%N%N")
			Result.append (project_structure_requirements)
			Result.append ({STRING_32} "%N%N")
			Result.append (project_confinement_rules)
			Result.append ({STRING_32} "%N%N")
			Result.append ({STRING_32} "[
I need you to design an Eiffel system based on my requirements.

=== YOUR TASK ===
1. Analyze my requirements
2. Decompose into cohesive Eiffel classes
3. Output a structured specification in JSON format

=== REQUIREMENTS ===
[USER: Replace this section with your system requirements]
Example: "I need a library management system with book tracking, member management, and loan processing"

=== DESIGN PRINCIPLES (Simple Eiffel Ecosystem) ===
1. DESIGN BY CONTRACT (DBC):
   - Write contracts BEFORE implementation (Specification Hat)
   - Preconditions: what callers must guarantee
   - Postconditions: what feature guarantees (must be COMPLETE, not just true)
   - Class invariants: what's always true about objects

2. VOID SAFETY:
   - 'attached' for required references
   - 'detachable' for optional references
   - Pattern: if attached x as l_x then ... end

3. COMMAND-QUERY SEPARATION (CQS):
   - Commands modify state, return nothing
   - Queries return values, no side effects

4. NAMING CONVENTIONS:
   - Class: ALL_CAPS (LIBRARY_BOOK)
   - Feature: lower_snake_case (find_by_title)
   - Arguments: a_ prefix (a_name, a_count)
   - Locals: l_ prefix (l_result, l_file)
   - Booleans: is_/has_/can_ prefix (is_empty, has_key)

5. SINGLE RESPONSIBILITY:
   - Each class has one clear purpose
   - Complex internals, simple external interface

=== OUTPUT FORMAT ===
Respond with a JSON object containing the system specification:

```json
{
  "type": "system_spec",
  "system_name": "library_system",
  "description": "Library management system for tracking books and loans",
  "classes": [
    {
      "name": "LIBRARY_BOOK",
      "description": "Represents a book in the library catalog",
      "attributes": [
        {"name": "title", "type": "STRING", "description": "Book title"},
        {"name": "author", "type": "STRING", "description": "Author name"},
        {"name": "is_available", "type": "BOOLEAN", "description": "Availability status"}
      ],
      "features": [
        {"name": "check_out", "type": "command", "description": "Mark book as borrowed"},
        {"name": "return_book", "type": "command", "description": "Mark book as available"}
      ],
      "invariants": ["title not empty", "author not empty"]
    }
  ],
  "relationships": [
    {"from": "LIBRARY_CATALOG", "to": "LIBRARY_BOOK", "type": "contains"}
  ]
}
```

Output ONLY the JSON. No explanations before or after.

=== NEXT CLI COMMAND ===
Save this JSON response to a file and run:
  simple_codegen process --session <SESSION> --input <response_file.json>

This parses your system specification and generates the first class prompt.
The CLI will guide you through generating each class in sequence.
]")
		end

	class_generation_instructions: STRING_32
			-- Instructions for generating a single class.
		once
			Result := {STRING_32} "[
=== SPECIFICATION HAT (Write Contracts FIRST) ===
Follow the "vibe-contracting" principle: specify WHAT before HOW.

For EACH feature, answer these questions IN ORDER:
1. What must be true BEFORE this can be called? → require clause
2. What will be true AFTER this completes? → ensure clause
3. Is the postcondition COMPLETE, not just true? → Check for missing guarantees

=== NAMING CONVENTIONS (CRITICAL) ===
Class names:     ALL_CAPS with underscores (LIBRARY_BOOK, HASH_TABLE)
Feature names:   all_lowercase with underscores (set_owner, find_by_title)
Constants:       Initial_cap (Pi, Welcome_message)
Arguments:       a_ prefix (a_name, a_count, a_item)
Local variables: l_ prefix for clarity (l_result, l_file, l_count)
Loop cursors:    ic for across loops (across items as ic loop ...)
Boolean queries: is_, has_, can_ prefix (is_empty, has_key, can_extend)

=== CONTRACT TAG NAMING ===
Preconditions:   name_not_empty, index_valid, item_attached, count_positive
Postconditions:  name_set, count_increased, result_not_void, item_added
Invariants:      count_valid, bounds_consistent, items_attached

=== CONTRACTS (AGGRESSIVE BUT MEANINGFUL) ===
- DO add contracts that express domain logic
- DO use 'old' for state comparisons: count = old count + 1
- DO NOT add trivial contracts (x /= Void in void-safe code is redundant)
- ALWAYS check postcondition completeness (is it TRUE but INCOMPLETE?)

Example of INCOMPLETE vs COMPLETE postcondition:
  INCOMPLETE: ensure has_item: items.has (a_item)
  COMPLETE:   ensure has_item: items.has (a_item); count_increased: count = old count + 1

=== FEATURE CLAUSE STRUCTURE ===
feature {NONE} -- Initialization
    make, make_from_*, make_with_*
feature -- Access
    Public queries returning values
feature -- Status report
    Boolean status queries (is_*, has_*)
feature -- Element change
    Commands that modify state
feature {NONE} -- Implementation
    Private helpers

=== COMMAND-QUERY SEPARATION ===
- Queries (functions): Return values, NO side effects
- Commands (procedures): Modify state, NO return value
- NEVER mix: a setter should NOT return the new value

=== VOID SAFETY ===
- Use 'attached' for required references
- Use 'detachable' for optional references
- Initialize ALL attributes in creation procedures
- Pattern: if attached x as l_x then ... end

=== SIMPLE_* LIBRARY GOTCHAS (CRITICAL) ===
SIMPLE_JSON (SIMPLE_JSON_VALUE):
- All query features (item, as_array, as_object) return DETACHABLE
- MUST wrap with 'attached' pattern: if attached obj.item ("key") as val then ...
- Use is_number (NOT is_real) to check for numeric values
- Use as_string_32 (NOT as_string) for string values
- For numeric values, check is_integer FIRST:
    if val.is_integer then x := val.as_integer.to_double
    elseif val.is_number then x := val.as_real end

SIMPLE_FILE:
- Creation: create l_file.make (a_path) -- NOT make_open_read!
- Reading: l_content := l_file.read_all OR l_file.read_text
- No close method - file closes automatically after read
- Check exists before reading: if l_file.exists then ...

SIMPLE_CSV:
- Use parse (content) to parse a string, parse_file (path) for files
- Access rows: csv.row_at (i) returns ARRAYED_LIST [STRING]
- Access cells: csv.row_at (i).i_th (col)
- Row/col indices are 1-based

UNICODE OUTPUT (STRING_32/CHARACTER_32):
- STRING_32.to_string_8 has precondition is_valid_as_string_8 - FAILS on Unicode!
- CHARACTER_32.out returns "U+XXXX" code point, NOT the character
- For Unicode output, use: print (l_string_32) or print (l_char_32)
- Buffer CHARACTER_32 to STRING_32, then print: l_buf.append_character (char); print (l_buf)
- If class needs both STRING_8 buffer AND Unicode: add separate STRING_32 attribute

MANIFEST ARRAYS WITH UNICODE:
- Mixed types in manifest arrays cause VWMA warning
- For CHARACTER_32 arrays with ' ' (CHAR_8) and '%/0x2588/' (CHAR_32):
    WRONG:  arr := << ' ', '%/0x2588/' >>
    RIGHT:  arr := {ARRAY [CHARACTER_32]} << ' ', '%/0x2588/' >>

STANDARD I/O:
- stdin read: io.input.end_of_file (NOT io.end_of_file)
- stdin loop: from until io.input.end_of_file loop io.read_line ... end

ARGUMENTS_32:
- Has NO make feature - do NOT try to rename it
- Just inherit: inherit ARGUMENTS_32 (no rename clause)
- Access args: argument (i) returns STRING_32, argument_count for count

=== EIFFEL INHERITANCE GOTCHAS ===
DEFERRED FEATURES:
- Do NOT use 'redefine' for deferred features - just implement them
- WRONG: inherit PARENT redefine deferred_feature end
- RIGHT: inherit PARENT (no redefine clause, just provide implementation)
- Only use 'redefine' for effective (already implemented) features

STRING ESCAPING:
- Quote in string: use %%" (NOT %%%")
- Newline: %N
- Tab: %T
- Percent: %%

=== STANDARD FEATURE NAMES (EiffelBase) ===
Access:  item, count, capacity
Status:  is_empty, is_full, has, is_extendible
Commands: extend, put, replace, remove, prune, wipe_out
Creation: make, make_empty, make_from_*, make_with_*

=== CLASS STRUCTURE ===
- End class with just 'end' (not 'end CLASS_NAME')
- Header comment after each feature signature
- Group related features under appropriate clause
]"
		end

	json_output_format_class: STRING_32
			-- JSON output format for class generation (generic).
		once
			Result := json_output_format_class_with_session ("<SESSION>")
		end

	json_output_format_class_with_session (a_session: STRING_32): STRING_32
			-- JSON output format for class generation with specific session name.
		do
			create Result.make (1000)
			Result.append ("=== OUTPUT FORMAT ===%N")
			Result.append ("Respond with a JSON object containing the generated class:%N%N")
			Result.append ("```json%N")
			Result.append ("{%N")
			Result.append ("  %"type%": %"class_code%",%N")
			Result.append ("  %"class_name%": %"LIBRARY_BOOK%",%N")
			Result.append ("  %"code%": %"note\n    description: \%"...\%"\nclass\n    LIBRARY_BOOK\n...\nend%",%N")
			Result.append ("  %"notes%": %"Brief note about implementation decisions%"%N")
			Result.append ("}%N")
			Result.append ("```%N%N")
			Result.append ("The %"code%" field must contain the complete, valid Eiffel class.%N")
			Result.append ("Output ONLY the JSON. No explanations before or after.%N%N")
			Result.append ("=== NEXT CLI COMMAND ===%N")
			Result.append ("Save this JSON response to a file (e.g., response.json) and run:%N")
			Result.append ("  simple_codegen process --session " + a_session + " --input response.json%N%N")
			Result.append ("This parses your response and either:%N")
			Result.append ("- Generates next class prompt (if more classes pending)%N")
			Result.append ("- Indicates ready for: simple_codegen assemble --session " + a_session + " --output <path>%N")
		end

	json_output_format_refinement: STRING_32
			-- JSON output format for refinement.
		once
			Result := {STRING_32} "[
=== OUTPUT FORMAT ===
Respond with a JSON object containing the refined class:

```json
{
  "type": "refinement",
  "class_name": "LIBRARY_BOOK",
  "changes": ["Fixed missing precondition", "Added postcondition to check_out"],
  "code": "note\n    description: \"...\"\nclass\n    LIBRARY_BOOK\n...\nend"
}
```

Output ONLY the JSON. No explanations before or after.

=== NEXT CLI COMMAND ===
Save this JSON response to a file and run:
  simple_codegen process --session <SESSION> --input <response_file.json>

After refinement is processed, validate the class:
  simple_codegen validate --input <assembled_project>/src/<class_name>.e

If validation passes, proceed to assembly or next class.
If issues remain, another refinement prompt will be generated.
]"
		end

	json_output_format_feature: STRING_32
			-- JSON output format for feature generation.
		once
			Result := {STRING_32} "[
=== OUTPUT FORMAT ===
Respond with a JSON object containing the feature and updated class:

```json
{
  "type": "feature_code",
  "class_name": "LIBRARY_BOOK",
  "feature_name": "set_title",
  "feature_type": "command",
  "code": "note\n    description: \"...\"\nclass\n    LIBRARY_BOOK\n...\nend",
  "notes": "Added set_title command with precondition for non-empty title"
}
```

The "code" field must contain the complete class with the new/modified feature.
Output ONLY the JSON. No explanations before or after.

=== NEXT CLI COMMAND ===
Save this JSON response to a file and run:
  simple_codegen process --session <SESSION> --input <response_file.json>

Then validate the updated class:
  simple_codegen validate --input <assembled_project>/src/<class_name>.e

If adding more features, use:
  simple_codegen add-feature --session <SESSION> --class <CLASS> --feature <name> --type <command|query>
]"
		end

	test_generation_template: STRING_32
			-- Template for test generation prompt.
		once
			Result := {STRING_32} "[
=== TEST GENERATION GUIDELINES ===

Generate comprehensive tests using Eiffel's Testing framework.
Test class should inherit from EQA_TEST_SET.

1. HAPPY PATH TESTS:
   - Test normal operation with valid inputs
   - Verify postconditions are satisfied
   - Check state changes after commands
   - Test typical use case scenarios

2. EDGE CASE TESTS (Critical):
   - Boundary values (empty strings, zero, max values)
   - Precondition boundaries (just valid, just invalid)
   - State transitions at limits
   - Concurrent-like scenarios if applicable

3. CONTRACT VERIFICATION:
   - Tests that verify preconditions reject bad input
   - Tests that verify postconditions hold
   - Tests that verify invariants are maintained

4. TEST NAMING:
   - test_<feature>_<scenario> (test_add_contact_success)
   - test_<feature>_<edge_case> (test_add_contact_empty_name_rejected)

5. TEST STRUCTURE:
   feature -- Test: <Feature Group>
       test_feature_happy_path
       test_feature_edge_case_1
       test_feature_edge_case_2

=== OUTPUT FORMAT ===
Respond with a JSON object containing the test class:

```json
{
  "type": "test_class",
  "class_name": "TEST_LIBRARY_BOOK",
  "target_class": "LIBRARY_BOOK",
  "test_count": 8,
  "code": "note\n    description: \"Tests for LIBRARY_BOOK\"\nclass\n    TEST_LIBRARY_BOOK\ninherit\n    EQA_TEST_SET\n...\nend"
}
```

Output ONLY the JSON. No explanations before or after.

=== NEXT CLI COMMAND ===
Save this JSON response to a file and run:
  simple_codegen process --session <SESSION> --input <response_file.json>

Then compile and run the tests:
  simple_codegen compile --session <SESSION> --project <assembled_project>

If tests fail, refinement prompts will be auto-generated for the failing classes.
Generate tests for other classes:
  simple_codegen generate-tests --session <SESSION> --class <ANOTHER_CLASS>
]"
		end

feature -- Research and Planning Prompts

	build_research_prompt (a_topic, a_scope: STRING_32): STRING_32
			-- Build 7-step in-depth research prompt.
		require
			topic_not_empty: not a_topic.is_empty
			scope_not_empty: not a_scope.is_empty
		do
			create Result.make (4000)
			Result.append ("=== 7-STEP IN-DEPTH RESEARCH ===%N%N")
			Result.append ("Topic: ")
			Result.append (a_topic)
			Result.append ("%N")
			Result.append ("Scope: ")
			Result.append (a_scope)
			Result.append ("%N")
			Result.append ("Session: ")
			Result.append (session.session_name)
			Result.append ("%N%N")

			Result.append (research_7_step_template)
			Result.append ("%N%N")
			Result.append (json_output_format_research)
		end

	build_plan_prompt (a_goal: STRING_32; a_class_name: detachable STRING_32; a_existing_code: detachable STRING_32): STRING_32
			-- Build design-build-implement-test planning prompt.
		require
			goal_not_empty: not a_goal.is_empty
		do
			create Result.make (4000)
			Result.append ("=== DESIGN-BUILD-IMPLEMENT-TEST PLANNING ===%N%N")
			Result.append ("Goal: ")
			Result.append (a_goal)
			Result.append ("%N")
			Result.append ("Session: ")
			Result.append (session.session_name)
			Result.append ("%N")

			if attached a_class_name as l_cn then
				Result.append ("Target class: ")
				Result.append (l_cn)
				Result.append ("%N")
				if attached a_existing_code as l_code then
					Result.append ("%N=== EXISTING CODE ===%N")
					Result.append (l_code)
					Result.append ("%N")
				end
			else
				Result.append ("Scope: System-wide%N")
			end

			Result.append ("%N")
			Result.append (planning_dbit_template)
			Result.append ("%N%N")
			Result.append (json_output_format_plan)
		end

	research_7_step_template: STRING_32
			-- Template for 7-step research process.
		do
			create Result.make (8000)
			Result.append (user_manual_reminder)
			Result.append ({STRING_32} "%N%N")
			Result.append (project_structure_requirements)
			Result.append ({STRING_32} "%N%N")
			Result.append (project_confinement_rules)
			Result.append ({STRING_32} "%N%N")
			Result.append ({STRING_32} "[
=== 7-STEP RESEARCH PROCESS ===

Execute each step thoroughly and document your findings.

STEP 1: UNDERSTAND THE PROBLEM/DOMAIN
- What exactly is being asked?
- What domain knowledge is required?
- What are the key concepts involved?

STEP 2: RESEARCH EXISTING SOLUTIONS
- What similar solutions exist?
- What libraries/tools are available?
- What patterns have worked in similar contexts?

STEP 3: IDENTIFY REQUIREMENTS/CONSTRAINTS
- What are the functional requirements?
- What are the non-functional requirements (performance, scalability)?
- What constraints exist (technology, time, resources)?
- What simple_* ecosystem libraries can be used?

STEP 4: EVALUATE OPTIONS/TRADE-OFFS
- What are the possible approaches?
- What are the pros/cons of each?
- Which fits best with Eiffel/DBC principles?

STEP 5: DESIGN APPROACH
- High-level architecture
- Class decomposition
- Key contracts (preconditions, postconditions, invariants)
- Integration points with existing code

STEP 6: DOCUMENT DECISIONS
- What was decided and why?
- What alternatives were rejected?
- What assumptions were made?

STEP 7: CREATE IMPLEMENTATION PLAN
- Ordered steps to implement
- Dependencies between steps
- Verification criteria for each step
- Next CLI commands to execute
]")
		end

	planning_dbit_template: STRING_32
			-- Template for Design-Build-Implement-Test cycle.
		once
			Result := {STRING_32} "[
=== DESIGN-BUILD-IMPLEMENT-TEST (DBIT) CYCLE ===

Apply the HATS methodology with this four-phase cycle:

PHASE 1: DESIGN (Specification Hat)
- Start with contracts FIRST
- Define preconditions: what must callers provide?
- Define postconditions: what does the feature guarantee?
- Define invariants: what is always true about the class?
- NO implementation details yet - just contracts

PHASE 2: BUILD (Construction Hat)
- Implement the feature bodies
- Follow the contracts you designed
- Use established patterns (Builder, Facade, etc.)
- Apply SCOOP patterns if concurrency needed

PHASE 3: IMPLEMENT (Integration Hat)
- Wire up with existing classes
- Handle dependencies
- Ensure ECF configuration is correct
- Verify library imports

PHASE 4: TEST (Verification Hat)
- Happy path tests: normal operation
- Edge case tests: boundary conditions
- Contract verification: preconditions reject bad input
- Run compilation and fix any issues
- Iterate until all tests pass

=== CHECKLIST ===
[ ] All features have preconditions
[ ] All features have postconditions (not just True)
[ ] Class has meaningful invariant
[ ] Void safety respected (attached/detachable)
[ ] Command-Query Separation followed
[ ] Naming conventions applied (a_, l_, ic)
[ ] SCOOP-compatible if concurrent
]"
		end

	json_output_format_research: STRING_32
			-- JSON output format for research results.
		once
			Result := {STRING_32} "[
=== OUTPUT FORMAT ===
Respond with a JSON object containing your research findings:

```json
{
  "type": "research",
  "topic": "topic description",
  "scope": "system|class|feature",
  "steps": {
    "step_1_understand": "Problem analysis...",
    "step_2_existing": "Existing solutions found...",
    "step_3_requirements": "Requirements identified...",
    "step_4_evaluate": "Options evaluated...",
    "step_5_design": "Design approach...",
    "step_6_decisions": "Decisions documented...",
    "step_7_plan": "Implementation plan..."
  },
  "recommendations": ["Recommendation 1", "Recommendation 2"],
  "next_actions": ["CLI command 1", "CLI command 2"]
}
```

Output ONLY the JSON. No explanations before or after.

=== NEXT CLI COMMAND ===
Based on research findings, typically proceed with:
  simple_codegen plan --session <SESSION> --goal "implement findings"

Or if ready to generate code directly:
  simple_codegen init --session <NEW_SESSION> (for new project)
  simple_codegen add-feature --session <SESSION> --class <CLASS> --feature <name> --type <type>
]"
		end

	build_c_integration_prompt (a_mode, a_target: STRING_32): STRING_32
			-- Build C/C++ integration prompt based on mode.
		require
			mode_not_empty: not a_mode.is_empty
			target_not_empty: not a_target.is_empty
		do
			create Result.make (5000)
			Result.append ("=== C/C++ INTEGRATION ===%N%N")
			Result.append ("Mode: ")
			Result.append (a_mode)
			Result.append ("%N")
			Result.append ("Target: ")
			Result.append (a_target)
			Result.append ("%N")
			Result.append ("Session: ")
			Result.append (session.session_name)
			Result.append ("%N%N")

			if a_mode.is_case_insensitive_equal ("wrap") then
				Result.append (c_inline_wrap_template)
			elseif a_mode.is_case_insensitive_equal ("library") then
				Result.append (c_library_template)
			elseif a_mode.is_case_insensitive_equal ("win32") then
				Result.append (c_win32_template)
			else
				Result.append (c_inline_wrap_template)
			end

			Result.append ("%N%N")
			Result.append (json_output_format_c_integration)
		end

	c_inline_wrap_template: STRING_32
			-- Template for inline C wrapping (Eric Bezault pattern).
		once
			create Result.make (2000)
			Result.append ("=== INLINE C EXTERNAL PATTERN (Eric Bezault) ===%N%N")
			Result.append ("Generate Eiffel class(es) with inline C externals following these rules:%N%N")
			Result.append ("1. ALL C CODE IN EIFFEL FILES - No separate .c files%N")
			Result.append ("2. Use 'external %"C inline use %%<header.h%%>%"' pattern%N")
			Result.append ("3. Wrap each C function with Eiffel contracts%N")
			Result.append ("4. Map types properly between C and Eiffel%N%N")
			Result.append ("INLINE EXTERNAL TEMPLATE:%N")
			Result.append ("  feature_name (a_arg: EIFFEL_TYPE): RETURN_TYPE%N")
			Result.append ("      -- Description%N")
			Result.append ("    require%N")
			Result.append ("      valid_arg: -- precondition%N")
			Result.append ("    external%N")
			Result.append ("      %"C inline use %%<header.h%%>%"%N")
			Result.append ("    alias%N")
			Result.append ("      %"[ // C code here; return (EIF_TYPE)result; ]%"%N")
			Result.append ("    ensure%N")
			Result.append ("      -- postcondition%N")
			Result.append ("    end%N%N")
			Result.append ("TYPE MAPPINGS:%N")
			Result.append ("  INTEGER = int, EIF_INTEGER%N")
			Result.append ("  INTEGER_64 = long long, EIF_INTEGER_64%N")
			Result.append ("  REAL_64 = double, EIF_REAL_64%N")
			Result.append ("  BOOLEAN = int (0/1), EIF_BOOLEAN%N")
			Result.append ("  POINTER = void*, EIF_POINTER%N")
			Result.append ("  STRING = char* (via C_STRING class)%N%N")
			Result.append ("MEMORY RULES:%N")
			Result.append ("  - Use MANAGED_POINTER for Eiffel-owned buffers%N")
			Result.append ("  - Document who owns allocated memory%N")
			Result.append ("  - Pair malloc with free%N")
			Result.append ("  - Check for NULL before dereferencing%N%N")
			Result.append ("INCLUDE PATTERNS:%N")
			Result.append ("  - System: use %%<stdio.h%%>%N")
			Result.append ("  - Multiple: use %%<h1.h%%>, %%<h2.h%%>%N")
			Result.append ("  - Local: use %"local.h%"%N")
		end

	c_library_template: STRING_32
			-- Template for external C library integration.
		once
			create Result.make (2000)
			Result.append ("=== EXTERNAL C LIBRARY INTEGRATION ===%N%N")
			Result.append ("Generate Eiffel wrapper class(es) for an external C/C++ library.%N%N")
			Result.append ("1. ECF CONFIGURATION:%N")
			Result.append ("   Generate proper external_include, external_library elements%N")
			Result.append ("   Handle platform differences (Windows .lib vs Unix -l)%N%N")
			Result.append ("2. WRAPPER CLASS STRUCTURE:%N")
			Result.append ("   note%N")
			Result.append ("     description: %"Wrapper for <library>%"%N")
			Result.append ("   class%N")
			Result.append ("     SIMPLE_<LIBRARY>%N")
			Result.append ("   create%N")
			Result.append ("     make%N")
			Result.append ("   feature -- Initialization%N")
			Result.append ("     make%N")
			Result.append ("       do%N")
			Result.append ("         initialize_library%N")
			Result.append ("       end%N")
			Result.append ("   feature -- Library Operations%N")
			Result.append ("     -- Wrapped functions here%N")
			Result.append ("   feature {NONE} -- C Externals%N")
			Result.append ("     -- Inline C externals%N")
			Result.append ("   feature {NONE} -- Cleanup%N")
			Result.append ("     dispose%N")
			Result.append ("       do%N")
			Result.append ("         cleanup_library%N")
			Result.append ("       end%N")
			Result.append ("   end%N%N")
			Result.append ("3. ECF SNIPPET FORMAT:%N")
			Result.append ("   <external_include location=%"path/to/headers%"/>%N")
			Result.append ("   <external_library location=%"lib.lib%">%N")
			Result.append ("     <condition>%N")
			Result.append ("       <platform value=%"windows%"/>%N")
			Result.append ("     </condition>%N")
			Result.append ("   </external_library>%N")
			Result.append ("   <external_library location=%"-lname%">%N")
			Result.append ("     <condition>%N")
			Result.append ("       <platform excluded_value=%"windows%"/>%N")
			Result.append ("     </condition>%N")
			Result.append ("   </external_library>%N%N")
			Result.append ("4. LIFECYCLE MANAGEMENT:%N")
			Result.append ("   - Initialize library in make%N")
			Result.append ("   - Clean up in dispose (inherit DISPOSABLE)%N")
			Result.append ("   - Handle library load failures gracefully%N")
		end

	c_win32_template: STRING_32
			-- Template for Win32 API wrapping.
		once
			create Result.make (3000)
			Result.append ("=== WIN32 API WRAPPING ===%N%N")
			Result.append ("Generate Eiffel wrapper for Win32 API functions.%N%N")
			Result.append ("1. ALWAYS USE <windows.h>:%N")
			Result.append ("   external%N")
			Result.append ("     %"C inline use <windows.h>%"%N")
			Result.append ("   alias%N")
			Result.append ("     %"[ // Win32 code here ]%"%N")
			Result.append ("   end%N%N")
			Result.append ("2. TYPE MAPPINGS (Win32 -> Eiffel):%N")
			Result.append ("   DWORD -> NATURAL_32%N")
			Result.append ("   HANDLE -> POINTER%N")
			Result.append ("   HWND -> POINTER%N")
			Result.append ("   BOOL -> BOOLEAN (0=False, nonzero=True)%N")
			Result.append ("   LPCTSTR -> POINTER (use WEL_STRING for conversion)%N")
			Result.append ("   LPWSTR -> POINTER (for wide strings)%N")
			Result.append ("   HRESULT -> INTEGER%N%N")
			Result.append ("3. ERROR HANDLING:%N")
			Result.append ("   win32_get_last_error: INTEGER%N")
			Result.append ("     external%N")
			Result.append ("       %"C inline use <windows.h>%"%N")
			Result.append ("     alias%N")
			Result.append ("       %"return (EIF_INTEGER)GetLastError();%"%N")
			Result.append ("     end%N%N")
			Result.append ("4. STRING HANDLING:%N")
			Result.append ("   - Use WEL_STRING for LPCTSTR/LPWSTR conversion%N")
			Result.append ("   - Use C_STRING for LPSTR/char* conversion%N")
			Result.append ("   - Remember Windows uses UTF-16 (wide strings)%N%N")
			Result.append ("5. HANDLE MANAGEMENT:%N")
			Result.append ("   - Store handles as POINTER%N")
			Result.append ("   - Close handles in dispose%N")
			Result.append ("   - Check for INVALID_HANDLE_VALUE%N%N")
			Result.append ("EXAMPLE:%N")
			Result.append ("  create_file (a_path: STRING_32): POINTER%N")
			Result.append ("      -- Open file, return handle.%N")
			Result.append ("    local%N")
			Result.append ("      l_path: WEL_STRING%N")
			Result.append ("    do%N")
			Result.append ("      create l_path.make (a_path)%N")
			Result.append ("      Result := c_create_file (l_path.item)%N")
			Result.append ("    end%N%N")
			Result.append ("  c_create_file (a_path: POINTER): POINTER%N")
			Result.append ("    external%N")
			Result.append ("      %"C inline use <windows.h>%"%N")
			Result.append ("    alias%N")
			Result.append ("      %"[ return (EIF_POINTER)CreateFileW((LPCWSTR)$a_path, ")
			Result.append ("GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, ")
			Result.append ("FILE_ATTRIBUTE_NORMAL, NULL); ]%"%N")
			Result.append ("    end%N")
		end

	json_output_format_c_integration: STRING_32
			-- JSON output format for C integration.
		once
			Result := {STRING_32} "[
=== OUTPUT FORMAT ===
Respond with a JSON object containing the C integration code:

```json
{
  "type": "c_integration",
  "mode": "wrap|library|win32",
  "target": "description of what's being wrapped",
  "classes": [
    {
      "name": "SIMPLE_WRAPPER",
      "code": "note\n  description: \"...\"\nclass\n  SIMPLE_WRAPPER\n...\nend"
    }
  ],
  "ecf_snippet": "<external_include location=\"...\"/>...",
  "headers_needed": ["<header1.h>", "<header2.h>"],
  "libraries_needed": ["lib1", "lib2"],
  "notes": "Implementation notes, caveats, platform specifics"
}
```

Output ONLY the JSON. No explanations before or after.

=== NEXT CLI COMMAND ===
After receiving the integration code:
1. Add ECF snippet to your project's .ecf file
2. Create the wrapper class file(s)
3. Compile and test:
   simple_codegen compile --session <SESSION> --project <path>

If compilation fails, refinement prompts will be generated.
]"
		end

	json_output_format_plan: STRING_32
			-- JSON output format for planning results.
		once
			Result := {STRING_32} "[
=== OUTPUT FORMAT ===
Respond with a JSON object containing your plan:

```json
{
  "type": "plan",
  "goal": "goal description",
  "scope": "system|class|feature",
  "phases": {
    "design": {
      "contracts": ["require: ...", "ensure: ...", "invariant: ..."],
      "classes": ["CLASS_1", "CLASS_2"],
      "features": ["feature_1", "feature_2"]
    },
    "build": {
      "tasks": ["Task 1", "Task 2"],
      "dependencies": ["simple_file", "simple_json"]
    },
    "implement": {
      "integration_points": ["Point 1", "Point 2"],
      "ecf_changes": ["Add library X"]
    },
    "test": {
      "happy_path": ["Test scenario 1"],
      "edge_cases": ["Edge case 1", "Edge case 2"],
      "contract_tests": ["Precondition test 1"]
    }
  },
  "next_cli_commands": [
    "simple_codegen add-feature --session S --class C --feature f --type command",
    "simple_codegen compile --session S --project P"
  ]
}
```

Output ONLY the JSON. No explanations before or after.

=== NEXT CLI COMMAND ===
Execute the first command from next_cli_commands array.
The plan will guide subsequent commands through the DBIT cycle.
]"
		end

feature -- User Manual Reference

	user_manual_reminder: STRING_32
			-- Reminder to read the Claude User Manual first.
		once
			Result := {STRING_32} "[
=== CLAUDE USER MANUAL REMINDER ===

BEFORE proceeding, ensure you have read and understood:
  /d/prod/simple_code/CLAUDE_USER_MANUAL.md

This manual contains:
- How to determine SCALE and SCOPE of work
- The 6 lifecycle stages and when to apply them
- Mandatory rules for project confinement
- Complete command reference
- Common mistakes to avoid

If you haven't read it, STOP and read it now.
If you have read it, proceed with the work below.

=====================================
]"
		end

feature -- Project Structure Requirements

	project_structure_requirements: STRING_32
			-- Complete project structure requirements for simple_* pattern.
		once
			Result := {STRING_32} "[
=== SCALE AND SCOPE AWARENESS ===

FIRST: Determine the SCALE and SCOPE of the request.

SCALE (what level are you working at?):
  - SYSTEM:   New project/library (requires FULL structure below)
  - SUBSYSTEM: New module within existing project (partial structure)
  - CLUSTER:  Group of related classes (src/ changes only)
  - CLASS:    Single class (src/ file only)
  - FEATURE:  Single feature in existing class (edit only)

SCOPE (what dev-ops stages are needed?):
  For SYSTEM scale → ALL stages (1-6)
  For SUBSYSTEM scale → Stages 2-5 (skip skeleton if exists)
  For CLUSTER scale → Stages 2-3, maybe 5
  For CLASS scale → Stage 2, maybe 3
  For FEATURE scale → Stage 2 only (edit existing file)

=== SIMPLE_* PROJECT STRUCTURE (FOR SYSTEM SCALE) ===

NEW projects MUST have this complete structure:

PROJECT_ROOT/
├── project_name.ecf        # ECF configuration with library AND test targets
├── README.md               # Project description, usage, examples
├── CHANGELOG.md            # Version history
├── .gitignore              # Git ignore patterns
├── src/                    # Source code
│   ├── main_class.e
│   └── supporting_classes.e
├── testing/                # Test classes
│   ├── test_app.e          # Test runner (root class for test target)
│   └── lib_tests.e         # Test cases inheriting TEST_SET_BASE
├── docs/                   # Documentation
│   ├── index.html          # Main documentation page
│   └── api/                # API documentation (optional)
├── bin/                    # Compiled binaries (deployed)
│   └── project_name.exe
└── inno/                   # Installer files (optional)
    ├── project_name.iss    # INNO Setup script
    └── Output/             # Built installer

=== LIFECYCLE STAGES ===

You MUST complete ALL stages in order:

STAGE 1: PROJECT SKELETON
- Create directory structure (src/, testing/, docs/, bin/)
- Create ECF with both library and test targets
- Create README.md with project description
- Create CHANGELOG.md with initial version
- Create .gitignore

STAGE 2: CODE GENERATION
- Generate main classes in src/
- Apply DBC, void safety, SCOOP patterns
- Validate with simple_codegen validator

STAGE 3: TEST CREATION
- Create test_app.e (test runner root class)
- Create lib_tests.e (test cases)
- ECF test target must include testing cluster
- Use simple_testing library

STAGE 4: DOCUMENTATION
- Create docs/index.html with:
  - Project overview
  - API reference
  - Usage examples
  - Installation instructions

STAGE 5: BUILD AND DEPLOY
- Compile with test target, run tests
- Compile release target (finalized)
- Copy binary to bin/ folder
- Deploy to /d/prod/bin/ if ecosystem tool

STAGE 6: INSTALLER (optional for CLI tools)
- Create INNO Setup script
- Build installer
- Test installation/uninstallation

=== CLI COMMANDS FOR EACH STAGE ===

Stage 1: simple_codegen init --session <name>
Stage 2: simple_codegen generate --session <name>
Stage 3: simple_codegen generate-tests --session <name>
Stage 4: simple_codegen docs --session <name>
Stage 5: simple_codegen compile --session <name> --project <path>
Stage 6: simple_codegen inno --session <name>

=== VERIFICATION CHECKLIST ===

Before declaring project COMPLETE:
[ ] ECF has both main AND test targets
[ ] testing/ folder exists with test_app.e and lib_tests.e
[ ] docs/ folder exists with index.html
[ ] README.md exists with project description
[ ] CHANGELOG.md exists with version history
[ ] .gitignore exists
[ ] bin/ folder exists with compiled binary
[ ] All tests pass
[ ] Documentation is complete
]"
		end

feature -- Project Confinement Rules

	project_confinement_rules: STRING_32
			-- Rules for confining work to the project directory.
		once
			Result := {STRING_32} "[
=== PROJECT CONFINEMENT (CRITICAL) ===
ALL work MUST be confined to the project directory.

1. FILE CREATION:
   - ONLY create files inside the project directory
   - NEVER create files in parent directories (e.g., /d/prod/)
   - All source files go in project_root/src/
   - All generated files stay in project_root/

2. COMPILATION - USE CLI TOOLS (NOT ec.exe/ec.sh directly):
   *** NEVER run ec.exe or ec.sh directly ***
   *** USE these CLI tools instead: ***

   For session-based projects:
     simple_codegen.exe compile --session <name> --project <path>

   For any Eiffel project:
     simple_codegen compile --session <name> --project <path>
     (compiles from correct directory, handles errors)

   These tools:
   - Automatically run from correct directory
   - Create EIFGENs in proper location
   - Handle refinement prompts on errors
   - Track compilation history

3. ARTIFACTS:
   - Logs, temp files, output → project_root/
   - Test results → project_root/
   - EIFGENs → project_root/EIFGENs/
   - Documentation → project_root/docs/

4. VERIFICATION:
   Before ANY file operation, verify the path is INSIDE project_root.
   Pattern: path.has_substring(project_root)

VIOLATION of these rules causes:
- EIFGENs in wrong location (locks files elsewhere)
- Pollution of shared directories
- Confusion about what belongs to which project
]"
		end

	cleanup_rules: STRING_32
			-- Rules for cleaning up after completion.
		once
			Result := {STRING_32} "[
=== CLEANUP (Required when DONE) ===
Before finishing work, clean up resources:

1. TERMINATE PROCESSES:
   - Ensure no background compilations running
   - Kill any spawned subprocesses (ec.exe, finish_freezing.exe)
   - Release file locks

2. TEMPORARY FILES:
   - Delete any temp files created during work
   - Remove intermediate artifacts not needed
   - Clean response.json, prompt.txt if one-time use

3. VERIFY NO LOCKS:
   - Check that project EIFGENs is not locked
   - Ensure no files held open

4. REPORT ARTIFACTS:
   When done, list what was created:
   - New/modified source files
   - Binaries deployed
   - Config files updated

COMMAND to verify cleanup:
  Check for locks: File Locksmith (Windows) or lsof (Unix)
  Check processes: tasklist | grep ec.exe (Windows)
]"
		end

	full_session_rules: STRING_32
			-- Combined rules for the session (manual + structure + confinement + cleanup).
		do
			create Result.make (8000)
			Result.append (user_manual_reminder)
			Result.append ({STRING_32} "%N%N")
			Result.append (project_structure_requirements)
			Result.append ({STRING_32} "%N%N")
			Result.append (project_confinement_rules)
			Result.append ({STRING_32} "%N%N")
			Result.append (cleanup_rules)
		end

invariant
	session_valid: session.is_valid

end
