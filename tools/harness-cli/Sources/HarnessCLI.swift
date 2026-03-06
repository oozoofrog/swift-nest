import Foundation

struct HarnessError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

struct ParsedArguments {
    let values: [String: String]
    let flags: Set<String>
    let positionals: [String]

    func value(for key: String) -> String? {
        values[key]
    }

    func contains(_ flag: String) -> Bool {
        flags.contains(flag)
    }
}

struct HarnessState: Codable {
    var profile: String
    var skills: [String]
    var workflows: [String]
    var configPath: String
    var contextPath: String

    enum CodingKeys: String, CodingKey {
        case profile
        case skills
        case workflows
        case configPath = "config_path"
        case contextPath = "context_path"
    }

    init(profile: String, skills: [String], workflows: [String], configPath: String, contextPath: String) {
        self.profile = profile
        self.skills = skills
        self.workflows = workflows
        self.configPath = configPath
        self.contextPath = contextPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(String.self, forKey: .profile)
        skills = try container.decode([String].self, forKey: .skills)
        workflows = try container.decodeIfPresent([String].self, forKey: .workflows) ?? HarnessCLI.defaultWorkflowNames
        configPath = try container.decode(String.self, forKey: .configPath)
        contextPath = try container.decode(String.self, forKey: .contextPath)
    }
}

struct GeneratedManifest: Codable {
    var files: [String]
    var profile: String
}

struct HarnessRepository {
    static let managedPaths: [String] = [
        "Makefile",
        "config/project.example.yaml",
        "harness",
        "profiles",
        "templates",
        "tools/harness-cli/Package.swift",
        "tools/harness-cli/Sources",
    ]

    let rootURL: URL
    let fileManager = FileManager.default

    var templatesURL: URL { rootURL.appendingPathComponent("templates", isDirectory: true) }
    var profilesURL: URL { rootURL.appendingPathComponent("profiles", isDirectory: true) }
    var configURL: URL { rootURL.appendingPathComponent("config", isDirectory: true) }
    var stateDirectoryURL: URL { rootURL.appendingPathComponent(".ai-harness", isDirectory: true) }
    var stateFileURL: URL { stateDirectoryURL.appendingPathComponent("state.json") }

    static func locate() throws -> HarnessRepository {
        if let envRoot = ProcessInfo.processInfo.environment["HARNESS_ROOT"], !envRoot.isEmpty {
            let url = URL(fileURLWithPath: envRoot, isDirectory: true).resolvingSymlinksInPath()
            if isRepositoryRoot(url) {
                return HarnessRepository(rootURL: url)
            }
        }

        var candidates: [URL] = [URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)]
        if let executableURL = Bundle.main.executableURL {
            var current = executableURL.deletingLastPathComponent()
            while true {
                candidates.append(current)
                let parent = current.deletingLastPathComponent()
                if parent.path == current.path {
                    break
                }
                current = parent
            }
        }

        for candidate in candidates {
            let resolved = candidate.resolvingSymlinksInPath()
            if isRepositoryRoot(resolved) {
                return HarnessRepository(rootURL: resolved)
            }
        }

