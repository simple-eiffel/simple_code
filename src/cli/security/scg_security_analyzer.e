note
	description: "[
		Security analysis for code generation based on 2026 cybersecurity landscape.

		Incorporates key threat vectors from IBM Technology cybersecurity predictions:

		=== AGENTIC AI RISKS (Critical for 2026+) ===
		1. ATTACKS ON AGENTS:
		   - Risk amplifier: Bad actions at light speed
		   - Zero-click attacks via indirect prompt injection
		   - Non-human identity proliferation
		   - Privilege escalation vulnerabilities
		   - Excessive access grants

		2. ATTACKS BY AGENTS:
		   - Hyper-personalized phishing generation
		   - Polymorphic malware (changes signatures over time)
		   - Automated ransomware kill chains
		   - Full attack chain automation (recon → exploit → exfil)
		   - Enhanced social engineering via deepfakes

		=== OWASP LLM TOP 10 (Prompt Injection is #1) ===
		- Prompt injection remains #1 vulnerability (2023, 2025, ongoing)
		- Shadow AI: Unapproved AI implementations ($670K+ breach cost increase)
		- 60% of organizations lack AI governance policies

		=== QUANTUM THREAT ===
		- Q-Day approaching: Quantum computers will break current cryptography
		- Harvest-now-decrypt-later attacks already occurring
		- Post-quantum cryptography (PQC) must be implemented NOW

		=== KEY DEFENSE PRINCIPLES ===
		1. Never trust external input (all boundaries)
		2. Principle of least privilege (especially for automated systems)
		3. Defense in depth (multiple layers)
		4. Cryptographic agility (no hardcoded algorithms)
		5. Zero-trust architecture
		6. Input validation at EVERY boundary
		7. Rate limiting for automated systems
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SCG_SECURITY_ANALYZER

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize security analyzer.
		do
			create findings.make (10)
			create recommendations.make (10)
		end

feature -- Access

	findings: ARRAYED_LIST [SCG_SECURITY_FINDING]
			-- Security findings from analysis

	recommendations: ARRAYED_LIST [STRING]
			-- Security recommendations for code generation

	severity_score: REAL_64
			-- Overall severity (0.0 = safe, 1.0 = critical)

feature -- Analysis

	analyze_class_spec (a_spec: SCG_SESSION_CLASS_SPEC)
			-- Analyze class specification for security concerns.
		require
			spec_not_void: a_spec /= Void
		do
			findings.wipe_out
			recommendations.wipe_out
			severity_score := 0.0

			-- Check for agentic patterns (highest risk in 2026+)
			check_agentic_risks (a_spec)

			-- Check for prompt injection vulnerabilities
			check_prompt_injection_risks (a_spec)

			-- Check for identity/auth patterns
			check_identity_risks (a_spec)

			-- Check for cryptographic concerns
			check_crypto_risks (a_spec)

			-- Check for data handling
			check_data_exfil_risks (a_spec)

			-- Check for input validation
			check_input_validation_needs (a_spec)

			-- Calculate overall severity
			calculate_severity
		end

	as_prompt_enhancement: STRING
			-- Generate security guidance for prompt injection.
		do
			create Result.make (2000)

			if not findings.is_empty or not recommendations.is_empty then
				Result.append ("=== SECURITY ANALYSIS (2026 Threat Landscape) ===%N")
				Result.append ("Severity Score: ")
				Result.append (((severity_score * 100).truncated_to_integer).out)
				Result.append ("%%%N%N")

				-- Critical findings first
				if across findings as f some f.severity >= Severity_high end then
					Result.append ("!!! CRITICAL SECURITY CONCERNS !!!%N")
					across findings as f loop
						if f.severity >= Severity_high then
							Result.append ("  [")
							Result.append (severity_name (f.severity))
							Result.append ("] ")
							Result.append (f.category)
							Result.append (": ")
							Result.append (f.description)
							Result.append ("%N")
						end
					end
					Result.append ("%N")
				end

				-- Medium findings
				if across findings as f some f.severity = Severity_medium end then
					Result.append ("SECURITY CONSIDERATIONS:%N")
					across findings as f loop
						if f.severity = Severity_medium then
							Result.append ("  - ")
							Result.append (f.category)
							Result.append (": ")
							Result.append (f.description)
							Result.append ("%N")
						end
					end
					Result.append ("%N")
				end

				-- Recommendations
				if not recommendations.is_empty then
					Result.append ("SECURITY REQUIREMENTS FOR GENERATED CODE:%N")
					across recommendations as r loop
						Result.append ("  * ")
						Result.append (r)
						Result.append ("%N")
					end
					Result.append ("%N")
				end

				-- Standard security footer
				Result.append (security_standards_footer)
			end
		end

feature {NONE} -- Risk Analysis

	check_agentic_risks (a_spec: SCG_SESSION_CLASS_SPEC)
			-- Check for agentic AI risks (2026's biggest threat vector).
			-- Key insight: Agents are RISK AMPLIFIERS - bad actions at light speed.
		local
			l_name_lower, l_desc_lower: STRING
		do
			l_name_lower := a_spec.name.as_lower
			l_desc_lower := a_spec.description.as_lower

			-- Pattern: Agent/autonomous classes
			if l_name_lower.has_substring ("agent") or
			   l_desc_lower.has_substring ("autonomous") or
			   l_desc_lower.has_substring ("automated") then
				add_finding (Severity_critical, "AGENTIC_RISK",
					"Autonomous agent detected - RISK AMPLIFIER. Must implement: " +
					"rate limiting, action logging, human-in-loop for destructive ops, " +
					"strict input sanitization, privilege boundaries")
				recommendations.extend ("Implement rate limiting - agents operate at light speed")
				recommendations.extend ("Add human-in-the-loop confirmation for destructive actions")
				recommendations.extend ("Log ALL agent actions for audit trail")
				recommendations.extend ("Implement dead-man switch / circuit breaker pattern")
			end

			-- Pattern: Email/message processing (zero-click attack vector)
			if l_desc_lower.has_substring ("email") or
			   l_desc_lower.has_substring ("message") or
			   l_desc_lower.has_substring ("inbox") then
				add_finding (Severity_high, "ZERO_CLICK_VECTOR",
					"Email/message processing detected - vulnerable to INDIRECT PROMPT INJECTION. " +
					"Attacker embeds instructions in email body; agent reads and follows them")
				recommendations.extend ("NEVER execute instructions found in message content")
				recommendations.extend ("Treat ALL message content as UNTRUSTED DATA, not commands")
				recommendations.extend ("Implement content scanning before agent processing")
			end

			-- Pattern: Spawning/creating other processes
			if l_desc_lower.has_substring ("spawn") or
			   l_desc_lower.has_substring ("create process") or
			   l_desc_lower.has_substring ("subprocess") then
				add_finding (Severity_high, "IDENTITY_PROLIFERATION",
					"Process spawning detected - non-human identity proliferation risk. " +
					"Each spawned process needs identity management")
				recommendations.extend ("Track all spawned process identities")
				recommendations.extend ("Implement identity lifecycle management")
				recommendations.extend ("Set maximum spawn limits to prevent runaway creation")
			end
		end

	check_prompt_injection_risks (a_spec: SCG_SESSION_CLASS_SPEC)
			-- Check for prompt injection vulnerabilities.
			-- OWASP LLM Top 10 #1 in 2023 AND 2025 - still critical.
		local
			l_desc_lower: STRING
		do
			l_desc_lower := a_spec.description.as_lower

			-- Pattern: LLM/AI integration
			if l_desc_lower.has_substring ("llm") or
			   l_desc_lower.has_substring ("ai") or
			   l_desc_lower.has_substring ("prompt") or
			   l_desc_lower.has_substring ("chatbot") or
			   l_desc_lower.has_substring ("language model") then
				add_finding (Severity_critical, "PROMPT_INJECTION",
					"LLM integration detected - #1 OWASP LLM vulnerability. " +
					"Both direct and indirect prompt injection must be defended")
				recommendations.extend ("Sanitize ALL user input before including in prompts")
				recommendations.extend ("Use structured output formats (JSON) not free text")
				recommendations.extend ("Implement prompt injection detection")
				recommendations.extend ("Never include raw external content in system prompts")
				recommendations.extend ("Use separate contexts for trusted vs untrusted content")
			end

			-- Pattern: User input handling
			if l_desc_lower.has_substring ("user input") or
			   l_desc_lower.has_substring ("form") or
			   l_desc_lower.has_substring ("query") then
				add_finding (Severity_medium, "INPUT_BOUNDARY",
					"User input boundary detected - validate and sanitize ALL external input")
				recommendations.extend ("Implement input validation contracts (preconditions)")
				recommendations.extend ("Use allowlist validation where possible")
				recommendations.extend ("Escape/encode output appropriate to context")
			end
		end

	check_identity_risks (a_spec: SCG_SESSION_CLASS_SPEC)
			-- Check for identity and authentication risks.
			-- Key insight: Passkeys > Passwords, non-human identities exploding.
		local
			l_desc_lower: STRING
		do
			l_desc_lower := a_spec.description.as_lower

			-- Pattern: Authentication
			if l_desc_lower.has_substring ("auth") or
			   l_desc_lower.has_substring ("login") or
			   l_desc_lower.has_substring ("credential") or
			   l_desc_lower.has_substring ("password") then
				add_finding (Severity_high, "AUTHENTICATION",
					"Authentication detected - use modern standards (passkeys, FIDO2)")
				recommendations.extend ("Prefer passkeys/FIDO2 over passwords")
				recommendations.extend ("Implement MFA for sensitive operations")
				recommendations.extend ("Never store plaintext credentials")
				recommendations.extend ("Use secure credential storage (OS keychain)")
			end

			-- Pattern: Service accounts / API keys
			if l_desc_lower.has_substring ("api key") or
			   l_desc_lower.has_substring ("token") or
			   l_desc_lower.has_substring ("service account") then
				add_finding (Severity_high, "NON_HUMAN_IDENTITY",
					"Non-human identity detected - requires lifecycle management")
				recommendations.extend ("Rotate API keys/tokens regularly")
				recommendations.extend ("Use short-lived tokens where possible")
				recommendations.extend ("Implement least privilege for service accounts")
				recommendations.extend ("Track and audit non-human identity usage")
			end

			-- Pattern: Privilege/access
			if l_desc_lower.has_substring ("admin") or
			   l_desc_lower.has_substring ("privilege") or
			   l_desc_lower.has_substring ("permission") then
				add_finding (Severity_medium, "PRIVILEGE_ESCALATION",
					"Privilege management detected - prevent escalation attacks")
				recommendations.extend ("Implement principle of least privilege")
				recommendations.extend ("Validate privilege at every operation, not just entry")
				recommendations.extend ("Log all privilege changes and usage")
			end
		end

	check_crypto_risks (a_spec: SCG_SESSION_CLASS_SPEC)
			-- Check for cryptographic risks.
			-- Key insight: Q-Day is coming - prepare for post-quantum NOW.
		local
			l_desc_lower: STRING
		do
			l_desc_lower := a_spec.description.as_lower

			-- Pattern: Encryption/cryptography
			if l_desc_lower.has_substring ("encrypt") or
			   l_desc_lower.has_substring ("crypto") or
			   l_desc_lower.has_substring ("hash") or
			   l_desc_lower.has_substring ("cipher") then
				add_finding (Severity_medium, "CRYPTO_AGILITY",
					"Cryptography detected - prepare for post-quantum (Q-Day coming)")
				recommendations.extend ("Do NOT hardcode cryptographic algorithms")
				recommendations.extend ("Use cryptographic agility pattern (configurable algorithms)")
				recommendations.extend ("Consider post-quantum safe algorithms (ML-KEM, ML-DSA)")
				recommendations.extend ("Avoid RSA/ECC for long-term secrets (quantum vulnerable)")
			end

			-- Pattern: Sensitive data storage
			if l_desc_lower.has_substring ("secret") or
			   l_desc_lower.has_substring ("private key") or
			   l_desc_lower.has_substring ("sensitive") then
				add_finding (Severity_high, "HARVEST_NOW_DECRYPT_LATER",
					"Sensitive data detected - may be harvested now for quantum decryption later")
				recommendations.extend ("Encrypt sensitive data with quantum-safe algorithms")
				recommendations.extend ("Minimize sensitive data retention")
				recommendations.extend ("Implement data classification and handling policies")
			end
		end

	check_data_exfil_risks (a_spec: SCG_SESSION_CLASS_SPEC)
			-- Check for data exfiltration risks.
			-- Key insight: Agents can exfiltrate at scale.
		local
			l_desc_lower: STRING
		do
			l_desc_lower := a_spec.description.as_lower

			-- Pattern: Data export/send
			if l_desc_lower.has_substring ("export") or
			   l_desc_lower.has_substring ("send") or
			   l_desc_lower.has_substring ("upload") or
			   l_desc_lower.has_substring ("transfer") then
				add_finding (Severity_medium, "DATA_EXFILTRATION",
					"Data export capability detected - potential exfiltration vector")
				recommendations.extend ("Log all data exports with user/source attribution")
				recommendations.extend ("Implement data loss prevention (DLP) checks")
				recommendations.extend ("Rate limit bulk data operations")
				recommendations.extend ("Require confirmation for large data transfers")
			end

			-- Pattern: External API calls
			if l_desc_lower.has_substring ("api") or
			   l_desc_lower.has_substring ("http") or
			   l_desc_lower.has_substring ("request") or
			   l_desc_lower.has_substring ("webhook") then
				add_finding (Severity_medium, "EXTERNAL_COMMUNICATION",
					"External communication detected - potential data leak channel")
				recommendations.extend ("Allowlist permitted external endpoints")
				recommendations.extend ("Log all external API calls")
				recommendations.extend ("Validate and sanitize all outbound data")
			end
		end

	check_input_validation_needs (a_spec: SCG_SESSION_CLASS_SPEC)
			-- Check for input validation requirements.
		local
			l_desc_lower: STRING
		do
			l_desc_lower := a_spec.description.as_lower

			-- Pattern: File operations
			if l_desc_lower.has_substring ("file") or
			   l_desc_lower.has_substring ("path") or
			   l_desc_lower.has_substring ("directory") then
				recommendations.extend ("Validate file paths - prevent path traversal (../)")
				recommendations.extend ("Use allowlist for permitted directories")
				recommendations.extend ("Check file types and sizes before processing")
			end

			-- Pattern: Database operations
			if l_desc_lower.has_substring ("database") or
			   l_desc_lower.has_substring ("sql") or
			   l_desc_lower.has_substring ("query") then
				recommendations.extend ("Use parameterized queries - prevent SQL injection")
				recommendations.extend ("Implement query result size limits")
				recommendations.extend ("Validate and sanitize all query inputs")
			end

			-- Pattern: Command execution
			if l_desc_lower.has_substring ("execute") or
			   l_desc_lower.has_substring ("command") or
			   l_desc_lower.has_substring ("shell") or
			   l_desc_lower.has_substring ("process") then
				add_finding (Severity_high, "COMMAND_INJECTION",
					"Command execution detected - high risk for injection attacks")
				recommendations.extend ("NEVER construct commands from user input")
				recommendations.extend ("Use allowlist of permitted commands")
				recommendations.extend ("Sandbox command execution where possible")
				recommendations.extend ("Validate ALL command arguments strictly")
			end
		end

feature {NONE} -- Helpers

	add_finding (a_severity: INTEGER; a_category, a_description: STRING)
			-- Add a security finding.
		local
			l_finding: SCG_SECURITY_FINDING
		do
			create l_finding.make (a_severity, a_category, a_description)
			findings.extend (l_finding)
		end

	calculate_severity
			-- Calculate overall severity score from findings.
		local
			l_max: REAL_64
		do
			l_max := 0.0
			across findings as f loop
				l_max := l_max.max (f.severity.to_real / Severity_critical.to_real)
			end
			severity_score := l_max
		end

	severity_name (a_severity: INTEGER): STRING
			-- Human-readable severity name.
		do
			inspect a_severity
			when Severity_critical then Result := "CRITICAL"
			when Severity_high then Result := "HIGH"
			when Severity_medium then Result := "MEDIUM"
			when Severity_low then Result := "LOW"
			else Result := "INFO"
			end
		end

	security_standards_footer: STRING
			-- Standard security guidance footer.
		do
			Result := "[
=== MANDATORY SECURITY PRACTICES ===
1. INPUT VALIDATION: Validate ALL external input at boundaries
2. OUTPUT ENCODING: Encode output appropriate to context (HTML, SQL, shell)
3. LEAST PRIVILEGE: Request minimum necessary permissions
4. DEFENSE IN DEPTH: Multiple security layers, not single points
5. FAIL SECURE: On error, deny access, don't fail open
6. AUDIT LOGGING: Log security-relevant events for forensics
7. SECURE DEFAULTS: Security ON by default, opt-out not opt-in

=== EIFFEL SECURITY PATTERNS ===
- Use PRECONDITIONS to validate input (require clauses)
- Use POSTCONDITIONS to verify security state (ensure clauses)
- Use INVARIANTS to maintain security properties
- Prefer immutable data structures where possible
- Use typed data instead of raw strings for security tokens
]"
		end

feature -- Severity Constants

	Severity_info: INTEGER = 0
	Severity_low: INTEGER = 1
	Severity_medium: INTEGER = 2
	Severity_high: INTEGER = 3
	Severity_critical: INTEGER = 4

invariant
	findings_exists: findings /= Void
	recommendations_exists: recommendations /= Void
	severity_valid: severity_score >= 0.0 and severity_score <= 1.0

end
