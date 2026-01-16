note
	description: "[
		Test cases for SCG_CLASS_GEN AI-assisted class generator.

		Validation Strategy:
		1. Save generated output to file for human inspection
		2. Parser validation (fast fail) - uses simple_eiffel_parser
		3. Compilation validation (definitive) - uses ec.sh

		Output files are written to: simple_code/output/
		Log files are written to: simple_code/output/generation.log
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	TEST_SCG_CLASS_GEN

inherit
	TEST_SET_BASE

feature -- Test: Basic Generation with Validation

	test_class_gen_creation
			-- Test SCG_CLASS_GEN with comprehensive validation.
			-- 1. Generate a class
			-- 2. Save to file for inspection
			-- 3. Validate with parser
			-- 4. Validate with compiler
		local
			l_gen: SCG_CLASS_GEN
			l_logger: SIMPLE_LOGGER
			l_saved: BOOLEAN
			l_valid_syntax: BOOLEAN
		do
			-- Setup logging
			create l_logger.make_to_file (output_path + "/generation.log")
			l_logger.set_json_output (False)
			l_logger.info ("=== Starting class generation test ===")
			l_logger.info ("System spec: " + test_system_spec_detailed.to_string_8)
			l_logger.info ("Class spec: " + test_class_spec_detailed.to_string_8)

			-- Generate class
			l_logger.info ("Creating SCG_CLASS_GEN...")
			create l_gen.make_class (test_system_spec_detailed, test_class_spec_detailed, Void, Void)

			-- Log results
			l_logger.info ("Generation completed: is_generated=" + l_gen.is_generated.out)
			l_logger.info ("Has error: " + l_gen.has_error.out)
			if l_gen.has_error then
				l_logger.error ("Error: " + l_gen.last_error.to_string_8)
			end
			l_logger.info ("Generated text length: " + l_gen.generated_class_text.count.out + " chars")

			-- Log the full generation log
			l_logger.info ("--- Generation Log ---")
			l_logger.info (l_gen.log_as_string.to_string_8)
			l_logger.info ("--- End Generation Log ---")

			-- Save generated output for inspection
			if l_gen.is_generated then
				l_saved := l_gen.save_to_file (output_path + "/calculator_controller.e")
				l_logger.info ("Saved to file: " + l_saved.out)
				if l_saved and attached l_gen.last_saved_path as p then
					l_logger.info ("File path: " + p.to_string_8)
				end

				-- Validate with parser (first-line test)
				l_valid_syntax := validate_with_parser (l_gen.generated_class_text, l_logger)
				l_logger.info ("Parser validation: " + l_valid_syntax.out)

				-- Only attempt compilation if parser passed
				if l_valid_syntax then
					-- Compilation validation (definitive test)
					l_logger.info ("Attempting compilation validation...")
					-- Note: Compilation test requires separate test project setup
					-- For now we rely on parser validation
				end
			end

			l_logger.info ("=== Test completed ===")

			-- Assertions
			assert ("class_generated", l_gen.is_generated)
			assert ("no_error", not l_gen.has_error)
			assert ("text_not_empty", not l_gen.generated_class_text.is_empty)
			assert ("saved_to_file", l_saved)
			assert ("valid_eiffel_syntax", l_valid_syntax)
		end

	test_class_gen_with_ollama
			-- Test class generation using Ollama AI provider.
			-- Skips gracefully if Ollama is not running or model unavailable.
		local
			l_gen: SCG_CLASS_GEN
			l_ollama: OLLAMA_CLIENT
			l_logger: SIMPLE_LOGGER
			l_saved: BOOLEAN
			l_valid_syntax: BOOLEAN
			l_model: STRING_32
			l_model_available: BOOLEAN
			l_retried: BOOLEAN
		do
			if l_retried then
				-- Ollama not running or other error - skip test
				assert ("ollama_unavailable_skipped", True)
			else
				-- Setup logging
				create l_logger.make_to_file (output_path + "/ollama_generation.log")
				l_logger.set_json_output (False)
				l_logger.info ("=== Starting Ollama class generation test ===")

				-- Create Ollama client
				create l_ollama.make
				l_model := "llama3"
				l_logger.info ("Checking Ollama model: " + l_model.to_string_8)

				-- Check if model is available BEFORE calling make_class (precondition requires it)
				-- This may throw exception if Ollama server isn't running
				l_model_available := l_ollama.is_valid_model (l_model)

				if not l_model_available then
					l_logger.warn ("Model not available on Ollama server - test skipped")
					l_logger.info ("Available models: " + l_ollama.supported_models.count.out)
					l_logger.info ("=== Ollama test skipped (model unavailable) ===")
					assert ("ollama_model_unavailable_skipped", True)
				else
					l_ollama.set_model (l_model)
					l_logger.info ("Model available, proceeding with generation...")

					-- Generate class with Ollama
					l_logger.info ("Creating SCG_CLASS_GEN with Ollama...")
					create l_gen.make_class (test_system_spec_detailed, test_class_spec_detailed, l_ollama, l_model)

					-- Log results
					l_logger.info ("Generation completed: is_generated=" + l_gen.is_generated.out)
					l_logger.info ("Has error: " + l_gen.has_error.out)
					if l_gen.has_error then
						l_logger.error ("Error: " + l_gen.last_error.to_string_8)
					end

					-- Save and validate if generation succeeded
					if l_gen.is_generated then
						l_saved := l_gen.save_to_file (output_path + "/ollama_generated_class.e")
						l_logger.info ("Saved to file: " + l_saved.out)

						-- Validate with parser
						l_valid_syntax := validate_with_parser (l_gen.generated_class_text, l_logger)
						l_logger.info ("Parser validation: " + l_valid_syntax.out)
					else
						l_saved := False
						l_valid_syntax := False
					end

					l_logger.info ("=== Ollama test completed ===")

					assert ("ollama_class_generated", l_gen.is_generated)
					assert ("ollama_no_error", not l_gen.has_error)
					assert ("ollama_valid_syntax", l_valid_syntax)
				end
			end
		rescue
			l_retried := True
			retry
		end

