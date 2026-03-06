import Foundation

struct HarnessWorkflowDefinition {
    let name: String
    let description: String
    let templatePath: String
    let isDefault: Bool
}

extension HarnessCLI {
    static let defaultWorkflowNames = ["add-feature", "fix-bug", "refactor", "build"]
    static let optionalWorkflowNames = ["permissions", "networking", "review"]

    static let workflowDefinitions: [String: HarnessWorkflowDefinition] = {
        let definitions = [
            HarnessWorkflowDefinition(
                name: "add-feature",
                description: "Use for new features or visible behavior additions.",
                templatePath: "Workflows/add-feature.md",
                isDefault: true
            ),
            HarnessWorkflowDefinition(
                name: "fix-bug",
                description: "Use for bug fixes and regression repairs.",
                templatePath: "Workflows/fix-bug.md",
                isDefault: true
            ),
            HarnessWorkflowDefinition(
                name: "refactor",
                description: "Use for structure-only changes that preserve behavior.",
                templatePath: "Workflows/refactor.md",
                isDefault: true
            ),
            HarnessWorkflowDefinition(
                name: "build",
                description: "Use for build or test verification work.",
                templatePath: "Workflows/build.md",
                isDefault: true
            ),
            HarnessWorkflowDefinition(
                name: "permissions",
                description: "Use when device authorization states are part of the task.",
                templatePath: "Workflows/permissions.md",
                isDefault: false
            ),
            HarnessWorkflowDefinition(
                name: "networking",
                description: "Use for request/response and remote repository changes.",
                templatePath: "Workflows/networking.md",
                isDefault: false
            ),
            HarnessWorkflowDefinition(
                name: "review",
                description: "Use for findings-first code review tasks.",
                templatePath: "Workflows/review.md",
                isDefault: false
            ),
        ]

        return Dictionary(uniqueKeysWithValues: definitions.map { ($0.name, $0) })
    }()

    static func orderedWorkflowDefinitions() -> [HarnessWorkflowDefinition] {
        (defaultWorkflowNames + optionalWorkflowNames).compactMap { workflowDefinitions[$0] }
    }

    static func normalizedWorkflowNames(_ workflows: [String]) -> [String] {
        let valid = workflows.filter { workflowDefinitions[$0] != nil }
        let merged = Set(defaultWorkflowNames).union(valid)
        return orderedWorkflowDefinitions().map(\.name).filter { merged.contains($0) }
    }

    static func workflowContext(config: [String: Any], skills: [String], workflows: [String]) -> [String: String] {
        let sortedSkills = skills.sorted()
        let enabledWorkflows = normalizedWorkflowNames(workflows)

        let selectedSkillsBullets = sortedSkills.isEmpty
            ? "- none selected"
            : sortedSkills.map { "- `\($0)`" }.joined(separator: "\n")

        let workflowRouting = enabledWorkflows.compactMap { name -> String? in
            guard let definition = workflowDefinitions[name] else {
                return nil
            }
            return "- `\(name)`: \(definition.description) Read `.ai-harness/workflows/\(name).md`."
        }.joined(separator: "\n")

        let buildCommand = HarnessDocumentLoader.string(config, key: "build_command", default: "")
        let testCommand = HarnessDocumentLoader.string(config, key: "test_command", default: "")

        let buildSummary = buildCommand.isEmpty
            ? "not configured; inspect the repository build entrypoint first"
            : buildCommand
        let testSummary = testCommand.isEmpty
            ? "not configured; inspect the repository test entrypoint first"
            : testCommand

        let buildBlock: String
        if buildCommand.isEmpty {
            buildBlock = """
            Build command is not configured.
            Discover the correct workspace/project, scheme, and destination before running a build.
            """
        } else {
            buildBlock = """
            Primary build command:
            ```bash
            \(buildCommand)
            ```
            """
        }

        let testBlock: String
        if testCommand.isEmpty {
            testBlock = """
            Test command is not configured.
            Discover the correct test entrypoint before running tests.
            """
        } else {
            testBlock = """
            Primary test command:
            ```bash
            \(testCommand)
            ```
            """
        }

        return [
            "SELECTED_SKILLS_BULLETS": selectedSkillsBullets,
            "WORKFLOW_ROUTING": workflowRouting,
            "BUILD_COMMAND_SUMMARY": buildSummary,
            "TEST_COMMAND_SUMMARY": testSummary,
            "BUILD_COMMAND_BLOCK": buildBlock,
            "TEST_COMMAND_BLOCK": testBlock,
            "ENABLED_WORKFLOWS_BULLETS": enabledWorkflows.map { "- `\($0)`" }.joined(separator: "\n"),
        ]
    }

    static func renderWorkflow(
        named name: String,
        config: [String: Any],
        profileName: String,
        skills: [String],
        workflows: [String],
        repository: HarnessRepository
    ) throws -> String {
        guard let definition = workflowDefinitions[name] else {
            throw HarnessError("Unknown workflow: \(name)")
        }

        let baseContext = try normalizeContext(config: config, profileName: profileName)
        let mergedContext = mergedContext(base: baseContext, extra: workflowContext(config: config, skills: skills, workflows: workflows))
        let templateURL = repository.templatesURL.appendingPathComponent(definition.templatePath)
        let template = try String(contentsOf: templateURL, encoding: .utf8)
        return renderString(template, context: mergedContext)
    }

    static func writeAgentsFile(
        config: [String: Any],
        profileName: String,
        skills: [String],
        workflows: [String],
        repository: HarnessRepository
    ) throws {
        let baseContext = try normalizeContext(config: config, profileName: profileName)
        let mergedContext = mergedContext(base: baseContext, extra: workflowContext(config: config, skills: skills, workflows: workflows))
        let templateURL = repository.templatesURL.appendingPathComponent("AGENTS.md")
        let template = try String(contentsOf: templateURL, encoding: .utf8)
        let outputURL = repository.rootURL.appendingPathComponent("AGENTS.md")
        try renderString(template, context: mergedContext).write(to: outputURL, atomically: true, encoding: .utf8)
    }

    static func scaffoldWorkflowFiles(
        config: [String: Any],
        profileName: String,
        skills: [String],
        workflows: [String],
        repository: HarnessRepository
    ) throws -> [String] {
        let enabledWorkflows = normalizedWorkflowNames(workflows)
        let outputDirectoryURL = repository.stateDirectoryURL.appendingPathComponent("workflows", isDirectory: true)
        try repository.fileManager.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)

        for definition in orderedWorkflowDefinitions() {
            let outputURL = outputDirectoryURL.appendingPathComponent("\(definition.name).md")
            if repository.fileManager.fileExists(atPath: outputURL.path) {
                try? repository.fileManager.removeItem(at: outputURL)
            }
        }

        for name in enabledWorkflows {
            let content = try renderWorkflow(
                named: name,
                config: config,
                profileName: profileName,
                skills: skills,
                workflows: enabledWorkflows,
                repository: repository
            )
            let outputURL = outputDirectoryURL.appendingPathComponent("\(name).md")
            try content.write(to: outputURL, atomically: true, encoding: .utf8)
        }

        return enabledWorkflows
    }

    static func mergedContext(base: [String: String], extra: [String: String]) -> [String: String] {
        base.merging(extra) { _, new in new }
    }
}
