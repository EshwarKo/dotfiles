# User Elicitation Skill

Before starting any non-trivial task, gather clear requirements through
structured questioning. Do not guess — ask.

## When to Elicit

- New feature requests with ambiguous scope
- Bug reports missing reproduction steps
- Refactoring without clear goals
- Any task where you'd need to make more than 2 assumptions

## Process

1. Read the request carefully
2. Identify what's ambiguous or underspecified
3. Ask 2-4 targeted questions using the AskUserQuestion tool
4. Confirm your understanding with a brief summary
5. Only then begin implementation

## Question Categories

- **Scope**: What's in? What's out? What's the MVP?
- **Context**: Who uses this? What environment? What constraints?
- **Edge cases**: What happens when X fails? Empty input? Concurrent access?
- **Verification**: How do we know it works? What does success look like?
- **Priority**: Must-have vs nice-to-have?

## Anti-patterns

- Do NOT ask more than 4 questions at once
- Do NOT ask questions you can answer by reading the codebase
- Do NOT ask about implementation details the user doesn't care about
- Do NOT re-ask questions already answered in CLAUDE.md or conversation
