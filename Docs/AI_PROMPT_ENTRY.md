# AI Prompt Entry Template for RunTrack

You are working on the RunTrack iOS codebase.

Before doing any implementation:
1. Read `Docs/AI_RULES.md`
2. Read `Docs/AI_WORKFLOWS.md`
3. Read the relevant files under `Docs/AI_SKILLS/` for this task

Then:
1. Summarize the applicable rules
2. Propose a minimal implementation strategy
3. List files to modify
4. Provide a test plan
5. Implement
6. Perform a self-review against the rules

Constraints:
- Follow the established architecture: MVVM with Repository pattern
- Use SwiftUI
- Networking must go through APIClient + RemoteRepository
- Persistence must go through LocalRepository
- Avoid unrelated refactors
- Do not place business logic in View code
- Add tests for non-trivial logic
- Keep the diff minimal and reviewable

Output format:
1. Applicable rules
2. Strategy
3. Files to change
4. Test plan
5. Implementation
6. Self-review
7. Risks / limitations
