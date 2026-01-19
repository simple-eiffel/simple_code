note
	description: "[
		Main facade for code reuse discovery in simple_codegen.

		Discovers reuse opportunities by:
		1. Analyzing ECF to find available libraries
		2. Searching KB for similar classes/features
		3. Matching specifications against existing code
		4. Recommending reuse strategies (use, inherit, compose, write fresh)

		Usage:
			create discoverer.make (kb, ecf_path)
			result := discoverer.discover_for_class (class_spec)
			-- result.prompt_enhancement contains text to inject into prompt
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_REUSE_DISCOVERER

create
	make,
	make_with_kb

feature {NONE} -- Initialization

	make (a_ecf_path: STRING)
			-- Create discoverer for project at `a_ecf_path'.
		require
			ecf_path_not_empty: not a_ecf_path.is_empty
		do
			ecf_path := a_ecf_path
			create matcher.make
			create ecf_analyzer.make
			ecf_analyzer.analyze_file (a_ecf_path)
			create last_error.make_empty
			create api_cache.make (20)
		ensure
			ecf_path_set: ecf_path = a_ecf_path
		end

	make_with_kb (a_kb: SCG_KB; a_ecf_path: STRING)
			-- Create discoverer with knowledge base and ECF path.
		require
			kb_not_void: a_kb /= Void
			kb_open: a_kb.is_open
			ecf_path_not_empty: not a_ecf_path.is_empty
		do
			kb := a_kb
			ecf_path := a_ecf_path
			create matcher.make
			create ecf_analyzer.make
			ecf_analyzer.analyze_file (a_ecf_path)
			create last_error.make_empty
			create api_cache.make (20)
		ensure
			kb_set: kb = a_kb
			ecf_path_set: ecf_path = a_ecf_path
		end

feature -- Access

	kb: detachable SCG_KB
			-- Knowledge base for searching (optional)

	ecf_path: STRING
			-- Path to project ECF file

	last_error: STRING
			-- Error from last operation

	is_enabled: BOOLEAN
			-- Is reuse discovery enabled?
		do
			Result := attached kb
		end

feature -- Cleanup

	close
			-- Release resources (KB reference).
			-- Call this before letting the discoverer go out of scope.
		do
			kb := Void
		ensure
			kb_detached: kb = Void
		end

feature -- Discovery

	discover_for_class (a_spec: SCG_SESSION_CLASS_SPEC): SCG_REUSE_RESULT
			-- Discover reuse opportunities for class specification.
		require
			spec_not_void: a_spec /= Void
		local
			l_candidates: ARRAYED_LIST [SCG_REUSE_CANDIDATE]
			l_best_score: REAL_64
		do
			create Result.make (a_spec.name.to_string_8)

			-- Phase 1: Search for similar classes in KB (external libs)
			if attached kb as l_kb then
				l_candidates := search_similar_classes (l_kb, a_spec)
				across l_candidates as ic_c loop
					Result.add_candidate (ic_c)
				end
			end

			-- Phase 2: Search for matching features (external libs)
			if attached kb as l_kb then
				across a_spec.features as ic_feat loop
					search_matching_features (l_kb, ic_feat, Result)
				end
			end

			-- Phase 3: Search for internal matches (same project)
			if attached session_specs as l_specs then
				search_internal_matches (a_spec, l_specs, Result)
			end

			-- Phase 4: Analyze is-a (inherit) and has-a (compose) opportunities
			analyze_inheritance_opportunities (a_spec, Result)
			analyze_composition_opportunities (a_spec, Result)

			-- Phase 5: Analyze semantic alignment (ancestor opportunities)
			if attached session_specs as l_specs then
				analyze_semantic_alignment (a_spec, l_specs, Result)
			end

			-- Phase 6: Build API summary from ECF dependencies
			Result.set_api_summary (build_api_summary (a_spec))

			-- Phase 7: Determine recommendation
			if Result.has_candidates then
				l_best_score := Result.candidates.first.match_score
				Result.set_recommendation (
					matcher.recommend_strategy (l_best_score, True,
						across Result.candidates as c some c.is_feature_level end))
				Result.set_confidence (l_best_score)

				-- Build "do not reinvent" list
				build_do_not_reinvent (Result)
			else
				-- No candidates - recommend fresh
				Result.set_confidence (0.0)
			end

			-- Phase 8: Build prompt enhancement
			Result.build_prompt_enhancement
		ensure
			result_not_void: Result /= Void
		end

	discover_for_system (a_specs: ARRAYED_LIST [SCG_SESSION_CLASS_SPEC]): SCG_REUSE_RESULT
			-- Discover reuse opportunities for entire system (all specs).
			-- This is called at the SYSTEM scale point before any class generation.
		require
			specs_not_empty: not a_specs.is_empty
		local
			l_class_result: SCG_REUSE_RESULT
		do
			create Result.make ("SYSTEM")
			session_specs := a_specs

			-- Analyze each class spec
			across a_specs as ic_spec loop
				l_class_result := discover_for_class (ic_spec)

				-- Merge candidates and recommendations
				across l_class_result.candidates as ic_c loop
					Result.add_candidate (ic_c)
				end
				across l_class_result.internal_candidates as ic_cand loop
					Result.add_internal_candidate (ic_cand)
				end
				across l_class_result.inherit_candidates as ic_inh loop
					-- Parse and re-add inherit candidates
					Result.inherit_candidates.extend (ic_inh)
				end
				across l_class_result.compose_candidates as ic_comp loop
					Result.compose_candidates.extend (ic_comp)
				end
				across l_class_result.do_not_reinvent as ic_dnr loop
					Result.add_do_not_reinvent (ic_dnr)
				end
				across l_class_result.suggested_imports as ic_si loop
					Result.add_suggested_import (ic_si)
				end
			end

			-- Cross-class semantic analysis (looking for common ancestors)
			analyze_cross_class_semantics (a_specs, Result)

			-- Build final enhancement
			Result.build_prompt_enhancement
		ensure
			result_not_void: Result /= Void
		end

	set_session_specs (a_specs: ARRAYED_LIST [SCG_SESSION_CLASS_SPEC])
			-- Set the session specs for internal matching.
		do
			session_specs := a_specs
		ensure
			session_specs_set: session_specs = a_specs
		end

	discover_for_feature (a_class_name, a_feature_name: STRING): SCG_REUSE_RESULT
			-- Discover reuse opportunities for a single feature.
		require
			class_not_empty: not a_class_name.is_empty
			feature_not_empty: not a_feature_name.is_empty
		local
			l_feature_spec: STRING_32
		do
			create Result.make (a_class_name + "." + a_feature_name)

			if attached kb as l_kb then
				l_feature_spec := a_feature_name.to_string_32
				search_matching_features (l_kb, l_feature_spec, Result)
			end

			-- Determine recommendation
			if Result.has_candidates then
				Result.set_recommendation (
					matcher.recommend_strategy (Result.candidates.first.match_score, False, True))
				Result.set_confidence (Result.candidates.first.match_score)
			end

			Result.build_prompt_enhancement
		ensure
			result_not_void: Result /= Void
		end

feature -- API Extraction

	extract_library_apis (a_libraries: ARRAYED_LIST [STRING]): STRING
			-- Extract API summaries from specified libraries.
		require
			libraries_not_void: a_libraries /= Void
		do
			create Result.make (2000)
			across a_libraries as lib loop
				Result.append (extract_single_library_api (lib))
			end
		end

	extract_single_library_api (a_library_name: STRING): STRING
			-- Extract API summary for a single library.
		require
			name_not_empty: not a_library_name.is_empty
		local
			l_cached: detachable STRING
		do
			-- Check cache first
			l_cached := api_cache.item (a_library_name)
			if attached l_cached then
				Result := l_cached
			else
				Result := build_library_api_summary (a_library_name)
				api_cache.force (Result, a_library_name)
			end
		end

	get_relevant_contracts (a_class_name: STRING): STRING
			-- Get contracts from similar classes for reference.
		require
			class_not_empty: not a_class_name.is_empty
		do
			create Result.make (500)

			if attached kb as l_kb then
				if attached l_kb.find_class (a_class_name) as l_class then
					across l_kb.get_class_features (l_class.id) as feat loop
						if not feat.preconditions.is_empty or not feat.postconditions.is_empty then
							Result.append (feat.name)
							Result.append (":%N")
							if not feat.preconditions.is_empty then
								Result.append ("  require: ")
								Result.append (feat.preconditions)
								Result.append ("%N")
							end
							if not feat.postconditions.is_empty then
								Result.append ("  ensure: ")
								Result.append (feat.postconditions)
								Result.append ("%N")
							end
						end
					end
				end
			end
		end

feature {NONE} -- Search Implementation

	search_similar_classes (a_kb: SCG_KB; a_spec: SCG_SESSION_CLASS_SPEC): ARRAYED_LIST [SCG_REUSE_CANDIDATE]
			-- Search KB for classes similar to specification.
		require
			kb_open: a_kb.is_open
		local
			l_candidate: SCG_REUSE_CANDIDATE
			l_score: REAL_64
			l_search_results: ARRAYED_LIST [TUPLE [content_type: STRING; title: STRING; body: STRING]]
		do
			create Result.make (10)

			-- Direct class name search
			if attached a_kb.find_class (a_spec.name) as l_class then
				l_score := 1.0 -- Exact match
				create l_candidate.make_for_class (l_class.library, l_class.name, l_class.description, l_score)
				l_candidate.set_strategy (create {SCG_REUSE_STRATEGY}.make_use_existing)
				Result.extend (l_candidate)
			end

			-- FTS search for related classes
			l_search_results := a_kb.search (a_spec.name, 5)
			across l_search_results as sr loop
				if sr.content_type.is_equal ("class") then
					-- Extract library from body if possible
					l_score := matcher.match_class_name (a_spec.name, sr.title)
					if l_score >= 0.4 then -- Threshold for inclusion
						create l_candidate.make_for_class ("unknown", sr.title, sr.body, l_score)
						Result.extend (l_candidate)
					end
				end
			end

			-- Also search by description keywords
			if not a_spec.description.is_empty then
				l_search_results := a_kb.search (a_spec.description.to_string_8.substring (1, a_spec.description.count.min (50)), 5)
				across l_search_results as sr loop
					if sr.content_type.is_equal ("class") then
						l_score := matcher.match_description (a_spec.description.to_string_8, sr.body)
						if l_score >= 0.3 then
							-- Check if we already have this class
							if not across Result as r some r.class_name.is_equal (sr.title) end then
								create l_candidate.make_for_class ("unknown", sr.title, sr.body, l_score)
								Result.extend (l_candidate)
							end
						end
					end
				end
			end
		end

	search_matching_features (a_kb: SCG_KB; a_feature_spec: STRING_32; a_result: SCG_REUSE_RESULT)
			-- Search KB for features matching specification, add to result.
		require
			kb_open: a_kb.is_open
		local
			l_matches: ARRAYED_LIST [TUPLE [class_name: STRING; feature_name: STRING; kind: STRING; signature: STRING]]
			l_candidate: SCG_REUSE_CANDIDATE
			l_score: REAL_64
		do
			-- Search for features by name
			l_matches := a_kb.search_features_by_name (a_feature_spec.to_string_8, 10)
			across l_matches as ic_m loop
				l_score := matcher.match_feature_name (a_feature_spec.to_string_8, ic_m.feature_name)
				if l_score >= 0.5 then -- Feature match threshold
					create l_candidate.make_for_feature (
						"base", -- Default library
						ic_m.class_name,
						ic_m.feature_name,
						ic_m.signature,
						l_score
					)

					-- Add to result if not duplicate
					if not across a_result.candidates as c some
						c.class_name.is_equal (ic_m.class_name) and
						c.feature_name.is_equal (ic_m.feature_name)
					end then
						a_result.add_candidate (l_candidate)

						-- Add to "do not reinvent" if strong match
						if l_score >= 0.8 then
							a_result.add_do_not_reinvent (
								ic_m.feature_name + " - use " + ic_m.class_name + "." + ic_m.feature_name + "()"
							)
						end
					end
				end
			end
		end

feature {NONE} -- API Building

	build_api_summary (a_spec: SCG_SESSION_CLASS_SPEC): STRING
			-- Build API summary from ECF dependencies relevant to spec.
		do
			create Result.make (1000)

			-- Include APIs from simple_* libraries in ECF
			across ecf_analyzer.simple_libraries as ic_lib loop
				Result.append (extract_single_library_api (ic_lib))
			end
		end

	build_library_api_summary (a_library_name: STRING): STRING
			-- Build API summary for a library from KB.
		local
			l_facade_name: STRING
		do
			create Result.make (500)

			if attached kb as l_kb then
				-- Try to find the facade class (SIMPLE_<NAME>)
				l_facade_name := facade_class_name (a_library_name)

				if attached l_kb.find_class (l_facade_name) as l_class then
					Result.append ("Library: ")
					Result.append (a_library_name)
					Result.append ("%N")
					Result.append ("  class ")
					Result.append (l_class.name)
					Result.append ("%N")

					-- Add key features
					across l_kb.get_class_features (l_class.id) as ic_feat loop
						-- Only show public features
						if ic_feat.kind.is_equal ("command") or ic_feat.kind.is_equal ("query") then
							Result.append ("    ")
							Result.append (ic_feat.name)
							if not ic_feat.signature.is_empty then
								Result.append (": ")
								Result.append (ic_feat.signature)
							end
							Result.append ("%N")
							if not ic_feat.preconditions.is_empty then
								Result.append ("      require: ")
								Result.append (ic_feat.preconditions)
								Result.append ("%N")
							end
						end
					end
					Result.append ("%N")
				end
			end
		end

	facade_class_name (a_library_name: STRING): STRING
			-- Convert library name to expected facade class name.
			-- e.g., "simple_csv" -> "SIMPLE_CSV"
		do
			Result := a_library_name.as_upper
		end

	build_do_not_reinvent (a_result: SCG_REUSE_RESULT)
			-- Build "do not reinvent" list from candidates.
		do
			across a_result.candidates as ic_c loop
				if ic_c.is_strong_match then
					if ic_c.is_feature_level then
						a_result.add_do_not_reinvent (
							ic_c.feature_name + " - use " + ic_c.class_name + "." + ic_c.feature_name
						)
					else
						a_result.add_do_not_reinvent (
							ic_c.class_name + " - available in " + ic_c.library_name
						)
					end

					-- Add library to suggested imports
					a_result.add_suggested_import (ic_c.library_name)
				end
			end
		end

feature {NONE} -- Is-a/Has-a Analysis

	analyze_inheritance_opportunities (a_spec: SCG_SESSION_CLASS_SPEC; a_result: SCG_REUSE_RESULT)
			-- Analyze potential inheritance relationships (is-a).
			-- Look for abstract base classes that match the specification's purpose.
		local
			l_name_lower: STRING
			l_desc_lower: STRING
		do
			l_name_lower := a_spec.name.as_lower
			l_desc_lower := a_spec.description.as_lower

			-- Pattern: *_RENDERER classes should inherit from CHART_RENDERER or similar
			if l_name_lower.has_substring ("renderer") then
				if attached kb as l_kb then
					if attached l_kb.find_class ("CHART_RENDERER") as l_class then
						a_result.add_inherit_candidate ("CHART_RENDERER", l_class.library,
							"Abstract base for renderers, provides output buffer and common features")
					end
				end
			end

			-- Pattern: *_LOADER classes might inherit from base loader or use composition
			if l_name_lower.has_substring ("loader") or l_name_lower.has_substring ("parser") then
				-- Recommend composition over inheritance for data loaders
				-- (this is handled in analyze_composition_opportunities)
			end

			-- Pattern: CLI apps inherit from ARGUMENTS_32 (but don't rename make!)
			if l_desc_lower.has_substring ("cli") or l_desc_lower.has_substring ("command line") then
				a_result.add_inherit_candidate ("ARGUMENTS_32", "base",
					"Provides argument parsing (DO NOT rename make feature)")
			end

			-- Pattern: Test classes inherit from EQA_TEST_SET
			if l_name_lower.starts_with ("test_") then
				a_result.add_inherit_candidate ("EQA_TEST_SET", "testing",
					"EiffelStudio test framework base class")
			end
		end

	analyze_composition_opportunities (a_spec: SCG_SESSION_CLASS_SPEC; a_result: SCG_REUSE_RESULT)
			-- Analyze potential composition relationships (has-a).
			-- Look for classes that should be used as components/attributes.
		local
			l_name_lower: STRING
			l_desc_lower: STRING
		do
			l_name_lower := a_spec.name.as_lower
			l_desc_lower := a_spec.description.as_lower

			-- Pattern: *_DATA_LOADER classes use SIMPLE_CSV or SIMPLE_JSON
			if l_name_lower.has_substring ("csv") or l_desc_lower.has_substring ("csv") then
				a_result.add_compose_candidate ("SIMPLE_CSV", "simple_csv",
					"CSV parsing - use parse(), row_at(), row_count")
				a_result.add_suggested_import ("simple_csv")
			end

			if l_name_lower.has_substring ("json") or l_desc_lower.has_substring ("json") then
				a_result.add_compose_candidate ("SIMPLE_JSON", "simple_json",
					"JSON parsing - use parse(), item(), as_array()")
				a_result.add_suggested_import ("simple_json")
			end

			-- Pattern: File operations use SIMPLE_FILE
			if l_desc_lower.has_substring ("file") or l_desc_lower.has_substring ("load") then
				a_result.add_compose_candidate ("SIMPLE_FILE", "simple_file",
					"File I/O - use make(path), exists, read_all, read_text")
				a_result.add_suggested_import ("simple_file")
			end

			-- Pattern: Terminal/console output uses SIMPLE_CONSOLE
			if l_desc_lower.has_substring ("terminal") or l_desc_lower.has_substring ("console") or
			   l_desc_lower.has_substring ("cli") then
				a_result.add_compose_candidate ("SIMPLE_CONSOLE", "simple_console",
					"Terminal I/O - use print_line(), print_error(), width")
				a_result.add_suggested_import ("simple_console")
			end

			-- Pattern: XML parsing uses SIMPLE_XML
			if l_name_lower.has_substring ("xml") or l_desc_lower.has_substring ("xml") then
				a_result.add_compose_candidate ("SIMPLE_XML", "simple_xml",
					"XML parsing - SAX-style event parser")
				a_result.add_suggested_import ("simple_xml")
			end

			-- Pattern: Path manipulation uses SIMPLE_PATH
			if l_desc_lower.has_substring ("path") or l_desc_lower.has_substring ("directory") then
				a_result.add_compose_candidate ("SIMPLE_PATH", "simple_path",
					"Path manipulation - join, parent, filename, extension")
				a_result.add_suggested_import ("simple_path")
			end

			-- Pattern: UUID generation uses SIMPLE_UUID
			if l_desc_lower.has_substring ("uuid") or l_desc_lower.has_substring ("unique id") then
				a_result.add_compose_candidate ("SIMPLE_UUID", "simple_uuid",
					"UUID generation - use generate, to_string")
				a_result.add_suggested_import ("simple_uuid")
			end

			-- Pattern: Process/command execution uses SIMPLE_PROCESS
			if l_desc_lower.has_substring ("process") or l_desc_lower.has_substring ("execute") or
			   l_desc_lower.has_substring ("command") then
				a_result.add_compose_candidate ("SIMPLE_PROCESS", "simple_process",
					"Process execution - run(), output, exit_code")
				a_result.add_suggested_import ("simple_process")
			end

			-- Pattern: Database uses SIMPLE_SQL
			if l_desc_lower.has_substring ("database") or l_desc_lower.has_substring ("sqlite") or
			   l_desc_lower.has_substring ("sql") then
				a_result.add_compose_candidate ("SIMPLE_SQL", "simple_sql",
					"SQLite database - execute(), query(), row_at()")
				a_result.add_suggested_import ("simple_sql")
			end
		end

feature {NONE} -- Internal Discovery

	search_internal_matches (a_spec: SCG_SESSION_CLASS_SPEC; a_all_specs: ARRAYED_LIST [SCG_SESSION_CLASS_SPEC]; a_result: SCG_REUSE_RESULT)
			-- Search for reuse opportunities within the same project.
			-- Finds classes with similar features that could be reused.
		local
			l_candidate: SCG_REUSE_CANDIDATE
			l_score: REAL_64
			l_shared_features: ARRAYED_LIST [STRING]
		do
			across a_all_specs as other_spec loop
				-- Don't compare with self
				if not other_spec.name.is_equal (a_spec.name) then
					-- Check for feature overlap
					create l_shared_features.make (5)
					across a_spec.features as feat loop
						if across other_spec.features as other_feat some
							feature_names_similar (feat.to_string_32.to_string_8, other_feat.to_string_32.to_string_8)
						end then
							l_shared_features.extend (feat.to_string_32.to_string_8)
						end
					end

					-- If significant overlap, add as internal candidate
					if l_shared_features.count >= 2 then
						l_score := l_shared_features.count.to_real / a_spec.features.count.max (1).to_real
						create l_candidate.make_for_class ("(internal)", other_spec.name.to_string_8, other_spec.description.to_string_8, l_score)
						a_result.add_internal_candidate (l_candidate)
					end
				end
			end
		end

	analyze_semantic_alignment (a_spec: SCG_SESSION_CLASS_SPEC; a_all_specs: ARRAYED_LIST [SCG_SESSION_CLASS_SPEC]; a_result: SCG_REUSE_RESULT)
			-- Detect semantic alignment with other specs in the same project.
			-- If two classes share significant feature patterns, suggest common ancestor.
		local
			l_shared_features: ARRAYED_LIST [STRING]
		do
			across a_all_specs as other_spec loop
				if not other_spec.name.is_equal (a_spec.name) then
					-- Find shared feature names
					create l_shared_features.make (5)
					across a_spec.features as feat loop
						across other_spec.features as other_feat loop
							if feature_names_similar (feat.to_string_32.to_string_8, other_feat.to_string_32.to_string_8) then
								l_shared_features.extend (feat.to_string_32.to_string_8)
							end
						end
					end

					-- Threshold: 3+ shared features suggests semantic alignment
					if l_shared_features.count >= 3 then
						a_result.add_semantic_alignment (a_spec.name.to_string_8, other_spec.name.to_string_8, l_shared_features)
					end
				end
			end
		end

	analyze_cross_class_semantics (a_specs: ARRAYED_LIST [SCG_SESSION_CLASS_SPEC]; a_result: SCG_REUSE_RESULT)
			-- Analyze all classes for common patterns that suggest deferred ancestors.
			-- This is a system-wide analysis for factoring opportunities.
		local
			l_renderer_classes: ARRAYED_LIST [STRING]
			l_data_loader_classes: ARRAYED_LIST [STRING]
			l_shared_by: ARRAYED_LIST [STRING]
		do
			create l_renderer_classes.make (5)
			create l_data_loader_classes.make (5)

			-- Group classes by pattern
			across a_specs as spec loop
				if spec.name.to_string_8.as_lower.has_substring ("renderer") then
					l_renderer_classes.extend (spec.name.to_string_8)
				end
				if spec.name.to_string_8.as_lower.has_substring ("loader") or
				   spec.name.to_string_8.as_lower.has_substring ("parser") then
					l_data_loader_classes.extend (spec.name.to_string_8)
				end
			end

			-- Suggest deferred ancestors for groups of 2+
			if l_renderer_classes.count >= 2 then
				create l_shared_by.make_from_array (l_renderer_classes.to_array)
				a_result.add_suggested_ancestor (
					"ABSTRACT_RENDERER",
					l_shared_by,
					"shared render pattern with output buffer and format handling"
				)
			end

			if l_data_loader_classes.count >= 2 then
				create l_shared_by.make_from_array (l_data_loader_classes.to_array)
				a_result.add_suggested_ancestor (
					"ABSTRACT_DATA_LOADER",
					l_shared_by,
					"shared loading pattern with source, parse, and validation"
				)
			end
		end

	feature_names_similar (a_name1, a_name2: STRING): BOOLEAN
			-- Are these feature names semantically similar?
			-- Checks for exact match, prefix match, or common word match.
		local
			l_n1, l_n2: STRING
		do
			l_n1 := a_name1.as_lower
			l_n2 := a_name2.as_lower

			-- Exact match
			if l_n1.is_equal (l_n2) then
				Result := True
			-- Prefix match (e.g., "render" matches "render_chart")
			elseif l_n1.starts_with (l_n2) or l_n2.starts_with (l_n1) then
				Result := True
			-- Contains match for short common names
			elseif l_n1.count >= 4 and l_n2.count >= 4 then
				if l_n1.has_substring (l_n2) or l_n2.has_substring (l_n1) then
					Result := True
				end
			end
		end

feature {NONE} -- Implementation

	matcher: SCG_SPEC_MATCHER
			-- Specification matcher

	ecf_analyzer: SCG_ECF_ANALYZER
			-- ECF dependency analyzer

	api_cache: HASH_TABLE [STRING, STRING]
			-- Cache of library API summaries

	session_specs: detachable ARRAYED_LIST [SCG_SESSION_CLASS_SPEC]
			-- Class specs from current session (for internal matching)

invariant
	matcher_exists: matcher /= Void
	ecf_analyzer_exists: ecf_analyzer /= Void

end
