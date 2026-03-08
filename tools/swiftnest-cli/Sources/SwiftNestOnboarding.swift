import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct SwiftNestOnboardingConfigDraft {
    var projectName: String
    var includesWatchCompanion: Bool
    var uiFramework: String
    var architectureStyle: String
    var minIOSVersion: String
    var packageManager: String
    var testFramework: String
    var lintTools: String
    var networkLayerName: String
    var persistenceLayerName: String
    var loggingSystem: String
    var privacyRequirements: String
    var preferredFileLineLimit: String
    var healthKitLayerName: String
    var buildCommand: String
    var testCommand: String

    func asDictionary() -> [String: String] {
        [
            "project_name": projectName,
            "optional_watchos_line": includesWatchCompanion ? "/ watchOS companion app enabled" : "",
            "ui_framework": uiFramework,
            "architecture_style": architectureStyle,
            "min_ios_version": minIOSVersion,
            "package_manager": packageManager,
            "test_framework": testFramework,
            "lint_tools": lintTools,
            "network_layer_name": networkLayerName,
            "persistence_layer_name": persistenceLayerName,
            "logging_system": loggingSystem,
            "privacy_requirements": privacyRequirements,
            "preferred_file_line_limit": preferredFileLineLimit,
            "healthkit_layer_name": healthKitLayerName,
            "build_command": buildCommand,
            "test_command": testCommand,
        ]
    }
}

struct SwiftNestOnboardingStatus {
    let starterRootURL: URL
    let targetRootURL: URL
    let targetAlreadyManaged: Bool
    let configURL: URL
    let configExists: Bool
    let stateExists: Bool

    var installsIntoDifferentRepository: Bool {
        starterRootURL.standardizedFileURL.path != targetRootURL.standardizedFileURL.path
    }
}

extension SwiftNestCLI {
    static let defaultOnboardingProfileName = "intermediate"

    static func runOnboard(parsed: ParsedArguments, repository: SwiftNestRepository) throws {
        guard parsed.positionals.isEmpty else {
            throw SwiftNestError(
                SwiftNestLocalizer.text(.unexpectedPositionalsOnboard, parsed.positionals.joined(separator: " "))
            )
        }

        let currentDirectoryURL = URL(
            fileURLWithPath: repository.fileManager.currentDirectoryPath,
            isDirectory: true
        ).resolvingSymlinksInPath().standardizedFileURL
        let targetURL = try resolveOnboardingTargetURL(
            parsed: parsed,
            repository: repository,
            currentDirectoryURL: currentDirectoryURL
        )
        let configURL = resolveOnboardingConfigURL(parsed.value(for: "--config"), targetRootURL: targetURL)
        var status = onboardingStatus(starterRepository: repository, targetRootURL: targetURL, configURL: configURL)
        let interactive = shouldRunInteractively(parsed: parsed)

        print(SwiftNestLocalizer.text(.onboardingStarted, status.targetRootURL.path))
        print(SwiftNestLocalizer.text(.onboardingStarterPath, status.starterRootURL.path))
        print(SwiftNestLocalizer.text(.onboardingTargetPath, status.targetRootURL.path))

        if !status.targetAlreadyManaged || parsed.contains("--force") {
            let installResult = try installManagedFiles(
                into: status.targetRootURL,
                force: parsed.contains("--force"),
                dryRun: false,
                repository: repository
            )
            printWarnings(for: status.targetRootURL, fileManager: repository.fileManager)
            print(SwiftNestLocalizer.text(.installedManagedFilesInto, status.targetRootURL.path))
            print(SwiftNestLocalizer.text(.changedFiles, installResult.copied))
            print(SwiftNestLocalizer.text(.unchangedFiles, installResult.unchanged))
            status = onboardingStatus(starterRepository: repository, targetRootURL: status.targetRootURL, configURL: configURL)
        } else {
            print(SwiftNestLocalizer.text(.onboardingManagedFilesReady, status.targetRootURL.path))
        }

        let targetRepository = SwiftNestRepository(rootURL: status.targetRootURL, assetRootURL: repository.assetRootURL)
        let configCreated = try ensureOnboardingConfig(
            at: status.configURL,
            repository: targetRepository,
            interactive: interactive,
            force: parsed.contains("--force")
        )

        if configCreated {
            print(SwiftNestLocalizer.text(.onboardingCreatedConfig, status.configURL.path))
        } else {
            print(SwiftNestLocalizer.text(.onboardingUsingExistingConfig, status.configURL.path))
        }

        let refreshedStatus = onboardingStatus(
            starterRepository: repository,
            targetRootURL: status.targetRootURL,
            configURL: status.configURL
        )
        if refreshedStatus.stateExists && !parsed.contains("--force") {
            let state = try targetRepository.loadState()
            printOnboardingAlreadyCompletedSummary(state: state, repository: targetRepository)
            return
        }

        let config = try HarnessDocumentLoader.loadObject(at: refreshedStatus.configURL)
        let profileName = try resolveOnboardingProfile(parsed: parsed, repository: targetRepository, interactive: interactive)
        let profile = try HarnessDocumentLoader.loadObject(at: targetRepository.profileURL(named: profileName))
        let defaultSkills = HarnessDocumentLoader.stringArray(profile, key: "default_skills")
        let skills = try resolveOnboardingSkills(
            parsed: parsed,
            defaultSkills: defaultSkills,
            repository: targetRepository,
            interactive: interactive
        )
        let workflows = try resolveWorkflowSelection(
            parsed: parsed,
            interactive: interactive,
            repository: targetRepository,
            defaultWorkflows: onboardingDefaultWorkflows(repository: targetRepository)
        )
        let skillAgent = try resolveSkillAgentSelection(parsed: parsed, interactive: interactive)

        let result = try initializeHarness(
            config: config,
            configURL: refreshedStatus.configURL,
            profileName: profileName,
            skills: skills,
            workflows: workflows,
            skillAgent: skillAgent,
            repository: targetRepository
        )

        printOnboardingCompletedSummary(result: result, repository: targetRepository, configURL: refreshedStatus.configURL)
    }

