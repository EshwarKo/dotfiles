# Spec-to-Implementation Pipeline

End-to-end workflow for taking a product specification and implementing it
using agent teams with human-in-the-loop design decisions.

## When to Use

Invoke this skill when the user provides a product spec, feature spec, or
software requirements document and wants a team of agents to implement it.

## Pipeline Steps

### Step 1: Spec Analysis
Read the entire spec. Produce a structured breakdown:
- Features list (numbered)
- Technical requirements
- Ambiguous areas that need user input
- Suggested architecture

### Step 2: User Elicitation (MANDATORY)
Before ANY implementation, ask the user about:
- Architecture choices (monolith vs services, framework, language)
- Data model design decisions
- API design preferences
- UI/UX choices if applicable
- Testing strategy (unit, integration, e2e)
- Priority order of features

Use the AskUserQuestion tool with 2-4 targeted questions.
Wait for answers before proceeding.

### Step 3: Task Decomposition
Break the spec into tasks following these rules:
- Each task maps to a specific file or small set of files
- Tasks should be independent (no two tasks edit the same file)
- 5-6 tasks per worker agent
- Tasks have clear acceptance criteria
- Include test-writing tasks for each feature task

### Step 4: Team Creation
Create an agent team with:
- **Lead** (you): coordinates, assigns tasks, synthesizes
- **Workers** (2-4): implement features in parallel
- **Test Agent** (1): dedicated to running tests and reviewing code
- **Review Agent** (optional): security and code quality review

Use `--teammate-mode tmux` for split-pane visibility.
Require plan approval for workers before they implement.

### Step 5: Ralph Loop Execution
Each worker runs a ralph loop:
1. **Observe**: Read assigned task and relevant existing code
2. **Plan**: Outline implementation approach (gets approved by lead)
3. **Act**: Write code
4. **Test**: Run tests (or signal test agent)
5. **Verify**: Lead reviews, user confirms if design decision needed
6. **Loop**: Pick up next task

### Step 6: Integration & Verification
After all tasks complete:
1. Test agent runs full test suite
2. Lead checks for integration issues
3. Present results to user for final review
4. Create a draft PR if requested

## Rules
- NEVER skip user elicitation for design decisions
- NEVER let two workers edit the same file
- ALWAYS run tests after each task completion
- ALWAYS present progress summary after each loop iteration
- If a worker is stuck for more than 2 attempts, escalate to the user
