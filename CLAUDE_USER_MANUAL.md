# Simple_Codegen Claude User Manual

**Version:** 2.0.0
**Purpose:** Comprehensive guide for Claude on how to use and interact with simple_codegen CLI.

---

## IMPORTANT: READ THIS FIRST

Before proceeding with ANY task, you MUST:
1. Read and understand this manual completely
2. Run `simple_codegen rules` to see the current guardrails
3. Check KB statistics with `simple_codegen projects --stats`
4. Determine the SCALE and SCOPE of the task
5. Follow simple_codegen prompts - DO NOT act on your own

---

## 1. OVERVIEW

simple_codegen is a Claude-in-the-Loop code generation CLI that guides you through structured Eiffel development. It provides prompts, validates output, and ensures you follow proper development practices.

**Your Role:** Execute tasks within the constraints defined by simple_codegen prompts. Never go outside these constraints.

---

## 2. SCALE AND SCOPE

### 2.1 Determine SCALE First

When given a task, identify the SCALE:

| Scale | Description | Example |
|-------|-------------|---------|
| SYSTEM | New project/library | "Create a library management system" |
| SUBSYSTEM | Module within existing project | "Add authentication to the app" |
| CLUSTER | Group of related classes | "Add data validation classes" |
| CLASS | Single class | "Create a CONFIG_MANAGER class" |
| FEATURE | Single feature in existing class | "Add a save method to CONFIG" |

### 2.2 Determine SCOPE (Stages Needed)

Based on SCALE, apply the appropriate SCOPE:

| Scale | Stages to Complete |
|-------|-------------------|
| SYSTEM | ALL stages (1-6) |
| SUBSYSTEM | Stages 2-5 (skip skeleton) |
| CLUSTER | Stages 2-3, maybe 5 |
| CLASS | Stage 2, maybe 3 |
| FEATURE | Stage 2 only |

---

## 3. LIFECYCLE STAGES

### Stage 1: PROJECT SKELETON
**Goal:** Create directory structure and configuration
- Create directories: src/, testing/, docs/, bin/
- Create ECF with main AND test targets
- Create README.md, CHANGELOG.md, .gitignore

**Command:** `simple_codegen init --session <name>`

### Stage 2: CODE GENERATION
**Goal:** Generate main classes
- Apply Design by Contract (DBC) principles
- Ensure void safety
- Follow SCOOP patterns if needed

**Commands:**
- `simple_codegen generate --session <name>`
- `simple_codegen process --input <response.json> --session <name>`

### Stage 3: TEST CREATION
**Goal:** Create comprehensive tests
- Create test_app.e (test runner)
- Create lib_tests.e (test cases)
- Include happy path and edge case tests

**Command:** `simple_codegen generate-tests --session <name> --class <CLASS>`

### Stage 4: DOCUMENTATION
**Goal:** Create project documentation
- docs/index.html with overview, API, examples
- Update README.md if needed

**Command:** `simple_codegen docs --session <name>`

### Stage 5: BUILD AND DEPLOY
**Goal:** Compile and deploy
- Compile test target, run tests
- Compile release target
- Copy binary to bin/ folder

**Commands:**
- `simple_codegen compile --session <name> --project <path>`
- `simple_codegen compile --session <name> --project <path>`

### Stage 6: INSTALLER (Optional)
**Goal:** Create installer for distribution
- Create INNO Setup script
- Build and test installer

**Command:** `simple_codegen inno --session <name>`

---

## 4. MANDATORY RULES

### 4.1 Project Confinement
- ALL files MUST be created INSIDE the project directory
- NEVER create files in /d/prod/ directly
- EIFGENs MUST be in project_root/EIFGENs/
- Source files go in project_root/src/

### 4.2 Compilation Rules
**NEVER use ec.exe or ec.sh directly!**

Use these tools instead:
- `simple_codegen compile --session <name> --project <path>`
- `simple_codegen compile --session <name> --project <path>`

### 4.3 Follow Prompts
- DO NOT act on your own outside prompts
- If simple_codegen provides a prompt, FOLLOW IT
- If you need guidance, run `simple_codegen rules`

### 4.4 Cleanup Requirements
Before finishing work:
- Terminate any background processes
- Delete temporary files
- Release file locks
- Report what artifacts were created

---

## 5. WORKFLOW

### 5.1 Starting a Task

1. **Run rules first:**
   ```bash
   simple_codegen rules
   ```

2. **Determine SCALE and SCOPE** from user's request

3. **Initialize session if SYSTEM scale:**
   ```bash
   simple_codegen init --session <name>
   ```

4. **Or use plan command for clarity:**
   ```bash
   simple_codegen plan --session <name> --goal "description"
   ```

### 5.2 During Task Execution

1. **Follow each prompt** from simple_codegen
2. **Process your responses:**
   ```bash
   simple_codegen process --input response.json --session <name>
   ```
3. **Validate generated code:**
   ```bash
   simple_codegen validate --input <file.e>
   ```