    static func initializeHarness(
        config: [String: Any],
        configURL: URL,
        profileName: String,
        skills: [String],
        workflows: [String],
        skillAgent: SwiftNestSkillAgent?,
        repository: SwiftNestRepository
    ) throws -> SwiftNestState {
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

        let normalizedSkillAgent = normalizedSkillAgentRawValue(skillAgent?.rawValue)
        try syncAgentSkillEnvironment(skillAgent: normalizedSkillAgent, skills: skills, repository: repository)
        try writeSelectedConfigurationFiles(
            profileName: profileName,
            skills: skills,
            skillAgent: normalizedSkillAgent,
            repository: repository
        )

        let state = SwiftNestState(
            dataVersion: currentDataVersion,
            profile: profileName,
            skills: skills,
            workflows: renderedWorkflows,
            skillAgent: normalizedSkillAgent,
            configPath: repository.serializeStatePath(configURL),
            contextPath: repository.serializeStatePath(contextURL)
        )
        try repository.saveState(state)
        return state
    }

    static func onboardingStatus(
        starterRepository: SwiftNestRepository,
        targetRootURL: URL,
        configURL: URL
    ) -> SwiftNestOnboardingStatus {
        let fileManager = starterRepository.fileManager
        let resolvedTargetRoot = targetRootURL.resolvingSymlinksInPath().standardizedFileURL
        return SwiftNestOnboardingStatus(
            starterRootURL: starterRepository.assetRootURL.resolvingSymlinksInPath().standardizedFileURL,
            targetRootURL: resolvedTargetRoot,
            targetAlreadyManaged: SwiftNestRepository.isRepositoryRoot(resolvedTargetRoot),
            configURL: configURL.resolvingSymlinksInPath().standardizedFileURL,
            configExists: fileManager.fileExists(atPath: configURL.path),
            stateExists: fileManager.fileExists(atPath: resolvedTargetRoot.appendingPathComponent(".swiftnest/state.json").path)
        )
    }

