import Foundation

do {
    try SwiftNestCLI.run(arguments: Array(CommandLine.arguments.dropFirst()))
} catch let error as SwiftNestError {
    fputs("error: \(error.message)\n", stderr)
    exit(1)
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
