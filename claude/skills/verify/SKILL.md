# Independent Verification Skill

Perform independent verification of plans, implementations, or claims.
Act as a fresh reviewer, not as the original author.

## Verification Modes

### Plan Verification
Review a proposed plan before execution:
1. Check each step for logical correctness
2. Identify missing steps or prerequisites
3. Flag scope creep or unnecessary complexity
4. Verify file paths and dependencies exist
5. Assess risk level of each change

### Code Verification
Review implemented code changes:
1. Read the diff carefully, line by line
2. Check for bugs, edge cases, and security issues
3. Verify tests cover the changes
4. Flag any OWASP top 10 vulnerabilities
5. Check for unnecessary complexity or dead code

### Claim Verification
Double-check factual claims in research output:
1. Re-verify each claim independently
2. Check sources if URLs are provided
3. Flag anything that can't be verified

## Output Format

Always produce a verification table:

```
| Item | Status | Notes |
|------|--------|-------|
| ... | PASS/FAIL/UNCERTAIN | ... |
```

End with an overall assessment: APPROVED / NEEDS CHANGES / BLOCKED.

## Rules

- Be skeptical — assume nothing is correct until verified
- Use subagents (Explore type) for codebase checks if needed
- If you can't verify something, say so explicitly
- Do not rubber-stamp; provide genuine critical review
