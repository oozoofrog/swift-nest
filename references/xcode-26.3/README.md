# Xcode 26.3 IDEIntelligenceChat Reference

This folder contains a harness-friendly reorganization of Xcode's IDEIntelligenceChat resources.
It is meant as reference material for evolving this project's prompt templates, workflow docs, and future profile/skill design.

## Why This Structure Is Useful

- `prompts/system-core/` exposes the top-level assistant persona and Apple-first coding rules that most closely map to harness-level instructions.
- `prompts/integration-and-editing/` isolates the edit/integration prompts that are useful when designing precise full-file rewrite flows.
- `prompts/planning-and-variants/` separates planner orchestration and variant prompts so model-specific differences are easy to compare.
- `prompts/context-and-grounding/` shows how Xcode packages query, file, selection, issue, and snippet context around the model.
- `prompts/guidelines-and-retrieval/` surfaces the retrieval and answer-shaping helpers that are relevant for future skill design.
- `prompts/generation-tools/` groups task-specific prompt templates for explanation, documentation, preview, and playground generation.
- `docs/additional-documentation/` keeps Apple-first topical reference docs in one place for fast browsing.
- `metadata/` provides model and pairing metadata in JSON for quick inspection.

## Prompt Categories

### system-core
- Count: 6
- Why it matters: Top-level assistant personas and tool-aware system prompts that shape the harness voice and default coding rules.
- Start here: BasicSystemPrompt, ReasoningSystemPrompt, ToolAssistedBasicSystemPrompt, AgentSystemPromptAddition

### integration-and-editing
- Count: 7
- Why it matters: Edit-oriented prompts that show how Xcode structures full-file rewrites, fast-apply edits, and code integration flows.
- Start here: IntegratorSystemPrompt, IntegratorUserPrompt, FastApplyIntegratorSystemPrompt, NewCodeIntegratorSystemPrompt

### planning-and-variants
- Count: 5
- Why it matters: Planner and variant prompts that show orchestration strategies, model-specific prompt variants, and experimental branches.
- Start here: PlannerExecutorStylePlannerSystemPrompt, PlannerExecutorStylePlannerSystemPrompt-gpt_5, VariantASystemPrompt, VariantBSystemPrompt

### context-and-grounding
- Count: 14
- Why it matters: Context-packing templates that explain what Xcode injects alongside the user query: files, selections, issues, snippets, and other grounding inputs.
- Start here: Query, CurrentFile, CurrentSelection, ContextItems, AgentAdditionalContext

### guidelines-and-retrieval
- Count: 7
- Why it matters: Guideline and retrieval support prompts that reveal how Xcode constrains answers, expands searches, and injects retrieval hints.
- Start here: InQueryDetailedGuidelines, ToolAssistedInQueryDetailedGuidelines, InstructionEmbeddingsQueryExpansion, LocalInfillEmbeddingsQueryExpansion

### generation-tools
- Count: 7
- Why it matters: Task-shaped templates for explanation, documentation, preview generation, and playground generation that can inspire harness workflows.
- Start here: CodingToolTemplateExplain, CodingToolTemplateDocument, GenerateDocumentation, GeneratePreview

## Additional Documentation

- Folder: `docs/additional-documentation/`
- Start here: FoundationModels-Using-on-device-LLM-in-your-app.md, Swift-Concurrency-Updates.md, SwiftUI-WebKit-Integration.md, Implementing-Visual-Intelligence-in-iOS.md

## Metadata

- `metadata/AgentVersions.json` shows bundled agent binary versions.
- `metadata/ApprovedIntegrationModelPairings.json` shows approved executor pairings.
- `metadata/version.json` captures the code intelligence bundle version metadata.