    static func resolveOnboardingTargetURL(
        parsed: ParsedArguments,
        repository: SwiftNestRepository,
        currentDirectoryURL: URL,
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

        let resolvedCurrentDirectoryURL = currentDirectoryURL.resolvingSymlinksInPath().standardizedFileURL
        let assetRootURL = repository.assetRootURL.resolvingSymlinksInPath().standardizedFileURL
        let assetPrefix = assetRootURL.path.hasSuffix("/") ? assetRootURL.path : assetRootURL.path + "/"

        if resolvedCurrentDirectoryURL.path == assetRootURL.path || resolvedCurrentDirectoryURL.path.hasPrefix(assetPrefix) {
            if repository.isStarterCheckout {
                throw SwiftNestError(SwiftNestLocalizer.text(.onboardingStarterCheckoutRequiresTarget))
            }
        }

        if let currentRepository = SwiftNestRepository.findManagedRepository(
            assetRootURL: assetRootURL,
            currentDirectoryPath: resolvedCurrentDirectoryURL.path
        ) {
            return currentRepository.rootURL
        }

        guard !parsed.contains("--non-interactive"), standardInputIsTTY() else {
            throw SwiftNestError(SwiftNestLocalizer.text(.onboardingRequiresTargetOutsideRepository))
        }

        let gitRootURL = SwiftNestRepository.findGitRepositoryRoot(
            currentDirectoryURL: resolvedCurrentDirectoryURL,
            fileManager: repository.fileManager
        )
        let implicitTargetURL = gitRootURL ?? resolvedCurrentDirectoryURL
        try confirmImplicitTarget(
            commandName: "onboard",
            targetURL: implicitTargetURL,
            currentDirectoryURL: resolvedCurrentDirectoryURL,
            gitRepositoryRootURL: gitRootURL,
            lineReader: lineReader
        )
        return implicitTargetURL
    }

    static func resolveOnboardingConfigURL(_ rawPath: String?, targetRootURL: URL) -> URL {
        let configPath: String
        if let rawPath, !rawPath.isEmpty {
            configPath = rawPath
        } else {
            configPath = "config/project.yaml"
        }
        return URL(fileURLWithPath: configPath, relativeTo: targetRootURL).standardizedFileURL
    }

    static func shouldRunInteractively(parsed: ParsedArguments) -> Bool {
        !parsed.contains("--non-interactive") && standardInputIsTTY()
    }

    static func standardInputIsTTY() -> Bool {
        isatty(fileno(stdin)) != 0
    }

    static func ensureOnboardingConfig(
        at configURL: URL,
        repository: SwiftNestRepository,
        interactive: Bool,
        force: Bool
    ) throws -> Bool {
        let fileManager = repository.fileManager
        if fileManager.fileExists(atPath: configURL.path), !force {
            return false
        }

        let defaults = inferredConfigDraft(for: repository.rootURL, fileManager: fileManager)
        let draft = interactive ? promptForConfigDraft(defaults: defaults) : defaults
        try fileManager.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let yaml = renderConfigYAML(from: draft)
        try yaml.write(to: configURL, atomically: true, encoding: .utf8)
        return true
    }

    static func inferredConfigDraft(for targetRootURL: URL, fileManager: FileManager) -> SwiftNestOnboardingConfigDraft {
        let repoName = inferredRepositoryName(for: targetRootURL, fileManager: fileManager)
        let inferredCommands = inferredBuildAndTestCommands(for: targetRootURL, fileManager: fileManager)

        return SwiftNestOnboardingConfigDraft(
            projectName: repoName,
            includesWatchCompanion: false,
            uiFramework: "SwiftUI",
            architectureStyle: "MVVM with Repository pattern",
            minIOSVersion: "iOS 17",
            packageManager: "Swift Package Manager",
            testFramework: "XCTest",
            lintTools: "SwiftLint, SwiftFormat",
            networkLayerName: "APIClient + RemoteRepository",
            persistenceLayerName: "LocalRepository",
            loggingSystem: "OSLog",
            privacyRequirements: "App Privacy disclosure and least-privilege data handling",
            preferredFileLineLimit: "300",
            healthKitLayerName: "HealthKitManager",
            buildCommand: inferredCommands.build,
            testCommand: inferredCommands.test
        )
    }

    static func inferredRepositoryName(for targetRootURL: URL, fileManager: FileManager) -> String {
        let candidates = inferredXcodeContainerNames(for: targetRootURL, fileManager: fileManager)
        if candidates.count == 1, let candidate = candidates.first {
            return candidate
        }
        let folderName = targetRootURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        return folderName.isEmpty ? "MyApp" : folderName
    }