4. **Refine if needed:**
   ```bash
   simple_codegen refine --session <name> --class <CLASS> --issues "issue1;issue2"
   ```

### 5.3 Completing a Task

1. **Verify checklist:**
   - [ ] ECF has main AND test targets
   - [ ] testing/ folder with tests
   - [ ] docs/ folder with index.html
   - [ ] README.md exists
   - [ ] bin/ folder with binary
   - [ ] All tests pass

2. **Report completion** with list of artifacts created

---

## 6. QUICK START: CREATING A NEW PROJECT

The fastest way to create a new Eiffel project is with the `new` command:

### Create a Library Project
```bash
simple_codegen new simple_mylib
```

### Create a CLI Application
```bash
simple_codegen new simple_myapp --type cli
```

### With Dependencies
```bash
simple_codegen new simple_mylib --lib simple_file --lib simple_json
```

### In a Specific Directory
```bash
simple_codegen new simple_mylib --dir /d/prod/libs
```

This creates a complete project scaffold with:
- ECF with main AND test targets
- Main class (library facade or CLI app)
- Test scaffold (test_app.e, lib_tests.e)
- README.md, CHANGELOG.md, .gitignore
- docs/index.html

The project is automatically registered in the KB tracking database.

---

## 7. KNOWLEDGE BASE (KB) INTEGRATION

simple_codegen includes a local copy of the Eiffel knowledge base containing:
- **4600+ classes** from ISE and simple_* libraries
- **87000+ features** with signatures and contracts
- **270+ examples** from Rosetta Code
- **28 patterns** for common Eiffel idioms
- **180+ libraries** with metadata

### Check KB Statistics
```bash
simple_codegen projects --stats
```

### Use KB for Context
The KB is used to:
- Shape prompts with relevant class/feature information
- Provide pattern examples for code generation
- Track projects you create

---

## 8. PROJECT TRACKING

All projects created with `simple_codegen new` are tracked in a local database.

### List All Projects
```bash
simple_codegen projects
```

### View Project Details
```bash
simple_codegen projects --project simple_mylib
```

This shows:
- Project type and path
- Generated classes
- Recent activity (generation log)

---

## 9. SIMPLE_CODEGEN COMMANDS REFERENCE

| Command | Description |
|---------|-------------|
| `new <name> [--type library\|cli] [--dir <path>] [--lib <lib>...]` | Create new project |
| `projects [--stats] [--project <name>]` | List projects or show KB stats |
| `init --session <name>` | Initialize generation session |
| `process --input <file> --session <name>` | Process Claude's response |
| `validate --input <file>` | Validate Eiffel code |
| `refine --session <name> --class <CLASS> --issues "..."` | Generate refinement prompt |
| `compile --session <name> --project <path>` | Compile project |
| `generate-tests --session <name> --class <CLASS>` | Generate test prompt |
| `assemble --session <name> --output <path>` | Assemble final project |
| `status --session <name>` | Show session status |
| `research --session <name> --topic "..." --scope <level>` | 7-step research |
| `plan --session <name> --goal "..."` | Design-Build-Implement-Test plan |
| `rules` | Show guardrails and constraints |
| `c-integrate --session <name> --mode <wrap\|library\|win32>` | C integration |
| `inno-install --session <name> --app <name> --exe <exe>` | Generate INNO installer |
| `git-context --session <name>` | Generate git context for prompts |

---

## 10. PROJECT STRUCTURE TEMPLATE

```
PROJECT_ROOT/
├── project_name.ecf        # Main AND test targets
├── README.md               # Project description
├── CHANGELOG.md            # Version history
├── .gitignore              # Git ignores
├── src/                    # Source code
│   ├── main_class.e
│   └── supporting_classes.e
├── testing/                # Tests
│   ├── test_app.e          # Test runner
│   └── lib_tests.e         # Test cases
├── docs/                   # Documentation
│   └── index.html
├── bin/                    # Binaries
│   └── project_name.exe
└── inno/                   # Installer (optional)
    └── project_name.iss
```

---

## 11. COMMON MISTAKES TO AVOID

1. **Acting without prompts** - Always wait for simple_codegen guidance
2. **Creating files in /d/prod/** - Use project directory only
3. **Using ec.exe directly** - Use simple_codegen compile only
4. **Skipping lifecycle stages** - Complete ALL stages for the SCOPE
5. **Not verifying checklist** - Always verify before declaring complete
6. **Forgetting test target in ECF** - Main AND test targets required

---

## 12. WHEN IN DOUBT

1. Run `simple_codegen rules`
2. Ask user for clarification
3. Use `simple_codegen plan` to create a detailed plan
4. Follow the plan systematically

---

## 13. REMEMBER

**You are Claude, working within a constrained box defined by simple_codegen.**

- Follow prompts exactly
- Stay within project boundaries
- Complete all lifecycle stages
- Verify checklist before completion
- Report artifacts created

This manual is your guide. Reference it whenever you're unsure.

---

*End of Claude User Manual*
