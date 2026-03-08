import Foundation

struct SwiftNestError: Error {
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

enum SwiftNestSkillAgent: String, CaseIterable, Equatable {
    case codex

    static let noneOption = "none"

    static var supportedCodesSummary: String {
        ([noneOption] + allCases.map(\.rawValue)).joined(separator: ", ")
    }

    static func normalized(from rawValue: String) -> SwiftNestSkillAgent? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return SwiftNestSkillAgent(rawValue: normalized)
    }

    static func resolved(from rawValue: String?) -> SwiftNestSkillAgent? {
        guard let rawValue else {
            return nil
        }

        let normalizedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedValue.isEmpty || normalizedValue == noneOption {
            return nil
        }
        return normalized(from: normalizedValue)
    }
}

struct SwiftNestState: Codable {
    var dataVersion: Int
    var profile: String
    var skills: [String]
    var workflows: [String]
    var skillAgent: String?
    var configPath: String
    var contextPath: String

    enum CodingKeys: String, CodingKey {
        case dataVersion = "data_version"
        case profile
        case skills
        case workflows
        case skillAgent = "skill_agent"
        case configPath = "config_path"
        case contextPath = "context_path"
    }

    init(
        dataVersion: Int = SwiftNestCLI.currentDataVersion,
        profile: String,
        skills: [String],
        workflows: [String],
        skillAgent: String? = nil,
        configPath: String,
        contextPath: String
    ) {
        self.dataVersion = dataVersion
        self.profile = profile
        self.skills = skills
        self.workflows = workflows
        self.skillAgent = skillAgent
        self.configPath = configPath
        self.contextPath = contextPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dataVersion = try container.decodeIfPresent(Int.self, forKey: .dataVersion) ?? 1
        profile = try container.decode(String.self, forKey: .profile)
        skills = try container.decode([String].self, forKey: .skills)
        workflows = try container.decodeIfPresent([String].self, forKey: .workflows) ?? SwiftNestCLI.defaultWorkflowNames
        skillAgent = try container.decodeIfPresent(String.self, forKey: .skillAgent)
        configPath = try container.decode(String.self, forKey: .configPath)
        contextPath = try container.decode(String.self, forKey: .contextPath)
    }
}

struct SwiftNestGeneratedManifest: Codable {
    var files: [String]
    var profile: String
}

struct SwiftNestAgentSkillManifest: Codable {
    var agent: String
    var installedDirectories: [String]
}

struct SwiftNestRepository {
    static let managedPaths: [String] = [
        "Makefile",
        "config/project.example.yaml",
        "profiles",
        "templates",
    ]

    let rootURL: URL
    let assetRootURL: URL
    let fileManager = FileManager.default

    init(rootURL: URL, assetRootURL: URL? = nil) {
        self.rootURL = rootURL.resolvingSymlinksInPath().standardizedFileURL
        self.assetRootURL = (assetRootURL ?? rootURL).resolvingSymlinksInPath().standardizedFileURL
    }

    var templatesURL: URL { assetRootURL.appendingPathComponent("templates", isDirectory: true) }
    var profilesURL: URL { assetRootURL.appendingPathComponent("profiles", isDirectory: true) }
    var resourcesURL: URL { assetRootURL.appendingPathComponent("resources", isDirectory: true) }
    var configURL: URL { rootURL.appendingPathComponent("config", isDirectory: true) }
    var stateDirectoryURL: URL { rootURL.appendingPathComponent(".swiftnest", isDirectory: true) }
    var stateFileURL: URL { stateDirectoryURL.appendingPathComponent("state.json") }
    var selectedSkillAgentURL: URL { stateDirectoryURL.appendingPathComponent("selected_skill_agent.txt") }
    var agentSkillStateDirectoryURL: URL { stateDirectoryURL.appendingPathComponent("agent_skills", isDirectory: true) }
    var agentsDirectoryURL: URL { rootURL.appendingPathComponent(".agents", isDirectory: true) }
    var agentSkillsDirectoryURL: URL { agentsDirectoryURL.appendingPathComponent("skills", isDirectory: true) }
    var isStarterCheckout: Bool {
        fileManager.fileExists(atPath: rootURL.appendingPathComponent("packaging/homebrew/swiftnest.rb.template").path)
            && fileManager.fileExists(atPath: rootURL.appendingPathComponent("tools/swiftnest-cli/Package.swift").path)
    }

    static func locateAssetRoot() throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        let environmentKeys = ["SWIFTNEST_ASSET_ROOT", "SWIFTNEST_ROOT", "HARNESS_ROOT"]
        for key in environmentKeys {
            if let envRoot = environment[key], !envRoot.isEmpty {
                let url = URL(fileURLWithPath: envRoot, isDirectory: true).resolvingSymlinksInPath().standardizedFileURL
                if isRepositoryRoot(url) {
                    return url
                }
            }
        }

        var candidates: [URL] = []
        if let executableURL = Bundle.main.executableURL {
            var current = executableURL
                .deletingLastPathComponent()
                .resolvingSymlinksInPath()
                .standardizedFileURL
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
            let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
            if isRepositoryRoot(resolved) {
                return resolved
            }
        }