    static func inferredBuildAndTestCommands(
        for targetRootURL: URL,
        fileManager: FileManager
    ) -> (build: String, test: String) {
        let topLevelItems = (try? fileManager.contentsOfDirectory(at: targetRootURL, includingPropertiesForKeys: nil)) ?? []
        let workspaces = topLevelItems.filter { $0.pathExtension == "xcworkspace" }
        let projects = topLevelItems.filter { $0.pathExtension == "xcodeproj" }
        let hasPackageManifest = fileManager.fileExists(atPath: targetRootURL.appendingPathComponent("Package.swift").path)

        if workspaces.count == 1, let workspace = workspaces.first {
            let workspaceName = workspace.lastPathComponent
            let scheme = workspace.deletingPathExtension().lastPathComponent
            return (
                "xcodebuild -workspace \(workspaceName) -scheme \(scheme) build",
                "xcodebuild -workspace \(workspaceName) -scheme \(scheme) test"
            )
        }

        if projects.count == 1, let project = projects.first {
            let scheme = project.deletingPathExtension().lastPathComponent
            return (
                "xcodebuild -scheme \(scheme) build",
                "xcodebuild -scheme \(scheme) test"
            )
        }

        if hasPackageManifest {
            return ("swift build", "swift test")
        }

        return ("", "")
    }

