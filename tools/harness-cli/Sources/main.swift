import Foundation

do {
    try HarnessCLI.run(arguments: Array(CommandLine.arguments.dropFirst()))
} catch let error as HarnessError {
    fputs("error: \(error.message)\n", stderr)
    exit(1)
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