        throw SwiftNestError(SwiftNestLocalizer.text(.couldNotLocateAssetRoot))
    }

    static func findManagedRepository(
        assetRootURL: URL,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath
    ) -> SwiftNestRepository? {
        var current = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let resolvedAssetRoot = assetRootURL.resolvingSymlinksInPath().standardizedFileURL

        while true {
            if isRepositoryRoot(current) {
                let repository = SwiftNestRepository(rootURL: current, assetRootURL: resolvedAssetRoot)
                if !repository.isStarterCheckout {
                    return repository
                }
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }

        return nil
    }

    static func locateManagedRepository(
        assetRootURL: URL,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath
    ) throws -> SwiftNestRepository {
        if let repository = findManagedRepository(
            assetRootURL: assetRootURL,
            currentDirectoryPath: currentDirectoryPath
        ) {
            return repository
        }

        throw SwiftNestError(SwiftNestLocalizer.text(.couldNotLocateRepositoryRoot))
    }

    static func findGitRepositoryRoot(
        currentDirectoryURL: URL,
        fileManager: FileManager = .default
    ) -> URL? {
        var current = currentDirectoryURL.resolvingSymlinksInPath().standardizedFileURL

        while true {
            let gitURL = current.appendingPathComponent(".git")
            if fileManager.fileExists(atPath: gitURL.path) {
                return current
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }

        return nil
    }

    static func isRepositoryRoot(_ url: URL) -> Bool {
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
            throw SwiftNestError(SwiftNestLocalizer.text(.unknownProfile, name))
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

    func loadState() throws -> SwiftNestState {
        guard fileManager.fileExists(atPath: stateFileURL.path) else {
            throw SwiftNestError(SwiftNestLocalizer.text(.noStateFile))
        }
        let data = try Data(contentsOf: stateFileURL)
        return try JSONDecoder().decode(SwiftNestState.self, from: data)
    }

    func saveState(_ state: SwiftNestState) throws {
        try fileManager.createDirectory(at: stateDirectoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateFileURL)
    }
}

enum SwiftNestCLI {
    // data version 1: repo-local CLI bootstrap installation
    // data version 2: global runtime with asset-root / managed-repo separation
    // data version 3: .swiftnest state directory rename
    static let currentDataVersion = 3
    static let fallbackCLIVersion = "development"
    static let codexGeneratedSkillMarker = "<!-- Generated by SwiftNest for Codex"
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
    static func run(
        arguments: [String],
        output: (String) -> Void = { print($0) },
        versionResolver: () -> String = { resolveCLIVersion() }
    ) throws {
        guard let command = arguments.first else {
            printTopLevelUsage()
            return
        }

        if command == "-v" || command == "--version" {
            output(versionResolver())
            return
        }

        if command == "-h" || command == "--help" || command == "help" {
            printTopLevelUsage()
            return
        }

        let remaining = Array(arguments.dropFirst())
        let assetRootURL = try SwiftNestRepository.locateAssetRoot()
        let assetRepository = SwiftNestRepository(rootURL: assetRootURL, assetRootURL: assetRootURL)

        switch command {
        case "onboard":
            let parsed = try parse(
                remaining,
                valueOptions: ["--target", "--config", "--profile", "--skills", "--workflows", "--skill-agent"],
                flagOptions: ["--non-interactive", "--force", "--help", "-h"]
            )
            if parsed.contains("--help") || parsed.contains("-h") {
                printOnboardUsage()
                return
            }
            try runOnboard(parsed: parsed, repository: assetRepository)
        case "install":
            let parsed = try parse(remaining, valueOptions: ["--target"], flagOptions: ["--force", "--dry-run", "--help", "-h"])
            if parsed.contains("--help") || parsed.contains("-h") {
                printInstallUsage()
                return
            }
            try runInstall(parsed: parsed, repository: assetRepository)
        case "init":
            let parsed = try parse(
                remaining,
                valueOptions: ["--config", "--profile", "--skills", "--workflows", "--skill-agent"],
                flagOptions: ["--non-interactive", "--help", "-h"]
            )
            if parsed.contains("--help") || parsed.contains("-h") {
                printInitUsage()
                return
            }
            let repository = try SwiftNestRepository.locateManagedRepository(assetRootURL: assetRootURL)
            try runInit(parsed: parsed, repository: repository)
        case "upgrade":
            let parsed = try parse(remaining, valueOptions: ["--to"], flagOptions: ["--help", "-h"])
            if parsed.contains("--help") || parsed.contains("-h") {
                printUpgradeUsage()
                return
            }
            let repository = try SwiftNestRepository.locateManagedRepository(assetRootURL: assetRootURL)
            try runUpgrade(parsed: parsed, repository: repository)
        case "workflow":
            if remaining.isEmpty || ["-h", "--help", "help"].contains(remaining[0]) {
                printWorkflowUsage()
                return
            }
            if remaining.count >= 2 && (remaining.contains("--help") || remaining.contains("-h")) {
                switch remaining[0] {
                case "list":
                    printWorkflowListUsage()
                case "print":
                    printWorkflowPrintUsage()
                case "scaffold":
                    printWorkflowScaffoldUsage()
                default:
                    throw SwiftNestError(SwiftNestLocalizer.text(.unknownWorkflowSubcommand, remaining[0]))
                }
                return
            }
            let repository = try SwiftNestRepository.locateManagedRepository(assetRootURL: assetRootURL)
            try runWorkflow(arguments: remaining, repository: repository)
        case "render-context":
            let parsed = try parse(remaining, valueOptions: [], flagOptions: ["--help", "-h"])
            if parsed.contains("--help") || parsed.contains("-h") {
                printRenderContextUsage()
                return
            }
            let repository = try SwiftNestRepository.locateManagedRepository(assetRootURL: assetRootURL)
            try runRenderContext(repository: repository)
        case "list-skills":
            let parsed = try parse(remaining, valueOptions: [], flagOptions: ["--help", "-h"])
            if parsed.contains("--help") || parsed.contains("-h") {
                printListSkillsUsage()
                return
            }
            try runListSkills(repository: assetRepository)
        case "list-profiles":
            let parsed = try parse(remaining, valueOptions: [], flagOptions: ["--help", "-h"])
            if parsed.contains("--help") || parsed.contains("-h") {
                printListProfilesUsage()
                return
            }
            try runListProfiles(repository: assetRepository)
        default:
            throw SwiftNestError(SwiftNestLocalizer.text(.unknownCommand, command))
        }
    }

    static func resolveCLIVersion(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        assetRootLocator: () throws -> URL = { try SwiftNestRepository.locateAssetRoot() },
        fileManager: FileManager = .default,
        gitVersionProvider: (URL) -> String? = { gitDescribedVersion(at: $0) }
    ) -> String {
        if let version = sanitizedVersion(environment["SWIFTNEST_VERSION"]) {
            return version
        }

        if let assetRootURL = try? assetRootLocator() {
            let versionFileURL = assetRootURL.appendingPathComponent("VERSION")
            if fileManager.fileExists(atPath: versionFileURL.path),
               let rawValue = try? String(contentsOf: versionFileURL, encoding: .utf8),
               let version = sanitizedVersion(rawValue)
            {
                return version
            }

            if let version = gitVersionProvider(assetRootURL) {
                return version
            }
        }

        return fallbackCLIVersion
    }

    static func sanitizedVersion(_ rawValue: String?) -> String? {
        guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func gitDescribedVersion(at assetRootURL: URL) -> String? {
        let gitMetadataURL = assetRootURL.appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitMetadataURL.path) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", assetRootURL.path, "describe", "--tags", "--always", "--dirty"]
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        return sanitizedVersion(String(decoding: stdoutData, as: UTF8.self))
    }

    static func runInstall(
        parsed: ParsedArguments,
        repository: SwiftNestRepository,
        currentDirectoryURL: URL? = nil,
        standardInputIsTTY: () -> Bool = {
            isatty(fileno(stdin)) != 0
        },
        lineReader: () -> String? = {
            readLine()
        }
    ) throws {
        guard parsed.positionals.isEmpty else {
            throw SwiftNestError(
                SwiftNestLocalizer.text(.unexpectedPositionalsInstall, parsed.positionals.joined(separator: " "))
            )
        }

        let targetURL = try resolveInstallTargetURL(
            parsed: parsed,
            repository: repository,
            currentDirectoryURL: currentDirectoryURL,
            standardInputIsTTY: standardInputIsTTY,
            lineReader: lineReader
        )
        if targetURL.path == repository.rootURL.standardizedFileURL.path {
            throw SwiftNestError(SwiftNestLocalizer.text(.targetRepositoryMustDiffer))
        }

        try repository.fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)

        let result = try installManagedFiles(into: targetURL, force: parsed.contains("--force"), dryRun: parsed.contains("--dry-run"), repository: repository)

        let installMessage = parsed.contains("--dry-run")
            ? SwiftNestLocalizer.text(.previewedManagedFilesInto, targetURL.path)
            : SwiftNestLocalizer.text(.installedManagedFilesInto, targetURL.path)
        printWarnings(for: targetURL, fileManager: repository.fileManager)
        print(installMessage)
        print(SwiftNestLocalizer.text(.changedFiles, result.copied))
        print(SwiftNestLocalizer.text(.unchangedFiles, result.unchanged))

        if !parsed.contains("--dry-run") {
            print(SwiftNestLocalizer.text(.nextSteps))
            print("  cd \(targetURL.path)")
            print("  swiftnest onboard --config config/project.yaml")
            print("  swiftnest init --config config/project.yaml --profile intermediate")
        }
    }

    static func resolveInstallTargetURL(
        parsed: ParsedArguments,
        repository: SwiftNestRepository,
        currentDirectoryURL: URL? = nil,
        standardInputIsTTY: () -> Bool = {
            isatty(fileno(stdin)) != 0
        },
        lineReader: () -> String? = {
            readLine()
        }
    ) throws -> URL {
        if let rawTarget = parsed.value(for: "--target"), !rawTarget.isEmpty {
            return URL(fileURLWithPath: rawTarget, isDirectory: true).standardizedFileURL
        }

        let currentDirectoryURL = (currentDirectoryURL ?? URL(
            fileURLWithPath: repository.fileManager.currentDirectoryPath,
            isDirectory: true
        )).resolvingSymlinksInPath().standardizedFileURL
        let assetRootURL = repository.assetRootURL.resolvingSymlinksInPath().standardizedFileURL
        let assetPrefix = assetRootURL.path.hasSuffix("/") ? assetRootURL.path : assetRootURL.path + "/"

        if repository.isStarterCheckout,
           (currentDirectoryURL.path == assetRootURL.path || currentDirectoryURL.path.hasPrefix(assetPrefix)) {
            throw SwiftNestError(SwiftNestLocalizer.text(.installStarterCheckoutRequiresTarget))
        }

        if let managedRepository = SwiftNestRepository.findManagedRepository(
            assetRootURL: assetRootURL,
            currentDirectoryPath: currentDirectoryURL.path
        ) {
            return managedRepository.rootURL
        }

        guard standardInputIsTTY() else {
            throw SwiftNestError(SwiftNestLocalizer.text(.installRequiresTarget))
        }

        let gitRootURL = SwiftNestRepository.findGitRepositoryRoot(
            currentDirectoryURL: currentDirectoryURL,
            fileManager: repository.fileManager
        )
        let implicitTargetURL = gitRootURL ?? currentDirectoryURL
        try confirmImplicitTarget(
            commandName: "install",
            targetURL: implicitTargetURL,
            currentDirectoryURL: currentDirectoryURL,
            gitRepositoryRootURL: gitRootURL,
            lineReader: lineReader
        )
        return implicitTargetURL
    }

    static func confirmImplicitTarget(
        commandName: String,
        targetURL: URL,
        currentDirectoryURL: URL,
        gitRepositoryRootURL: URL?,
        lineReader: () -> String? = {
            readLine()
        }
    ) throws {
        print(SwiftNestLocalizer.text(.implicitTargetConfirmationHeader, commandName))
        print(SwiftNestLocalizer.text(.implicitTargetConfirmationTarget, targetURL.path))
        if let gitRepositoryRootURL {
            print(SwiftNestLocalizer.text(.implicitTargetConfirmationGitDetected, gitRepositoryRootURL.path))
        } else {
            print(SwiftNestLocalizer.text(.implicitTargetConfirmationNoGit, currentDirectoryURL.path))
        }

        while true {
            print(SwiftNestLocalizer.text(.implicitTargetConfirmationPrompt), terminator: "")
            let raw = lineReader()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if raw.isEmpty || ["n", "no", "아니오", "아니요"].contains(raw) {
                throw SwiftNestError(SwiftNestLocalizer.text(.operationCancelled))
            }
            if ["y", "yes", "예", "네"].contains(raw) {
                return
            }
            print(SwiftNestLocalizer.text(.onboardingPromptBooleanRetry))
        }
    }

    static func runInit(parsed: ParsedArguments, repository: SwiftNestRepository) throws {
        guard parsed.positionals.isEmpty else {
            throw SwiftNestError(
                SwiftNestLocalizer.text(.unexpectedPositionalsInit, parsed.positionals.joined(separator: " "))
            )
        }

        guard let configValue = parsed.value(for: "--config"), !configValue.isEmpty else {
            throw SwiftNestError(SwiftNestLocalizer.text(.initRequiresConfig))
        }

        let configURL = URL(fileURLWithPath: configValue, relativeTo: repository.rootURL).standardizedFileURL
        let config = try HarnessDocumentLoader.loadObject(at: configURL)
        let interactive = shouldRunInteractively(parsed: parsed)

        let profileName = try resolveOnboardingProfile(parsed: parsed, repository: repository, interactive: interactive)
        let profile = try HarnessDocumentLoader.loadObject(at: repository.profileURL(named: profileName))
        let defaultSkills = HarnessDocumentLoader.stringArray(profile, key: "default_skills")
        let defaultWorkflows = defaultWorkflowsForInit(repository: repository)
        let skills = try resolveOnboardingSkills(
            parsed: parsed,
            defaultSkills: defaultSkills,
            repository: repository,
            interactive: interactive
        )
        let workflows = try resolveWorkflowSelection(
            parsed: parsed,
            interactive: interactive,
            repository: repository,
            defaultWorkflows: defaultWorkflows
        )
        let state = try initializeHarness(
            config: config,
            configURL: configURL,
            profileName: profileName,
            skills: skills,
            workflows: workflows,
            skillAgent: try resolveSkillAgentSelection(
                parsed: parsed,
                interactive: interactive,
                defaultSkillAgent: storedSkillAgentSelection(repository: repository)
            ),
            repository: repository
        )

        print(SwiftNestLocalizer.text(.initializedSwiftNest, profileName, skills.joined(separator: ", ")))
        print(SwiftNestLocalizer.text(.renderedContext, repository.resolveStatePath(state.contextPath).path))
    }

    static func runUpgrade(parsed: ParsedArguments, repository: SwiftNestRepository) throws {
        guard parsed.positionals.isEmpty else {
            throw SwiftNestError(
                SwiftNestLocalizer.text(.unexpectedPositionalsUpgrade, parsed.positionals.joined(separator: " "))
            )
        }

        guard let targetProfile = parsed.value(for: "--to"), !targetProfile.isEmpty else {
            throw SwiftNestError(SwiftNestLocalizer.text(.upgradeRequiresProfile))
        }

        var (state, config) = try currentStateAndConfig(repository: repository)
        let profile = try HarnessDocumentLoader.loadObject(at: repository.profileURL(named: targetProfile))
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
        state.skillAgent = normalizedSkillAgentRawValue(state.skillAgent)
        state.contextPath = repository.serializeStatePath(contextURL)
        state.dataVersion = currentDataVersion
        try repository.saveState(state)
        try syncAgentSkillEnvironment(skillAgent: state.skillAgent, skills: mergedSkills, repository: repository)
        try writeSelectedConfigurationFiles(profileName: targetProfile, skills: mergedSkills, skillAgent: state.skillAgent, repository: repository)

        print(SwiftNestLocalizer.text(.upgradedSwiftNest, targetProfile))
        print(SwiftNestLocalizer.text(.currentSkills, mergedSkills.joined(separator: ", ")))
    }

    static func runRenderContext(repository: SwiftNestRepository) throws {
        let (state, _) = try currentStateAndConfig(repository: repository)
        let workflows = normalizedWorkflowNames(state.workflows)
        let contextURL = try renderContextBundle(
            profileName: state.profile,
            skills: state.skills,
            workflows: workflows,
            repository: repository
        )
        print(contextURL.path)
    }

    static func runListSkills(repository: SwiftNestRepository) throws {
        for skill in try repository.availableSkills() {
            print(skill)
        }
    }

    static func runListProfiles(repository: SwiftNestRepository) throws {
        for summary in try listProfileSummaries(repository: repository) {
            print(summary)
        }
    }

    static func listProfileSummaries(
        repository: SwiftNestRepository,
        language: SwiftNestLanguage = SwiftNestLocalizer.activeLanguage
    ) throws -> [String] {
        try repository.availableProfiles().map { profileURL in
            let data = try HarnessDocumentLoader.loadObject(at: profileURL)
            let description = localizedProfileDescription(from: data, language: language)
            return "\(profileURL.deletingPathExtension().lastPathComponent): \(description)"
        }
    }

    static func localizedProfileDescription(
        from values: [String: Any],
        language: SwiftNestLanguage = SwiftNestLocalizer.activeLanguage
    ) -> String {
        switch language {
        case .ko:
            let koreanDescription = HarnessDocumentLoader.string(values, key: "description_ko", default: "")
            if !koreanDescription.isEmpty {
                return koreanDescription
            }
            return HarnessDocumentLoader.string(values, key: "description", default: "")
        case .en:
            return HarnessDocumentLoader.string(values, key: "description", default: "")
        }
    }

    static func runWorkflow(arguments: [String], repository: SwiftNestRepository) throws {
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
            throw SwiftNestError(SwiftNestLocalizer.text(.unknownWorkflowSubcommand, subcommand))
        }
    }

    static func runWorkflowList(repository: SwiftNestRepository) throws {
        let enabled = try currentWorkflowSet(repository: repository)
        for definition in availableWorkflowDefinitions(repository: repository) {
            let kind = definition.isDefault
                ? SwiftNestLocalizer.text(.workflowKindDefault)
                : SwiftNestLocalizer.text(.workflowKindOptional)
            let status = enabled.contains(definition.name)
                ? SwiftNestLocalizer.text(.workflowStatusEnabled)
                : SwiftNestLocalizer.text(.workflowStatusAvailable)
            print("\(definition.name) [\(kind), \(status)]: \(definition.runtimeDescription())")
        }
    }

    static func runWorkflowPrint(parsed: ParsedArguments, repository: SwiftNestRepository) throws {
        guard parsed.positionals.count == 1 else {
            throw SwiftNestError(SwiftNestLocalizer.text(.workflowPrintRequiresOneName))
        }

        let name = parsed.positionals[0]
        guard workflowTemplateExists(named: name, repository: repository) else {
            throw SwiftNestError(SwiftNestLocalizer.text(.unknownWorkflow, name))
        }
        let (state, config) = try currentStateAndConfig(repository: repository)
        let content = try renderWorkflow(
            named: name,
            config: config,
            profileName: state.profile,
            skills: state.skills,
            workflows: currentWorkflowSet(from: state, extraNames: [], repository: repository),
            repository: repository
        )
        print(content)
    }

    static func runWorkflowScaffold(parsed: ParsedArguments, repository: SwiftNestRepository) throws {
        let (state, config) = try currentStateAndConfig(repository: repository)
        let workflows = try currentWorkflowSet(from: state, extraNames: parsed.positionals, repository: repository)
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
        try syncAgentSkillEnvironment(skillAgent: updatedState.skillAgent, skills: updatedState.skills, repository: repository)

        print(SwiftNestLocalizer.text(.scaffoldedWorkflows, renderedWorkflows.joined(separator: ", ")))
    }

    static func currentStateAndConfig(repository: SwiftNestRepository) throws -> (SwiftNestState, [String: Any]) {
        try migrateRepositoryStateIfNeeded(repository: repository)
        let state = try repository.loadState()
        let configURL = repository.resolveStatePath(state.configPath)
        guard repository.fileManager.fileExists(atPath: configURL.path) else {
            throw SwiftNestError(SwiftNestLocalizer.text(.configPathNotFound, configURL.path))
        }
        let config = try HarnessDocumentLoader.loadObject(at: configURL)
        return (state, config)
    }

    static func writeSelectedConfigurationFiles(
        profileName: String,
        skills: [String],
        skillAgent: String?,
        repository: SwiftNestRepository
    ) throws {
        try repository.fileManager.createDirectory(at: repository.stateDirectoryURL, withIntermediateDirectories: true)
        let selectedProfileURL = repository.stateDirectoryURL.appendingPathComponent("selected_profile.yaml")
        let selectedSkillsURL = repository.stateDirectoryURL.appendingPathComponent("selected_skills.txt")
        let profileText = try String(contentsOf: try repository.profileURL(named: profileName), encoding: .utf8)
        try profileText.write(to: selectedProfileURL, atomically: true, encoding: .utf8)
        try (skills.joined(separator: "\n") + "\n").write(to: selectedSkillsURL, atomically: true, encoding: .utf8)
        try selectedSkillAgentLabel(for: skillAgent).appending("\n").write(
            to: repository.selectedSkillAgentURL,
            atomically: true,
            encoding: .utf8
        )
    }

    static func migrateRepositoryStateIfNeeded(repository: SwiftNestRepository) throws {
        guard repository.fileManager.fileExists(atPath: repository.stateFileURL.path) else {
            return
        }

        var state = try repository.loadState()
        guard state.dataVersion <= currentDataVersion else {
            throw SwiftNestError(
                SwiftNestLocalizer.text(.stateDataVersionTooNew, state.dataVersion, currentDataVersion)
            )
        }

        guard state.dataVersion < currentDataVersion else {
            return
        }

        let configURL = repository.resolveStatePath(state.configPath)
        guard repository.fileManager.fileExists(atPath: configURL.path) else {
            throw SwiftNestError(SwiftNestLocalizer.text(.configPathNotFound, configURL.path))
        }

        let config = try HarnessDocumentLoader.loadObject(at: configURL)
        let skills = state.skills.sorted()
        _ = try installManagedFiles(into: repository.rootURL, force: true, dryRun: false, repository: repository)
        let context = mergedContext(
            base: try normalizeContext(config: config, profileName: state.profile),
            extra: workflowContext(config: config, skills: skills, workflows: state.workflows)
        )
        try writeDocs(context: context, skills: skills, profileName: state.profile, repository: repository)
        let renderedWorkflows = try scaffoldWorkflowFiles(
            config: config,
            profileName: state.profile,
            skills: skills,
            workflows: state.workflows,
            repository: repository
        )
        try writeAgentsFile(
            config: config,
            profileName: state.profile,
            skills: skills,
            workflows: renderedWorkflows,
            repository: repository
        )
        let contextURL = try renderContextBundle(
            profileName: state.profile,
            skills: skills,
            workflows: renderedWorkflows,
            repository: repository
        )
        state.skills = skills
        state.workflows = renderedWorkflows
        state.skillAgent = normalizedSkillAgentRawValue(state.skillAgent)
        state.contextPath = repository.serializeStatePath(contextURL)
        state.dataVersion = currentDataVersion
        try repository.saveState(state)
        try syncAgentSkillEnvironment(skillAgent: state.skillAgent, skills: skills, repository: repository)
        try writeSelectedConfigurationFiles(profileName: state.profile, skills: skills, skillAgent: state.skillAgent, repository: repository)
    }

    static func currentWorkflowSet(repository: SwiftNestRepository) throws -> [String] {
        let availableNames = availableWorkflowNames(repository: repository)
        try migrateRepositoryStateIfNeeded(repository: repository)
        guard repository.fileManager.fileExists(atPath: repository.stateFileURL.path) else {
            return defaultWorkflowNames.filter { availableNames.contains($0) }
        }
        let state = try repository.loadState()
        return normalizedWorkflowNames(state.workflows).filter { availableNames.contains($0) }
    }

    static func currentWorkflowSet(
        from state: SwiftNestState,
        extraNames: [String],
        repository: SwiftNestRepository
    ) throws -> [String] {
        let availableNames = availableWorkflowNames(repository: repository)
        let base = Set(normalizedWorkflowNames(state.workflows).filter { availableNames.contains($0) })
        let extras = try validateWorkflowNames(extraNames, repository: repository)
        let merged = base.union(extras)
        return availableWorkflowDefinitions(repository: repository).map(\.name).filter { merged.contains($0) }
    }

    static func validateWorkflowNames(_ names: [String], repository: SwiftNestRepository? = nil) throws -> Set<String> {
        var valid: Set<String> = []
        for name in names {
            guard workflowDefinitions[name] != nil else {
                throw SwiftNestError(SwiftNestLocalizer.text(.unknownWorkflow, name))
            }
            if let repository, !workflowTemplateExists(named: name, repository: repository) {
                throw SwiftNestError(SwiftNestLocalizer.text(.unknownWorkflow, name))
            }
            valid.insert(name)
        }
        return valid
    }

    static func defaultWorkflowsForInit(repository: SwiftNestRepository) -> [String] {
        defaultWorkflowNames.filter { workflowTemplateExists(named: $0, repository: repository) }
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
                    throw SwiftNestError(SwiftNestLocalizer.text(.missingValueForOption, arg))
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
                throw SwiftNestError(SwiftNestLocalizer.text(.unknownOption, arg))
            }
            positionals.append(arg)
            index += 1
        }

        return ParsedArguments(values: values, flags: flags, positionals: positionals)
    }

    static func normalizeContext(config: [String: Any], profileName: String) throws -> [String: String] {
        guard let profileGuidance = profileGuidance[profileName], let workflowGuidance = workflowGuidance[profileName] else {
            throw SwiftNestError(SwiftNestLocalizer.text(.unknownProfile, profileName))
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

    static func onboardingPreservableSkillNames(repository: SwiftNestRepository) throws -> Set<String> {
        Set(try repository.availableSkills()).union(try repoLocalCustomSkillNames(repository: repository))
    }

    static func repoLocalCustomSkillNames(repository: SwiftNestRepository) throws -> Set<String> {
        let fileManager = repository.fileManager
        let skillsURL = repository.rootURL.appendingPathComponent("Docs/AI_SKILLS", isDirectory: true)
        guard fileManager.fileExists(atPath: skillsURL.path) else {
            return []
        }

        let items = try fileManager.contentsOfDirectory(at: skillsURL, includingPropertiesForKeys: nil)
        let existingSkillNames = Set(
            items
                .filter { $0.pathExtension == "md" }
                .map { $0.deletingPathExtension().lastPathComponent }
        )
        let manifestURL = skillsURL.appendingPathComponent(".generated_manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return []
        }

        return existingSkillNames.subtracting(try generatedSkillNames(manifestURL: manifestURL))
    }

    static func generatedSkillNames(manifestURL: URL) throws -> Set<String> {
        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(SwiftNestGeneratedManifest.self, from: data)
        return Set(
            manifest.files
                .filter { ($0 as NSString).pathExtension == "md" }
                .map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
        )
    }

    static func writeDocs(context: [String: String], skills: [String], profileName: String, repository: SwiftNestRepository) throws {
        let fileManager = repository.fileManager
        let docsURL = repository.rootURL.appendingPathComponent("Docs", isDirectory: true)
        let skillsURL = docsURL.appendingPathComponent("AI_SKILLS", isDirectory: true)
        let manifestURL = skillsURL.appendingPathComponent(".generated_manifest.json")
        try fileManager.createDirectory(at: docsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: skillsURL, withIntermediateDirectories: true)

        for relativePath in ["Docs/AI_RULES.md", "Docs/AI_WORKFLOWS.md", "Docs/AI_PROMPT_ENTRY.md"] {
            let sourceURL = repository.templatesURL.appendingPathComponent(relativePath)
            let destinationURL = repository.rootURL.appendingPathComponent(relativePath)
            let template = try String(contentsOf: sourceURL, encoding: .utf8)
            try renderString(template, context: context).write(to: destinationURL, atomically: true, encoding: .utf8)
        }

        try cleanupGeneratedSkillFilesIfNeeded(skillsURL: skillsURL, fileManager: fileManager)

        let repoLocalCustomSkills = try repoLocalCustomSkillNames(repository: repository)
        var generatedFiles: [String] = []
        for skill in skills {
            let sourceURL = repository.templatesURL.appendingPathComponent("Docs/AI_SKILLS/\(skill).md")
            let destinationURL = skillsURL.appendingPathComponent(sourceURL.lastPathComponent)
            if !fileManager.fileExists(atPath: sourceURL.path) {
                guard repoLocalCustomSkills.contains(skill) else {
                    throw SwiftNestError(SwiftNestLocalizer.text(.unknownSkillTemplate, skill))
                }
                continue
            }
            let template = try String(contentsOf: sourceURL, encoding: .utf8)
            try renderString(template, context: context).write(to: destinationURL, atomically: true, encoding: .utf8)
            generatedFiles.append(sourceURL.lastPathComponent)
        }

        let manifest = SwiftNestGeneratedManifest(files: generatedFiles, profile: profileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: manifestURL)
    }

    static func cleanupGeneratedSkillFilesIfNeeded(
        skillsURL: URL,
        fileManager: FileManager
    ) throws {
        let manifestURL = skillsURL.appendingPathComponent(".generated_manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return
        }

        for fileName in try generatedSkillNames(manifestURL: manifestURL).map({ "\($0).md" }) {
            let generatedURL = skillsURL.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: generatedURL.path) {
                try fileManager.removeItem(at: generatedURL)
            }
        }
    }

    static func normalizedSkillAgentRawValue(_ rawValue: String?) -> String? {
        SwiftNestSkillAgent.resolved(from: rawValue)?.rawValue
    }

    static func selectedSkillAgentLabel(for rawValue: String?) -> String {
        normalizedSkillAgentRawValue(rawValue) ?? SwiftNestSkillAgent.noneOption
    }

    static func syncAgentSkillEnvironment(
        skillAgent rawSkillAgent: String?,
        skills: [String],
        repository: SwiftNestRepository
    ) throws {
        switch SwiftNestSkillAgent.resolved(from: rawSkillAgent) {
        case .codex:
            try syncCodexSkillEnvironment(skills: skills, repository: repository)
        case nil:
            try cleanupCodexSkillEnvironment(repository: repository)
        }
    }

    static func syncCodexSkillEnvironment(
        skills: [String],
        repository: SwiftNestRepository
    ) throws {
        try cleanupCodexSkillEnvironment(repository: repository)

        let fileManager = repository.fileManager
        let resourceRootURL = repository.resourcesURL.appendingPathComponent("agents/codex/skills", isDirectory: true)
        try fileManager.createDirectory(at: repository.agentSkillsDirectoryURL, withIntermediateDirectories: true)
        let repoLocalCustomSkills = try repoLocalCustomSkillNames(repository: repository)

        var installedDirectories: [String] = []
        for skill in skills.sorted() {
            let slug = "swiftnest-\(skill)"
            let templateURL = resourceRootURL.appendingPathComponent("\(skill)/SKILL.md")
            let destinationDirectoryURL = repository.agentSkillsDirectoryURL.appendingPathComponent(slug, isDirectory: true)
            if !fileManager.fileExists(atPath: templateURL.path) {
                if repoLocalCustomSkills.contains(skill),
                   fileManager.fileExists(atPath: destinationDirectoryURL.appendingPathComponent("SKILL.md").path),
                   try !isSwiftNestGeneratedCodexSkillDirectory(destinationDirectoryURL, fileManager: fileManager)
                {
                    continue
                }
                throw SwiftNestError(SwiftNestLocalizer.text(.unknownAgentSkillResource, skill, SwiftNestSkillAgent.codex.rawValue))
            }

            let skillContentURL = repository.rootURL.appendingPathComponent("Docs/AI_SKILLS/\(skill).md")
            guard fileManager.fileExists(atPath: skillContentURL.path) else {
                throw SwiftNestError(SwiftNestLocalizer.text(.unknownSkillTemplate, skill))
            }

            let template = try String(contentsOf: templateURL, encoding: .utf8)
            let skillContent = try String(contentsOf: skillContentURL, encoding: .utf8)
            let context = [
                "SWIFTNEST_AGENT_SKILL_NAME": slug,
                "SWIFTNEST_AGENT_SKILL_DESCRIPTION": escapedFrontMatterValue(skillSummary(named: skill, repository: repository)),
                "SWIFTNEST_AGENT_SKILL_CONTENT": skillContent,
                "SWIFTNEST_SOURCE_SKILL_FILE": "\(skill).md",
            ]
            let rendered = renderString(template, context: context)
            try fileManager.createDirectory(at: destinationDirectoryURL, withIntermediateDirectories: true)
            try rendered.write(
                to: destinationDirectoryURL.appendingPathComponent("SKILL.md"),
                atomically: true,
                encoding: .utf8
            )
            installedDirectories.append(slug)
        }

        try fileManager.createDirectory(at: repository.agentSkillStateDirectoryURL, withIntermediateDirectories: true)
        let manifest = SwiftNestAgentSkillManifest(agent: SwiftNestSkillAgent.codex.rawValue, installedDirectories: installedDirectories)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(
            to: repository.agentSkillStateDirectoryURL.appendingPathComponent("codex_manifest.json"),
            options: .atomic
        )
    }

    static func cleanupCodexSkillEnvironment(repository: SwiftNestRepository) throws {
        let fileManager = repository.fileManager
        let manifestURL = repository.agentSkillStateDirectoryURL.appendingPathComponent("codex_manifest.json")

        if fileManager.fileExists(atPath: manifestURL.path) {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(SwiftNestAgentSkillManifest.self, from: data)
            for directoryName in manifest.installedDirectories {
                let directoryURL = repository.agentSkillsDirectoryURL.appendingPathComponent(directoryName, isDirectory: true)
                if fileManager.fileExists(atPath: directoryURL.path) {
                    try fileManager.removeItem(at: directoryURL)
                }
            }
            try fileManager.removeItem(at: manifestURL)
        } else if fileManager.fileExists(atPath: repository.agentSkillsDirectoryURL.path) {
            let contents = try fileManager.contentsOfDirectory(
                at: repository.agentSkillsDirectoryURL,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
            for item in contents where item.lastPathComponent.hasPrefix("swiftnest-") {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDir),
                   isDir.boolValue,
                   try isSwiftNestGeneratedCodexSkillDirectory(item, fileManager: fileManager)
                {
                    try fileManager.removeItem(at: item)
                }
            }
        }

        try removeDirectoryIfEmpty(repository.agentSkillStateDirectoryURL, fileManager: fileManager)
        try removeDirectoryIfEmpty(repository.agentSkillsDirectoryURL, fileManager: fileManager)
        try removeDirectoryIfEmpty(repository.agentsDirectoryURL, fileManager: fileManager)
    }

    static func isSwiftNestGeneratedCodexSkillDirectory(
        _ directoryURL: URL,
        fileManager: FileManager
    ) throws -> Bool {
        let skillURL = directoryURL.appendingPathComponent("SKILL.md")
        guard fileManager.fileExists(atPath: skillURL.path) else {
            return false
        }

        let contents = try String(contentsOf: skillURL, encoding: .utf8)
        return contents.contains(codexGeneratedSkillMarker)
    }

    static func removeDirectoryIfEmpty(_ directoryURL: URL, fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }

        let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
        if contents.isEmpty {
            try fileManager.removeItem(at: directoryURL)
        }
    }

    static func escapedFrontMatterValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func renderContextBundle(
        profileName: String,
        skills: [String],
        workflows: [String],
        repository: SwiftNestRepository
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

    static func chooseProfileInteractively(
        repository: SwiftNestRepository,
        defaultProfileName: String = defaultOnboardingProfileName
    ) throws -> String {
        let profiles = try repository.availableProfiles().map { profileURL -> (String, String) in
            let data = try HarnessDocumentLoader.loadObject(at: profileURL)
            return (profileURL.deletingPathExtension().lastPathComponent, localizedProfileDescription(from: data))
        }
        print(SwiftNestLocalizer.text(.profilesHeader))
        for (index, profile) in profiles.enumerated() {
            print("  \(index + 1). \(profile.0) — \(profile.1)")
        }
        let defaultNumber = profiles.firstIndex { $0.0 == defaultProfileName }.map { String($0 + 1) } ?? "1"
        print(SwiftNestLocalizer.text(.chooseProfileNumberPrompt, defaultNumber), terminator: "")
        let raw = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let chosen = raw.isEmpty ? defaultNumber : raw
        guard let number = Int(chosen), profiles.indices.contains(number - 1) else {
            throw SwiftNestError(SwiftNestLocalizer.text(.profileChoiceOutOfRange))
        }
        return profiles[number - 1].0
    }

    static func chooseSkillsInteractively(defaultSkills: [String], repository: SwiftNestRepository) throws -> [String] {
        let skills = try repository.availableSkills()
        print(SwiftNestLocalizer.text(.availableSkillsHeader))
        for (index, skill) in skills.enumerated() {
            let mark = defaultSkills.contains(skill) ? "*" : " "
            let summary = skillSummary(named: skill, repository: repository)
            print(String(format: "  %2d. [%@] %@ — %@", index + 1, mark, skill, summary))
        }
        print(SwiftNestLocalizer.text(.selectSkillsPrompt), terminator: "")
        let raw = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty {
            return defaultSkills.sorted()
        }

        var chosen: [String] = []
        for token in raw.split(separator: ",") {
            let trimmed = token.trimmingCharacters(in: .whitespaces)
            guard let number = Int(trimmed) else {
                throw SwiftNestError(SwiftNestLocalizer.text(.invalidSelection, trimmed))
            }
            guard skills.indices.contains(number - 1) else {
                throw SwiftNestError(SwiftNestLocalizer.text(.selectionOutOfRange, trimmed))
            }
            chosen.append(skills[number - 1])
        }
        return Array(Set(chosen)).sorted()
    }

    static func installManagedFiles(into targetURL: URL, force: Bool, dryRun: Bool, repository: SwiftNestRepository) throws -> (copied: Int, unchanged: Int) {
        let fileManager = repository.fileManager
        var copied = 0
        var unchanged = 0
        var conflicts: [String] = []
        var pendingCopies: [(sourceURL: URL, destinationURL: URL, relativePath: String, overwritesExisting: Bool)] = []

        for (sourceURL, relativePath) in try iterManagedFiles(repository: repository) {
            let destinationURL = targetURL.appendingPathComponent(relativePath)
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: destinationURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                throw SwiftNestError(SwiftNestLocalizer.text(.expectedFileButFoundDirectory, relativePath))
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

            pendingCopies.append(
                (
                    sourceURL: sourceURL,
                    destinationURL: destinationURL,
                    relativePath: relativePath,
                    overwritesExisting: fileManager.fileExists(atPath: destinationURL.path)
                )
            )
        }

        if !conflicts.isEmpty {
            let joined = conflicts.map { "- \($0)" }.joined(separator: "\n")
            throw SwiftNestError(SwiftNestLocalizer.text(.refusingOverwriteManagedFiles, joined))
        }

        for operation in pendingCopies {
            if dryRun {
                let actionMessage = operation.overwritesExisting
                    ? SwiftNestLocalizer.text(.dryRunOverwrite, operation.relativePath)
                    : SwiftNestLocalizer.text(.dryRunCopy, operation.relativePath)
                print(actionMessage)
                copied += 1
                continue
            }

            try fileManager.createDirectory(
                at: operation.destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if operation.overwritesExisting {
                try fileManager.removeItem(at: operation.destinationURL)
            }
            try fileManager.copyItem(at: operation.sourceURL, to: operation.destinationURL)
            copied += 1
        }

        return (copied, unchanged)
    }

    static func iterManagedFiles(repository: SwiftNestRepository) throws -> [(URL, String)] {
        var files: [(URL, String)] = []
        let resolvedRootURL = repository.assetRootURL.resolvingSymlinksInPath().standardizedFileURL

        for relativePath in SwiftNestRepository.managedPaths {
            let sourceURL = repository.assetRootURL.appendingPathComponent(relativePath)
            var isDirectory: ObjCBool = false
            guard repository.fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else {
                throw SwiftNestError(SwiftNestLocalizer.text(.managedPathMissingFromStarter, relativePath))
            }
            if isDirectory.boolValue {
                let enumerator = repository.fileManager.enumerator(
                    at: sourceURL.resolvingSymlinksInPath(),
                    includingPropertiesForKeys: [.isRegularFileKey]
                )
                while let fileURL = enumerator?.nextObject() as? URL {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                    if resourceValues.isRegularFile == true {
                        let relativeURL = try relativeManagedPath(for: fileURL, relativeTo: resolvedRootURL)
                        files.append((fileURL, relativeURL))
                    }
                }
            } else {
                files.append((sourceURL, relativePath))
            }
        }
        return files.sorted { $0.1 < $1.1 }
    }

    static func relativeManagedPath(for fileURL: URL, relativeTo rootURL: URL) throws -> String {
        let resolvedFileURL = fileURL.resolvingSymlinksInPath().standardizedFileURL
        let resolvedRootURL = rootURL.resolvingSymlinksInPath().standardizedFileURL
        let rootPath = resolvedRootURL.path.hasSuffix("/") ? resolvedRootURL.path : resolvedRootURL.path + "/"
        let filePath = resolvedFileURL.path

        guard filePath.hasPrefix(rootPath) else {
            throw SwiftNestError(SwiftNestLocalizer.text(.managedPathEscapedRepositoryRoot, fileURL.path))
        }

        return String(filePath.dropFirst(rootPath.count))
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
                if line == ".swiftnest" || line == ".swiftnest/" {
                    print(SwiftNestLocalizer.text(.warningGitignoreIgnoresAIHarness))
                    break
                }
            }
            for rawLine in gitignoreText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line == ".agents" || line == ".agents/" || line == ".agents/skills" || line == ".agents/skills/" {
                    print(SwiftNestLocalizer.text(.warningGitignoreIgnoresAgentSkills))
                    break
                }
            }
        }

        if fileManager.fileExists(atPath: targetURL.appendingPathComponent("Docs").path) {
            print(SwiftNestLocalizer.text(.warningDocsAlreadyExists))
        }
        if fileManager.fileExists(atPath: targetURL.appendingPathComponent(".swiftnest").path) {
            print(SwiftNestLocalizer.text(.warningAIHarnessAlreadyExists))
        }
    }

    static func printTopLevelUsage() {
        print(SwiftNestLocalizer.text(.usageTopLevel))
    }

    static func printInstallUsage() {
        print(SwiftNestLocalizer.text(.usageInstall))
    }

    static func printOnboardUsage() {
        print(SwiftNestLocalizer.text(.usageOnboard))
    }

    static func printInitUsage() {
        print(SwiftNestLocalizer.text(.usageInit))
    }

    static func printUpgradeUsage() {
        print(SwiftNestLocalizer.text(.usageUpgrade))
    }

    static func printWorkflowUsage() {
        print(SwiftNestLocalizer.text(.usageWorkflow))
    }

    static func printWorkflowListUsage() {
        print(SwiftNestLocalizer.text(.usageWorkflowList))
    }

    static func printWorkflowPrintUsage() {
        print(SwiftNestLocalizer.text(.usageWorkflowPrint))
    }

    static func printWorkflowScaffoldUsage() {
        print(SwiftNestLocalizer.text(.usageWorkflowScaffold))
    }

    static func printRenderContextUsage() {
        print(SwiftNestLocalizer.text(.usageRenderContext))
    }

    static func printListSkillsUsage() {
        print(SwiftNestLocalizer.text(.usageListSkills))
    }

    static func printListProfilesUsage() {
        print(SwiftNestLocalizer.text(.usageListProfiles))
    }
}