    static func inferredXcodeContainerNames(for targetRootURL: URL, fileManager: FileManager) -> [String] {
        let topLevelItems = (try? fileManager.contentsOfDirectory(at: targetRootURL, includingPropertiesForKeys: nil)) ?? []
        return topLevelItems
            .filter { $0.pathExtension == "xcworkspace" || $0.pathExtension == "xcodeproj" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    static func promptForConfigDraft(defaults: SwiftNestOnboardingConfigDraft) -> SwiftNestOnboardingConfigDraft {
        print(SwiftNestLocalizer.text(.onboardingConfigPromptHeader))
        return SwiftNestOnboardingConfigDraft(
            projectName: promptForTextValue(.onboardingPromptProjectName, defaultValue: defaults.projectName),
            includesWatchCompanion: promptForBooleanValue(.onboardingPromptWatchCompanion, defaultValue: defaults.includesWatchCompanion),
            uiFramework: promptForTextValue(.onboardingPromptUIFramework, defaultValue: defaults.uiFramework),
            architectureStyle: promptForTextValue(.onboardingPromptArchitectureStyle, defaultValue: defaults.architectureStyle),
            minIOSVersion: defaults.minIOSVersion,
            packageManager: defaults.packageManager,
            testFramework: defaults.testFramework,
            lintTools: defaults.lintTools,
            networkLayerName: promptForTextValue(.onboardingPromptNetworkLayerName, defaultValue: defaults.networkLayerName),
            persistenceLayerName: promptForTextValue(.onboardingPromptPersistenceLayerName, defaultValue: defaults.persistenceLayerName),
            loggingSystem: promptForTextValue(.onboardingPromptLoggingSystem, defaultValue: defaults.loggingSystem),
            privacyRequirements: defaults.privacyRequirements,
            preferredFileLineLimit: defaults.preferredFileLineLimit,
            healthKitLayerName: defaults.healthKitLayerName,
            buildCommand: promptForTextValue(.onboardingPromptBuildCommand, defaultValue: defaults.buildCommand, allowEmpty: true),
            testCommand: promptForTextValue(.onboardingPromptTestCommand, defaultValue: defaults.testCommand, allowEmpty: true)
        )
    }

    static func promptForTextValue(
        _ labelKey: SwiftNestMessageKey,
        defaultValue: String,
        allowEmpty: Bool = false
    ) -> String {
        while true {
            let label = SwiftNestLocalizer.text(labelKey)
            if defaultValue.isEmpty {
                print("\(label): ", terminator: "")
            } else {
                print("\(label) [\(defaultValue)]: ", terminator: "")
            }
            let rawValue = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if rawValue.isEmpty {
                if allowEmpty {
                    return defaultValue
                }
                return defaultValue.isEmpty ? rawValue : defaultValue
            }
            return rawValue
        }
    }

    static func promptForBooleanValue(_ labelKey: SwiftNestMessageKey, defaultValue: Bool) -> Bool {
        while true {
            let suffix = defaultValue ? "Y/n" : "y/N"
            print("\(SwiftNestLocalizer.text(labelKey)) [\(suffix)]: ", terminator: "")
            let rawValue = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if rawValue.isEmpty {
                return defaultValue
            }
            switch rawValue {
            case "y", "yes", "예", "ㅇ":
                return true
            case "n", "no", "아니오", "ㄴ":
                return false
            default:
                print(SwiftNestLocalizer.text(.onboardingPromptBooleanRetry))
            }
        }
    }

    static func renderConfigYAML(from draft: SwiftNestOnboardingConfigDraft) -> String {
        let values = draft.asDictionary()
        let orderedKeys = [
            "project_name",
            "optional_watchos_line",
            "ui_framework",
            "architecture_style",
            "min_ios_version",
            "package_manager",
            "test_framework",
            "lint_tools",
            "network_layer_name",
            "persistence_layer_name",
            "logging_system",
            "privacy_requirements",
            "preferred_file_line_limit",
            "healthkit_layer_name",
            "build_command",
            "test_command",
        ]
        return orderedKeys.map { key in
            let value = values[key] ?? ""
            return "\(key): \(yamlScalar(value))"
        }.joined(separator: "\n") + "\n"
    }

    static func yamlScalar(_ value: String) -> String {
        if value.isEmpty {
            return "\"\""
        }
        let needsQuotes = value.hasPrefix("#")
            || value.contains(":")
            || value.contains("\n")
            || value.hasPrefix(" ")
            || value.hasSuffix(" ")
        if !needsQuotes {
            return value
        }
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    static func resolveOnboardingProfile(
        parsed: ParsedArguments,
        repository: SwiftNestRepository,
        interactive: Bool
    ) throws -> String {
        if let profile = parsed.value(for: "--profile"), !profile.isEmpty {
            return profile
        }
        if interactive {
            return try chooseProfileInteractively(repository: repository, defaultProfileName: defaultOnboardingProfileName)
        }
        if repository.fileManager.fileExists(atPath: repository.profilesURL.appendingPathComponent("\(defaultOnboardingProfileName).yaml").path) {
            return defaultOnboardingProfileName
        }
        if let fallback = try repository.availableProfiles().first?.deletingPathExtension().lastPathComponent {
            return fallback
        }
        throw SwiftNestError(SwiftNestLocalizer.text(.noProfilesAvailable))
    }

    static func resolveOnboardingSkills(
        parsed: ParsedArguments,
        defaultSkills: [String],
        repository: SwiftNestRepository,
        interactive: Bool
    ) throws -> [String] {
        if let rawSkills = parsed.value(for: "--skills"), !rawSkills.isEmpty {
            return Array(Set(rawSkills.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })).sorted()
        }
        if interactive {
            return try chooseSkillsInteractively(defaultSkills: defaultSkills, repository: repository)
        }
        return defaultSkills.sorted()
    }

    static func resolveSkillAgentSelection(
        parsed: ParsedArguments,
        interactive: Bool
    ) throws -> SwiftNestSkillAgent? {
        if let rawSkillAgent = parsed.value(for: "--skill-agent") {
            return try validateSkillAgentSelection(rawSkillAgent)
        }
        if interactive {
            return try chooseSkillAgentInteractively()
        }
        return nil
    }

    static func validateSkillAgentSelection(_ rawValue: String) throws -> SwiftNestSkillAgent? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == SwiftNestSkillAgent.noneOption {
            return nil
        }
        guard let skillAgent = SwiftNestSkillAgent.normalized(from: trimmed) else {
            throw SwiftNestError(
                SwiftNestLocalizer.text(.unknownSkillAgent, trimmed, SwiftNestSkillAgent.supportedCodesSummary)
            )
        }
        return skillAgent
    }

    static func resolveWorkflowSelection(
        parsed: ParsedArguments,
        interactive: Bool,
        repository: SwiftNestRepository,
        defaultWorkflows: [String]
    ) throws -> [String] {
        let definitions = availableWorkflowDefinitions(repository: repository)
        let availableNames = Set(definitions.map(\.name))
        let availableDefaultWorkflows = defaultWorkflows.filter { availableNames.contains($0) }

        if let rawWorkflows = parsed.value(for: "--workflows"), !rawWorkflows.isEmpty {
            let names = rawWorkflows
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let validated = try validateWorkflowNames(names, repository: repository)
            let merged = Set(availableDefaultWorkflows).union(validated)
            return definitions.map(\.name).filter { merged.contains($0) }
        }
        if interactive {
            return try chooseWorkflowsInteractively(defaultWorkflows: availableDefaultWorkflows, repository: repository)
        }
        return availableDefaultWorkflows
    }

    static func onboardingDefaultWorkflows(repository: SwiftNestRepository) -> [String] {
        defaultOnboardingWorkflowNames.filter { workflowTemplateExists(named: $0, repository: repository) }
    }

    static func chooseWorkflowsInteractively(
        defaultWorkflows: [String],
        repository: SwiftNestRepository
    ) throws -> [String] {
        print(SwiftNestLocalizer.text(.availableWorkflowsHeader))
        let definitions = availableWorkflowDefinitions(repository: repository)
        for (index, workflow) in definitions.enumerated() {
            let kind = workflow.isDefault
                ? SwiftNestLocalizer.text(.workflowKindDefault)
                : SwiftNestLocalizer.text(.workflowKindOptional)
            let enabledByDefault = defaultWorkflows.contains(workflow.name)
            let mark = enabledByDefault ? "*" : " "
            print(String(format: "  %2d. [%@] %@ (%@) — %@", index + 1, mark, workflow.name, kind, workflow.runtimeDescription()))
        }
        print(SwiftNestLocalizer.text(.selectWorkflowsPrompt), terminator: "")
        let raw = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty {
            return defaultWorkflows
        }
        var chosen: [String] = []
        for token in raw.split(separator: ",") {
            let trimmed = token.trimmingCharacters(in: .whitespaces)
            guard let number = Int(trimmed) else {
                throw SwiftNestError(SwiftNestLocalizer.text(.invalidSelection, trimmed))
            }
            guard definitions.indices.contains(number - 1) else {
                throw SwiftNestError(SwiftNestLocalizer.text(.selectionOutOfRange, trimmed))
            }
            chosen.append(definitions[number - 1].name)
        }
        let merged = Set(defaultWorkflows).union(chosen)
        return definitions.map(\.name).filter { merged.contains($0) }
    }

    static func chooseSkillAgentInteractively() throws -> SwiftNestSkillAgent? {
        let options: [(label: String, value: SwiftNestSkillAgent?)] = [
            (SwiftNestLocalizer.text(.skillAgentNoneLabel), nil),
            (SwiftNestLocalizer.text(.skillAgentCodexLabel), .codex),
        ]

        print(SwiftNestLocalizer.text(.availableSkillAgentsHeader))
        for (index, option) in options.enumerated() {
            print("  \(index + 1). \(option.label)")
        }

        print(SwiftNestLocalizer.text(.selectSkillAgentPrompt, "1"), terminator: "")
        let raw = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let chosen = raw.isEmpty ? "1" : raw
        guard let number = Int(chosen), options.indices.contains(number - 1) else {
            throw SwiftNestError(SwiftNestLocalizer.text(.selectionOutOfRange, chosen))
        }
        return options[number - 1].value
    }

    static func printOnboardingAlreadyCompletedSummary(state: SwiftNestState, repository: SwiftNestRepository) {
        let workflows = normalizedWorkflowNames(state.workflows)
        print(SwiftNestLocalizer.text(.onboardingAlreadyCompleted, repository.rootURL.path))
        print(SwiftNestLocalizer.text(.onboardingCurrentProfile, state.profile))
        print(SwiftNestLocalizer.text(.onboardingCurrentSkills, state.skills.joined(separator: ", ")))
        print(SwiftNestLocalizer.text(.onboardingCurrentWorkflows, workflows.joined(separator: ", ")))
        print(SwiftNestLocalizer.text(.onboardingCurrentSkillAgent, selectedSkillAgentLabel(for: state.skillAgent)))
        printOnboardingReviewFollowUpIfNeeded(workflows: workflows)
        print(SwiftNestLocalizer.text(.onboardingUseForceToRerun))
    }

    static func printOnboardingCompletedSummary(
        result: SwiftNestState,
        repository: SwiftNestRepository,
        configURL: URL
    ) {
        let contextURL = repository.resolveStatePath(result.contextPath)
        print(SwiftNestLocalizer.text(.onboardingCompleted, repository.rootURL.path))
        print(SwiftNestLocalizer.text(.onboardingConfigReady, configURL.path))
        print(SwiftNestLocalizer.text(.onboardingCurrentProfile, result.profile))
        print(SwiftNestLocalizer.text(.onboardingCurrentSkills, result.skills.joined(separator: ", ")))
        print(SwiftNestLocalizer.text(.onboardingCurrentWorkflows, normalizedWorkflowNames(result.workflows).joined(separator: ", ")))
        print(SwiftNestLocalizer.text(.onboardingCurrentSkillAgent, selectedSkillAgentLabel(for: result.skillAgent)))
        print(SwiftNestLocalizer.text(.onboardingGeneratedFilesHeader))
        print("  - AGENTS.md")
        print("  - Docs/AI_RULES.md")
        print("  - Docs/AI_WORKFLOWS.md")
        print("  - Docs/AI_SKILLS/*")
        print("  - .swiftnest/state.json")
        print("  - .swiftnest/selected_skill_agent.txt")
        print("  - .swiftnest/rendered_context.md")
        if normalizedSkillAgentRawValue(result.skillAgent) == SwiftNestSkillAgent.codex.rawValue {
            print("  - .agents/skills/*")
        }
        if result.workflows.contains("onboarding-review") {
            print("  - .swiftnest/workflows/onboarding-review.md")
        }
        print(SwiftNestLocalizer.text(.onboardingHowAgentsUseThisHeader))
        print(SwiftNestLocalizer.text(.onboardingHowAgentsUseThisLine1))
        print(SwiftNestLocalizer.text(.onboardingHowAgentsUseThisLine2))
        print(SwiftNestLocalizer.text(.onboardingNextStepsHeader))
        print(SwiftNestLocalizer.text(.onboardingNextStepReviewConfig, configURL.path))
        print(SwiftNestLocalizer.text(.onboardingNextStepReviewAgents))
        printOnboardingReviewFollowUpIfNeeded(workflows: result.workflows)
        if normalizedSkillAgentRawValue(result.skillAgent) == SwiftNestSkillAgent.codex.rawValue {
            print(SwiftNestLocalizer.text(.onboardingNextStepCodexSkillsInstalled, repository.agentSkillsDirectoryURL.path))
        } else {
            print(SwiftNestLocalizer.text(.onboardingNextStepCodexSkillsNeeded))
        }
        print(SwiftNestLocalizer.text(.onboardingNextStepAgentRoot, repository.rootURL.path))
        print(SwiftNestLocalizer.text(.renderedContext, contextURL.path))
    }

    static func printOnboardingReviewFollowUpIfNeeded(workflows: [String]) {
        guard normalizedWorkflowNames(workflows).contains("onboarding-review") else {
            return
        }

        print(SwiftNestLocalizer.text(.onboardingNextStepReviewWorkflow))
        print(SwiftNestLocalizer.text(.onboardingNextStepReviewGoals))
    }

    static func skillSummary(named skill: String, repository: SwiftNestRepository) -> String {
        let candidates = [
            repository.rootURL.appendingPathComponent("Docs/AI_SKILLS/\(skill).md"),
            repository.templatesURL.appendingPathComponent("Docs/AI_SKILLS/\(skill).md"),
        ]
        for candidate in candidates where repository.fileManager.fileExists(atPath: candidate.path) {
            if let contents = try? String(contentsOf: candidate, encoding: .utf8) {
                let lines = contents.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                if let summary = lines.first(where: { $0.hasPrefix("Apply this skill whenever") || $0.hasPrefix("Use this skill whenever") || $0.hasPrefix("Apply this skill") }), !summary.isEmpty {
                    return summary
                }
            }
        }
        return SwiftNestLocalizer.text(.onboardingSkillSummaryFallback)
    }
}