        throw HarnessError("Could not locate the harness repository root.")
    }

    private static func isRepositoryRoot(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: url.appendingPathComponent("templates/Docs/AI_RULES.md").path)
            && fileManager.fileExists(atPath: url.appendingPathComponent("profiles").path)
            && fileManager.fileExists(atPath: url.appendingPathComponent("config/project.example.yaml").path)
    }

    func availableSkills() throws -> [String] {
        let skillsRoot = templatesURL.appendingPathComponent("Docs/AI_SKILLS", isDirectory: true)
        let items = try fileManager.contentsOfDirectory(at: skillsRoot, includingPropertiesForKeys: nil)
        return items
            .filter { $0.pathExtension == "md" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    func availableProfiles() throws -> [URL] {
        let items = try fileManager.contentsOfDirectory(at: profilesURL, includingPropertiesForKeys: nil)
        return items
            .filter { $0.pathExtension == "yaml" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func profileURL(named name: String) throws -> URL {
        let url = profilesURL.appendingPathComponent("\(name).yaml")
        guard fileManager.fileExists(atPath: url.path) else {
            throw HarnessError("Unknown profile: \(name)")
        }
        return url
    }

    func serializeStatePath(_ url: URL) -> String {
        let resolvedRoot = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        let resolvedPath = url.resolvingSymlinksInPath().standardizedFileURL.path

        if resolvedPath == resolvedRoot {
            return "."
        }

        let prefix = resolvedRoot.hasSuffix("/") ? resolvedRoot : resolvedRoot + "/"
        if resolvedPath.hasPrefix(prefix) {
            return String(resolvedPath.dropFirst(prefix.count))
        }

        return resolvedPath
    }

    func resolveStatePath(_ path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        if path == "." {
            return rootURL
        }
        return rootURL.appendingPathComponent(path)
    }

    func loadState() throws -> HarnessState {
        guard fileManager.fileExists(atPath: stateFileURL.path) else {
            throw HarnessError("No .ai-harness/state.json found. Run init first.")
        }
        let data = try Data(contentsOf: stateFileURL)
        return try JSONDecoder().decode(HarnessState.self, from: data)
    }

    func saveState(_ state: HarnessState) throws {
        try fileManager.createDirectory(at: stateDirectoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateFileURL)
    }
}

enum HarnessCLI {
    static let profileGuidance: [String: String] = [
        "basic": "- Keep output concise and implementation-focused.\n- Prefer minimal abstractions.\n- Do not add extra process unless the task clearly benefits.",
        "intermediate": "- Include explicit self-review.\n- Add regression tests for bug fixes when practical.\n- Call out state transition risks when async or permission logic is involved.",
        "advanced": "- Require an explicit risks/limitations section.\n- Be strict about state transitions, privacy, and performance-sensitive paths.\n- Add regression tests for bug fixes and emphasize actor/thread correctness.",
    ]

    static let workflowGuidance: [String: String] = [
        "basic": "- Keep reviews lightweight and focused on correctness.",
        "intermediate": "- Verify layer boundaries and regression risk before finishing.",
        "advanced": "- Verify privacy, performance, concurrency safety, and regression protection before finishing.",
    ]

    static func run(arguments: [String]) throws {
        let repository = try HarnessRepository.locate()

        guard let command = arguments.first else {
            printTopLevelUsage()
            return
        }

        if command == "-h" || command == "--help" || command == "help" {
            printTopLevelUsage()
            return
        }

        let remaining = Array(arguments.dropFirst())

        switch command {
        case "install":
            let parsed = try parse(remaining, valueOptions: ["--target"], flagOptions: ["--force", "--dry-run", "--help", "-h"])
            if parsed.contains("--help") || parsed.contains("-h") {
                printInstallUsage()
                return
            }
            try runInstall(parsed: parsed, repository: repository)
        case "init":
            let parsed = try parse(remaining, valueOptions: ["--config", "--profile", "--skills"], flagOptions: ["--non-interactive", "--help", "-h"])
            if parsed.contains("--help") || parsed.contains("-h") {
                printInitUsage()
                return
            }
            try runInit(parsed: parsed, repository: repository)
        case "upgrade":
            let parsed = try parse(remaining, valueOptions: ["--to"], flagOptions: ["--help", "-h"])
            if parsed.contains("--help") || parsed.contains("-h") {
                printUpgradeUsage()
                return
            }
            try runUpgrade(parsed: parsed, repository: repository)
        case "workflow":
            try runWorkflow(arguments: remaining, repository: repository)
        case "render-context":
            let parsed = try parse(remaining, valueOptions: [], flagOptions: ["--help", "-h"])
            if parsed.contains("--help") || parsed.contains("-h") {
                printRenderContextUsage()
                return
            }
            try runRenderContext(repository: repository)
        case "list-skills":
            let parsed = try parse(remaining, valueOptions: [], flagOptions: ["--help", "-h"])
            if parsed.contains("--help") || parsed.contains("-h") {
                printListSkillsUsage()
                return
            }
            try runListSkills(repository: repository)
        case "list-profiles":
            let parsed = try parse(remaining, valueOptions: [], flagOptions: ["--help", "-h"])
            if parsed.contains("--help") || parsed.contains("-h") {
                printListProfilesUsage()
                return
            }
            try runListProfiles(repository: repository)
        default:
            throw HarnessError("Unknown command: \(command)")
        }
    }

    static func runInstall(parsed: ParsedArguments, repository: HarnessRepository) throws {
        guard parsed.positionals.isEmpty else {
            throw HarnessError("Unexpected positional arguments for install: \(parsed.positionals.joined(separator: " "))")
        }

        guard let target = parsed.value(for: "--target"), !target.isEmpty else {
            throw HarnessError("install requires --target <path>.")
        }

        let targetURL = URL(fileURLWithPath: target, isDirectory: true).standardizedFileURL
        if targetURL.path == repository.rootURL.standardizedFileURL.path {
            throw HarnessError("Target repository must be different from the starter repository root.")
        }

        try repository.fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)

        let result = try installManagedFiles(into: targetURL, force: parsed.contains("--force"), dryRun: parsed.contains("--dry-run"), repository: repository)

        let mode = parsed.contains("--dry-run") ? "Previewed" : "Installed"
        printWarnings(for: targetURL, fileManager: repository.fileManager)
        print("\(mode) harness-managed files into \(targetURL.path)")
        print("Changed files: \(result.copied)")
        print("Unchanged files: \(result.unchanged)")

        if !parsed.contains("--dry-run") {
            print("Next steps:")
            print("  cd \(targetURL.path)")
            print("  test -f config/project.yaml || cp config/project.example.yaml config/project.yaml")
            print("  edit config/project.yaml")
            print("  ./harness init --config config/project.yaml --profile intermediate")
        }
    }

    static func runInit(parsed: ParsedArguments, repository: HarnessRepository) throws {
        guard parsed.positionals.isEmpty else {
            throw HarnessError("Unexpected positional arguments for init: \(parsed.positionals.joined(separator: " "))")
        }

        guard let configValue = parsed.value(for: "--config"), !configValue.isEmpty else {
            throw HarnessError("init requires --config <path>.")
        }

        let configURL = URL(fileURLWithPath: configValue, relativeTo: repository.rootURL).standardizedFileURL
        let config = try HarnessDocumentLoader.loadObject(at: configURL)

        let profileName = try parsed.value(for: "--profile") ?? chooseProfileInteractively(repository: repository)
        let profile = try HarnessDocumentLoader.loadObject(at: repository.profileURL(named: profileName))
        let defaultSkills = HarnessDocumentLoader.stringArray(profile, key: "default_skills")

        let skills: [String]
        if let rawSkills = parsed.value(for: "--skills"), !rawSkills.isEmpty {
            skills = Array(Set(rawSkills.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })).sorted()
        } else if parsed.contains("--non-interactive") {
            skills = defaultSkills
        } else {
            skills = try chooseSkillsInteractively(defaultSkills: defaultSkills, repository: repository)
        }

        let workflows = defaultWorkflowNames
        let context = mergedContext(
            base: try normalizeContext(config: config, profileName: profileName),
            extra: workflowContext(config: config, skills: skills, workflows: workflows)
        )
        try writeDocs(context: context, skills: skills, profileName: profileName, repository: repository)
        let renderedWorkflows = try scaffoldWorkflowFiles(
            config: config,
            profileName: profileName,
            skills: skills,
            workflows: workflows,
            repository: repository
        )
        try writeAgentsFile(
            config: config,
            profileName: profileName,
            skills: skills,
            workflows: renderedWorkflows,
            repository: repository
        )
        let contextURL = try renderContextBundle(
            profileName: profileName,
            skills: skills,
            workflows: renderedWorkflows,
            repository: repository
        )

        try repository.fileManager.createDirectory(at: repository.stateDirectoryURL, withIntermediateDirectories: true)
        let selectedProfileURL = repository.stateDirectoryURL.appendingPathComponent("selected_profile.yaml")
        let selectedSkillsURL = repository.stateDirectoryURL.appendingPathComponent("selected_skills.txt")
        let profileSourceURL = try repository.profileURL(named: profileName)
        let profileText = try String(contentsOf: profileSourceURL, encoding: .utf8)
        try profileText.write(to: selectedProfileURL, atomically: true, encoding: .utf8)
        try (skills.joined(separator: "\n") + "\n").write(to: selectedSkillsURL, atomically: true, encoding: .utf8)

        let state = HarnessState(
            profile: profileName,
            skills: skills,
            workflows: renderedWorkflows,
            configPath: repository.serializeStatePath(configURL),
            contextPath: repository.serializeStatePath(contextURL)
        )
        try repository.saveState(state)

        print("Initialized harness with profile '\(profileName)' and skills: \(skills.joined(separator: ", "))")
        print("Rendered context: \(contextURL.path)")
    }

    static func runUpgrade(parsed: ParsedArguments, repository: HarnessRepository) throws {
        guard parsed.positionals.isEmpty else {
            throw HarnessError("Unexpected positional arguments for upgrade: \(parsed.positionals.joined(separator: " "))")
        }

        guard let targetProfile = parsed.value(for: "--to"), !targetProfile.isEmpty else {
            throw HarnessError("upgrade requires --to <profile>.")
        }

        var state = try repository.loadState()
        let configURL = repository.resolveStatePath(state.configPath)
        guard repository.fileManager.fileExists(atPath: configURL.path) else {
            throw HarnessError("Config path not found: \(configURL.path)")
        }

        let profile = try HarnessDocumentLoader.loadObject(at: repository.profileURL(named: targetProfile))
        let config = try HarnessDocumentLoader.loadObject(at: configURL)
        let mergedSkills = Array(Set(state.skills).union(HarnessDocumentLoader.stringArray(profile, key: "default_skills"))).sorted()
        let workflows = normalizedWorkflowNames(state.workflows)
        let context = mergedContext(
            base: try normalizeContext(config: config, profileName: targetProfile),
            extra: workflowContext(config: config, skills: mergedSkills, workflows: workflows)
        )

        try writeDocs(context: context, skills: mergedSkills, profileName: targetProfile, repository: repository)
        let renderedWorkflows = try scaffoldWorkflowFiles(
            config: config,
            profileName: targetProfile,
            skills: mergedSkills,
            workflows: workflows,
            repository: repository
        )
        try writeAgentsFile(
            config: config,
            profileName: targetProfile,
            skills: mergedSkills,
            workflows: renderedWorkflows,
            repository: repository
        )
        let contextURL = try renderContextBundle(
            profileName: targetProfile,
            skills: mergedSkills,
            workflows: renderedWorkflows,
            repository: repository
        )

        state.profile = targetProfile
        state.skills = mergedSkills
        state.workflows = renderedWorkflows
        state.contextPath = repository.serializeStatePath(contextURL)
        try repository.saveState(state)

        let selectedProfileURL = repository.stateDirectoryURL.appendingPathComponent("selected_profile.yaml")
        let selectedSkillsURL = repository.stateDirectoryURL.appendingPathComponent("selected_skills.txt")
        let profileText = try String(contentsOf: try repository.profileURL(named: targetProfile), encoding: .utf8)
        try profileText.write(to: selectedProfileURL, atomically: true, encoding: .utf8)
        try (mergedSkills.joined(separator: "\n") + "\n").write(to: selectedSkillsURL, atomically: true, encoding: .utf8)

        print("Upgraded harness to '\(targetProfile)'.")
        print("Current skills: \(mergedSkills.joined(separator: ", "))")
    }

    static func runRenderContext(repository: HarnessRepository) throws {
        let state = try repository.loadState()
        let workflows = normalizedWorkflowNames(state.workflows)
        let contextURL = try renderContextBundle(
            profileName: state.profile,
            skills: state.skills,
            workflows: workflows,
            repository: repository
        )
        print(contextURL.path)
    }

    static func runListSkills(repository: HarnessRepository) throws {
        for skill in try repository.availableSkills() {
            print(skill)
        }
    }

    static func runListProfiles(repository: HarnessRepository) throws {
        for profileURL in try repository.availableProfiles() {
            let data = try HarnessDocumentLoader.loadObject(at: profileURL)
            let description = HarnessDocumentLoader.string(data, key: "description", default: "")
            print("\(profileURL.deletingPathExtension().lastPathComponent): \(description)")
        }
    }

    static func runWorkflow(arguments: [String], repository: HarnessRepository) throws {
        guard let subcommand = arguments.first else {
            printWorkflowUsage()
            return
        }

        if subcommand == "-h" || subcommand == "--help" || subcommand == "help" {
            printWorkflowUsage()
            return
        }

        let remaining = Array(arguments.dropFirst())

        switch subcommand {
        case "list":
            let parsed = try parse(remaining, valueOptions: [], flagOptions: ["--help", "-h"])
            if parsed.contains("--help") || parsed.contains("-h") {
                printWorkflowListUsage()
                return
            }
            try runWorkflowList(repository: repository)
        case "print":
            let parsed = try parse(remaining, valueOptions: [], flagOptions: ["--help", "-h"])
            if parsed.contains("--help") || parsed.contains("-h") {
                printWorkflowPrintUsage()
                return
            }
            try runWorkflowPrint(parsed: parsed, repository: repository)
        case "scaffold":
            let parsed = try parse(remaining, valueOptions: [], flagOptions: ["--help", "-h"])
            if parsed.contains("--help") || parsed.contains("-h") {
                printWorkflowScaffoldUsage()
                return
            }
            try runWorkflowScaffold(parsed: parsed, repository: repository)
        default:
            throw HarnessError("Unknown workflow subcommand: \(subcommand)")
        }
    }

    static func runWorkflowList(repository: HarnessRepository) throws {
        let enabled = try currentWorkflowSet(repository: repository)
        for definition in orderedWorkflowDefinitions() {
            let kind = definition.isDefault ? "default" : "optional"
            let status = enabled.contains(definition.name) ? "enabled" : "available"
            print("\(definition.name) [\(kind), \(status)]: \(definition.description)")
        }
    }

    static func runWorkflowPrint(parsed: ParsedArguments, repository: HarnessRepository) throws {
        guard parsed.positionals.count == 1 else {
            throw HarnessError("workflow print requires exactly one workflow name.")
        }

        let name = parsed.positionals[0]
        let (state, config) = try currentStateAndConfig(repository: repository)
        let content = try renderWorkflow(
            named: name,
            config: config,
            profileName: state.profile,
            skills: state.skills,
            workflows: currentWorkflowSet(from: state, extraNames: []),
            repository: repository
        )
        print(content)
    }

    static func runWorkflowScaffold(parsed: ParsedArguments, repository: HarnessRepository) throws {
        let (state, config) = try currentStateAndConfig(repository: repository)
        let workflows = try currentWorkflowSet(from: state, extraNames: parsed.positionals)
        let renderedWorkflows = try scaffoldWorkflowFiles(
            config: config,
            profileName: state.profile,
            skills: state.skills,
            workflows: workflows,
            repository: repository
        )
        try writeAgentsFile(
            config: config,
            profileName: state.profile,
            skills: state.skills,
            workflows: renderedWorkflows,
            repository: repository
        )
        let contextURL = try renderContextBundle(
            profileName: state.profile,
            skills: state.skills,
            workflows: renderedWorkflows,
            repository: repository
        )

        var updatedState = state
        updatedState.workflows = renderedWorkflows
        updatedState.contextPath = repository.serializeStatePath(contextURL)
        try repository.saveState(updatedState)

        print("Scaffolded workflows: \(renderedWorkflows.joined(separator: ", "))")
    }

    static func currentStateAndConfig(repository: HarnessRepository) throws -> (HarnessState, [String: Any]) {
        let state = try repository.loadState()
        let configURL = repository.resolveStatePath(state.configPath)
        guard repository.fileManager.fileExists(atPath: configURL.path) else {
            throw HarnessError("Config path not found: \(configURL.path)")
        }
        let config = try HarnessDocumentLoader.loadObject(at: configURL)
        return (state, config)
    }

    static func currentWorkflowSet(repository: HarnessRepository) throws -> [String] {
        if let state = try? repository.loadState() {
            return normalizedWorkflowNames(state.workflows)
        }
        return defaultWorkflowNames
    }

    static func currentWorkflowSet(from state: HarnessState, extraNames: [String]) throws -> [String] {
        let base = Set(normalizedWorkflowNames(state.workflows))
        let extras = try validateWorkflowNames(extraNames)
        let merged = base.union(extras)
        return orderedWorkflowDefinitions().map(\.name).filter { merged.contains($0) }
    }

    static func validateWorkflowNames(_ names: [String]) throws -> Set<String> {
        var valid: Set<String> = []
        for name in names {
            guard workflowDefinitions[name] != nil else {
                throw HarnessError("Unknown workflow: \(name)")
            }
            valid.insert(name)
        }
        return valid
    }

    static func parse(_ args: [String], valueOptions: Set<String>, flagOptions: Set<String>) throws -> ParsedArguments {
        var values: [String: String] = [:]
        var flags: Set<String> = []
        var positionals: [String] = []
        var index = 0

        while index < args.count {
            let arg = args[index]
            if valueOptions.contains(arg) {
                guard index + 1 < args.count else {
                    throw HarnessError("Missing value for \(arg).")
                }
                values[arg] = args[index + 1]
                index += 2
                continue
            }
            if flagOptions.contains(arg) {
                flags.insert(arg)
                index += 1
                continue
            }
            if arg.hasPrefix("--") || arg.hasPrefix("-") {
                throw HarnessError("Unknown option: \(arg)")
            }
            positionals.append(arg)
            index += 1
        }

        return ParsedArguments(values: values, flags: flags, positionals: positionals)
    }

    static func normalizeContext(config: [String: Any], profileName: String) throws -> [String: String] {
        guard let profileGuidance = profileGuidance[profileName], let workflowGuidance = workflowGuidance[profileName] else {
            throw HarnessError("Unknown profile: \(profileName)")
        }

        return [
            "PROJECT_NAME": HarnessDocumentLoader.string(config, key: "project_name", default: "MyApp"),
            "OPTIONAL_WATCHOS_LINE": HarnessDocumentLoader.string(config, key: "optional_watchos_line", default: ""),
            "UI_FRAMEWORK": HarnessDocumentLoader.string(config, key: "ui_framework", default: "SwiftUI"),
            "ARCHITECTURE_STYLE": HarnessDocumentLoader.string(config, key: "architecture_style", default: "MVVM"),
            "MIN_IOS_VERSION": HarnessDocumentLoader.string(config, key: "min_ios_version", default: "iOS 17"),
            "PACKAGE_MANAGER": HarnessDocumentLoader.string(config, key: "package_manager", default: "Swift Package Manager"),
            "TEST_FRAMEWORK": HarnessDocumentLoader.string(config, key: "test_framework", default: "XCTest"),
            "LINT_TOOLS": HarnessDocumentLoader.string(config, key: "lint_tools", default: "SwiftLint, SwiftFormat"),
            "NETWORK_LAYER_NAME": HarnessDocumentLoader.string(config, key: "network_layer_name", default: "APIClient"),
            "PERSISTENCE_LAYER_NAME": HarnessDocumentLoader.string(config, key: "persistence_layer_name", default: "Repository"),
            "LOGGING_SYSTEM": HarnessDocumentLoader.string(config, key: "logging_system", default: "OSLog"),
            "PRIVACY_REQUIREMENTS": HarnessDocumentLoader.string(config, key: "privacy_requirements", default: "least-privilege and privacy-safe handling"),
            "PREFERRED_FILE_LINE_LIMIT": HarnessDocumentLoader.string(config, key: "preferred_file_line_limit", default: "300"),
            "HEALTHKIT_LAYER_NAME": HarnessDocumentLoader.string(config, key: "healthkit_layer_name", default: "HealthKitManager"),
            "HARNESS_PROFILE": profileName,
            "PROFILE_GUIDANCE": profileGuidance,
            "WORKFLOW_GUIDANCE": workflowGuidance,
        ]
    }

    static func renderString(_ template: String, context: [String: String]) -> String {
        var rendered = template
        for (key, value) in context {
            rendered = rendered.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return rendered
    }

    static func writeDocs(context: [String: String], skills: [String], profileName: String, repository: HarnessRepository) throws {
        let fileManager = repository.fileManager
        let docsURL = repository.rootURL.appendingPathComponent("Docs", isDirectory: true)
        let skillsURL = docsURL.appendingPathComponent("AI_SKILLS", isDirectory: true)
        try fileManager.createDirectory(at: docsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: skillsURL, withIntermediateDirectories: true)

        for relativePath in ["Docs/AI_RULES.md", "Docs/AI_WORKFLOWS.md", "Docs/AI_PROMPT_ENTRY.md"] {
            let sourceURL = repository.templatesURL.appendingPathComponent(relativePath)
            let destinationURL = repository.rootURL.appendingPathComponent(relativePath)
            let template = try String(contentsOf: sourceURL, encoding: .utf8)
            try renderString(template, context: context).write(to: destinationURL, atomically: true, encoding: .utf8)
        }

        let manifestURL = skillsURL.appendingPathComponent(".generated_manifest.json")
        if fileManager.fileExists(atPath: manifestURL.path) {
            let data = try? Data(contentsOf: manifestURL)
            if let data, let manifest = try? JSONDecoder().decode(GeneratedManifest.self, from: data) {
                for fileName in manifest.files {
                    let generatedURL = skillsURL.appendingPathComponent(fileName)
                    if fileManager.fileExists(atPath: generatedURL.path) {
                        try? fileManager.removeItem(at: generatedURL)
                    }
                }
            }
        }

        var generatedFiles: [String] = []
        for skill in skills {
            let sourceURL = repository.templatesURL.appendingPathComponent("Docs/AI_SKILLS/\(skill).md")
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw HarnessError("Unknown skill template: \(skill)")
            }
            let destinationURL = skillsURL.appendingPathComponent(sourceURL.lastPathComponent)
            let template = try String(contentsOf: sourceURL, encoding: .utf8)
            try renderString(template, context: context).write(to: destinationURL, atomically: true, encoding: .utf8)
            generatedFiles.append(sourceURL.lastPathComponent)
        }

        let manifest = GeneratedManifest(files: generatedFiles, profile: profileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: manifestURL)
    }

    static func renderContextBundle(
        profileName: String,
        skills: [String],
        workflows: [String],
        repository: HarnessRepository
    ) throws -> URL {
        let docsURL = repository.rootURL.appendingPathComponent("Docs", isDirectory: true)
        let outputDirectoryURL = repository.stateDirectoryURL
        try repository.fileManager.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)
        let outputURL = outputDirectoryURL.appendingPathComponent("rendered_context.md")

        var sections: [String] = []
        let agentsURL = repository.rootURL.appendingPathComponent("AGENTS.md")
        if repository.fileManager.fileExists(atPath: agentsURL.path) {
            let content = try String(contentsOf: agentsURL, encoding: .utf8)
            sections.append("\n\n<!-- AGENTS.md -->\n\n\(content)")
        }

        for name in ["AI_RULES.md", "AI_WORKFLOWS.md", "AI_PROMPT_ENTRY.md"] {
            let fileURL = docsURL.appendingPathComponent(name)
            if repository.fileManager.fileExists(atPath: fileURL.path) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                sections.append("\n\n<!-- \(name) -->\n\n\(content)")
            }
        }

        for skill in skills {
            let fileURL = docsURL.appendingPathComponent("AI_SKILLS/\(skill).md")
            if repository.fileManager.fileExists(atPath: fileURL.path) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                sections.append("\n\n<!-- AI_SKILLS/\(skill).md -->\n\n\(content)")
            }
        }

        for workflow in normalizedWorkflowNames(workflows) {
            let fileURL = repository.stateDirectoryURL.appendingPathComponent("workflows/\(workflow).md")
            if repository.fileManager.fileExists(atPath: fileURL.path) {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                sections.append("\n\n<!-- workflows/\(workflow).md -->\n\n\(content)")
            }
        }

        let header = """
        # Rendered AI Harness Context

        Profile: \(profileName)

        Skills: \(skills.joined(separator: ", "))

        Workflows: \(normalizedWorkflowNames(workflows).joined(separator: ", "))
        """
        try (header + sections.joined()).write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL
    }

    static func chooseProfileInteractively(repository: HarnessRepository) throws -> String {
        let profiles = try repository.availableProfiles().map { $0.deletingPathExtension().lastPathComponent }
        print("Profiles:")
        for (index, name) in profiles.enumerated() {
            print("  \(index + 1). \(name)")
        }
        print("Choose profile number (default 1): ", terminator: "")
        let raw = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let chosen = raw.isEmpty ? "1" : raw
        guard let number = Int(chosen), profiles.indices.contains(number - 1) else {
            throw HarnessError("Profile choice out of range")
        }
        return profiles[number - 1]
    }

    static func chooseSkillsInteractively(defaultSkills: [String], repository: HarnessRepository) throws -> [String] {
        let skills = try repository.availableSkills()
        print("Available skills:")
        for (index, skill) in skills.enumerated() {
            let mark = defaultSkills.contains(skill) ? "*" : " "
            print(String(format: "  %2d. [%@] %@", index + 1, mark, skill))
        }
        print("Select skills by comma-separated numbers (Enter for defaults): ", terminator: "")
        let raw = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty {
            return defaultSkills
        }

        var chosen: [String] = []
        for token in raw.split(separator: ",") {
            let trimmed = token.trimmingCharacters(in: .whitespaces)
            guard let number = Int(trimmed) else {
                throw HarnessError("Invalid selection: \(trimmed)")
            }
            guard skills.indices.contains(number - 1) else {
                throw HarnessError("Selection out of range: \(trimmed)")
            }
            chosen.append(skills[number - 1])
        }
        return Array(Set(chosen)).sorted()
    }

    static func installManagedFiles(into targetURL: URL, force: Bool, dryRun: Bool, repository: HarnessRepository) throws -> (copied: Int, unchanged: Int) {
        let fileManager = repository.fileManager
        var copied = 0
        var unchanged = 0
        var conflicts: [String] = []

        for (sourceURL, relativePath) in try iterManagedFiles(repository: repository) {
            let destinationURL = targetURL.appendingPathComponent(relativePath)
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: destinationURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                throw HarnessError("Expected file but found directory at target path: \(relativePath)")
            }

            if fileManager.fileExists(atPath: destinationURL.path) {
                if try filesMatch(sourceURL, destinationURL) {
                    unchanged += 1
                    continue
                }
                if !force {
                    conflicts.append(relativePath)
                    continue
                }
            }

            if dryRun {
                let action = fileManager.fileExists(atPath: destinationURL.path) ? "overwrite" : "copy"
                print("\(action): \(relativePath)")
                copied += 1
                continue
            }

            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            copied += 1
        }

        if !conflicts.isEmpty {
            let joined = conflicts.map { "- \($0)" }.joined(separator: "\n")
            throw HarnessError(
                "Refusing to overwrite managed files in the target repository.\n"
                    + "Re-run with --force if these files should be replaced:\n"
                    + joined
            )
        }

        return (copied, unchanged)
    }

    static func iterManagedFiles(repository: HarnessRepository) throws -> [(URL, String)] {
        var files: [(URL, String)] = []
        for relativePath in HarnessRepository.managedPaths {
            let sourceURL = repository.rootURL.appendingPathComponent(relativePath)
            var isDirectory: ObjCBool = false
            guard repository.fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else {
                throw HarnessError("Managed path is missing from starter: \(relativePath)")
            }
            if isDirectory.boolValue {
                let enumerator = repository.fileManager.enumerator(at: sourceURL, includingPropertiesForKeys: [.isRegularFileKey])
                while let fileURL = enumerator?.nextObject() as? URL {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                    if resourceValues.isRegularFile == true {
                        let relativeURL = fileURL.path.replacingOccurrences(of: repository.rootURL.path + "/", with: "")
                        files.append((fileURL, relativeURL))
                    }
                }
            } else {
                files.append((sourceURL, relativePath))
            }
        }
        return files.sorted { $0.1 < $1.1 }
    }

    static func filesMatch(_ lhs: URL, _ rhs: URL) throws -> Bool {
        let lhsData = try Data(contentsOf: lhs)
        let rhsData = try Data(contentsOf: rhs)
        return lhsData == rhsData
    }

    static func printWarnings(for targetURL: URL, fileManager: FileManager) {
        let gitignoreURL = targetURL.appendingPathComponent(".gitignore")
        if let gitignoreText = try? String(contentsOf: gitignoreURL, encoding: .utf8) {
            for rawLine in gitignoreText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line == ".ai-harness" || line == ".ai-harness/" {
                    print("warning: .gitignore ignores .ai-harness/. Remove that rule before committing generated state.")
                    break
                }
            }
        }

        if fileManager.fileExists(atPath: targetURL.appendingPathComponent("Docs").path) {
            print("warning: Docs/ already exists. Review generated files after init before committing.")
        }
        if fileManager.fileExists(atPath: targetURL.appendingPathComponent(".ai-harness").path) {
            print("warning: .ai-harness/ already exists. Review current state before rerendering or upgrading.")
        }
    }

    static func printTopLevelUsage() {
        print(
            """
            usage: harness <command> [options]

            Commands:
              install        Install harness-managed files into a target repository
              init           Initialize docs from config, profile, and skills
              upgrade        Upgrade to a stricter profile
              workflow       Manage workflow scaffolds
              render-context Render the combined context bundle
              list-skills    List available skills
              list-profiles  List available profiles
            """
        )
    }

    static func printInstallUsage() {
        print("usage: harness install --target <path> [--force] [--dry-run]")
    }

    static func printInitUsage() {
        print("usage: harness init --config <path> [--profile <name>] [--skills <csv>] [--non-interactive]")
    }

    static func printUpgradeUsage() {
        print("usage: harness upgrade --to <profile>")
    }

    static func printWorkflowUsage() {
        print(
            """
            usage: harness workflow <subcommand> [options]

            Subcommands:
              list                 List supported workflows and current status
              print <name>         Print one rendered workflow to stdout
              scaffold [name ...]  Regenerate current workflows or add optional workflows
            """
        )
    }

    static func printWorkflowListUsage() {
        print("usage: harness workflow list")
    }

    static func printWorkflowPrintUsage() {
        print("usage: harness workflow print <name>")
    }

    static func printWorkflowScaffoldUsage() {
        print("usage: harness workflow scaffold [name ...]")
    }

    static func printRenderContextUsage() {
        print("usage: harness render-context")
    }

    static func printListSkillsUsage() {
        print("usage: harness list-skills")
    }

    static func printListProfilesUsage() {
        print("usage: harness list-profiles")
    }
}