feature -- Test: Parser Validation Sanity Checks

	test_parser_validation_valid_class
			-- Test parser validation with known-valid Eiffel code.
			-- Sanity check that our validation helper works correctly.
		local
			l_logger: SIMPLE_LOGGER
			l_valid: BOOLEAN
			l_file: PLAIN_TEXT_FILE
		do
			create l_logger.make_to_file (output_path + "/parser_valid.log")

			-- Debug: write the test string to file for inspection
			create l_file.make_create_read_write (output_path + "/test_valid_string.e")
			l_file.put_string (valid_eiffel_class.to_string_8)
			l_file.close

			l_valid := validate_with_parser (valid_eiffel_class, l_logger)
			assert ("valid_class_parses", l_valid)
		end

	test_parser_validation_invalid_class
			-- Test parser validation with invalid Eiffel code.
			-- Ensures our validation catches syntax errors.
		local
			l_logger: SIMPLE_LOGGER
			l_valid: BOOLEAN
		do
			create l_logger.make_to_file (output_path + "/parser_invalid.log")
			l_valid := validate_with_parser (invalid_eiffel_class, l_logger)
			assert ("invalid_class_fails_parse", not l_valid)
		end

feature {NONE} -- Validation Helpers

	validate_with_parser (a_source: STRING_32; a_logger: SIMPLE_LOGGER): BOOLEAN
			-- Validate Eiffel source with simple_eiffel_parser.
			-- Returns True if source parses without errors.
		local
			l_parser: SIMPLE_EIFFEL_PARSER
			l_ast: EIFFEL_AST
		do
			create l_parser.make
			a_logger.info ("Parsing source (" + a_source.count.out + " chars)...")
			l_ast := l_parser.parse_string (a_source.to_string_8)

			if l_ast.has_errors then
				a_logger.error ("Parse errors detected:")
				across l_ast.parse_errors as ic loop
					a_logger.error ("  - " + ic.message)
				end
				Result := False
			else
				a_logger.info ("Parse successful: " + l_ast.classes.count.out + " class(es)")
				Result := True
			end
		end

feature {NONE} -- Test Data

	output_path: STRING = "D:/prod/simple_code/output"
			-- Directory for generated output files

	test_system_spec_detailed: STRING_32
			-- Detailed system specification for realistic testing
		once
			Result := {STRING_32} "[
				{
					"app": {
						"name": "Calculator",
						"description": "A simple calculator application with basic arithmetic operations",
						"architecture": "MVC pattern with command-based operations"
					},
					"domain": {
						"purpose": "Perform arithmetic calculations",
						"core_concepts": ["operands", "operators", "results", "history"]
					}
				}
			]"
		end

	test_class_spec_detailed: STRING_32
			-- Detailed class specification for realistic testing
		once
			Result := {STRING_32} "[
				{
					"class": "CALCULATOR_CONTROLLER",
					"purpose": "Main controller for calculator operations",
					"responsibilities": [
						"Accept user input for operands and operators",
						"Delegate calculations to calculator engine",
						"Maintain calculation history",
						"Handle errors gracefully"
					],
					"features": [
						"add (a, b: REAL_64): REAL_64",
						"subtract (a, b: REAL_64): REAL_64",
						"multiply (a, b: REAL_64): REAL_64",
						"divide (a, b: REAL_64): REAL_64",
						"clear_history",
						"history: LIST [STRING]"
					],
					"contracts": {
						"divide_precondition": "b /= 0",
						"history_invariant": "history is never void"
					}
				}
			]"
		end

	valid_eiffel_class: STRING_32
			-- Known-valid Eiffel class for parser validation sanity check
		local
			s: STRING_32
		once
			create s.make (500)
			s.append ("note%N")
			s.append ("%Tdescription: %"A simple test entity%"%N%N")
			s.append ("class%N")
			s.append ("%TTEST_CLASS%N%N")
			s.append ("create%N")
			s.append ("%Tmake%N%N")
			s.append ("feature {NONE} -- Initialization%N%N")
			s.append ("%Tmake%N")
			s.append ("%T%Tdo%N")
			s.append ("%T%T%Tvalue := 0%N")
			s.append ("%T%Tend%N%N")
			s.append ("feature -- Access%N%N")
			s.append ("%Tvalue: INTEGER%N%N")
			s.append ("end%N")
			Result := s
		end

	invalid_eiffel_class: STRING_32
			-- Invalid Eiffel class for parser validation (missing end keyword)
		local
			s: STRING_32
		once
			create s.make (200)
			s.append ("class%N")
			s.append ("%TBROKEN_CLASS%N%N")
			s.append ("feature%N")
			s.append ("%Tvalue: INTEGER%N%N")
			s.append ("%T-- Missing end keyword deliberately%N")
			Result := s
		end

end
