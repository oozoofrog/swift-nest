import Foundation

do {
    let rawArguments = Array(CommandLine.arguments.dropFirst())
    SwiftNestLocalizer.configure(language: SwiftNestLanguageResolver.defaultLanguage())
    let resolvedInvocation = try SwiftNestLanguageResolver.resolve(arguments: rawArguments)
    SwiftNestLocalizer.configure(language: resolvedInvocation.language)
    try SwiftNestCLI.run(arguments: resolvedInvocation.arguments)
} catch let error as SwiftNestError {
    fputs("\(SwiftNestLocalizer.text(.errorPrefix)): \(error.message)\n", stderr)
    exit(1)
} catch {
    fputs("\(SwiftNestLocalizer.text(.errorPrefix)): \(error.localizedDescription)\n", stderr)
    exit(1)
}
