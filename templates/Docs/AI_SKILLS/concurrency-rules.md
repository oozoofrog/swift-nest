# Concurrency Rules

Apply this skill whenever async work, task orchestration, cancellation, or actor correctness is involved.

- Prefer structured concurrency.
- Use `async/await` when consistent with the codebase.
- UI-facing state changes should happen on the correct actor.
- Support cancellation for user-triggered async operations where relevant.
- Consider re-entrancy and repeated invocation behavior.
- Prefer predictable state transitions over ad hoc async mutation.
