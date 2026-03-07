# Homebrew Packaging

This directory contains the release-time Homebrew formula template for SwiftNest.

## Files

- `swiftnest.rb.template`: starter formula that should be copied into the separate tap repository as `Formula/swiftnest.rb`
- `render_formula.sh`: renders the template with a concrete Git tag archive and SHA256

## Release Checklist

Release the Homebrew formula in this order:

1. Create and push a new Git tag from `swift-nest`.
2. Download the matching tag archive from GitHub.
3. Compute the archive SHA256.
4. Render the formula into the tap repository, typically `oozoofrog/homebrew-swiftnest`.

For the feature-to-release handoff sequence after work lands on `main`, see the repository `AGENTS.md`.

   ```bash
   ./packaging/homebrew/render_formula.sh \
     --tag v0.1.0 \
     --archive /tmp/swift-nest-v0.1.0.tar.gz \
     --output /path/to/homebrew-swiftnest/Formula/swiftnest.rb
   ```

   or

   ```bash
   make render-homebrew-formula \
     RELEASE_TAG=v0.1.0 \
     RELEASE_ARCHIVE=/tmp/swift-nest-v0.1.0.tar.gz \
     FORMULA_OUTPUT=/path/to/homebrew-swiftnest/Formula/swiftnest.rb
   ```

5. Commit the rendered formula to the tap repository.
6. Verify with:

   ```bash
   brew tap oozoofrog/swiftnest https://github.com/oozoofrog/homebrew-swiftnest
   brew install swiftnest
   brew test swiftnest
   ```

## Wrapper Behavior

The rendered Homebrew wrapper should:

- set `SWIFTNEST_ROOT` to the formula `libexec`
- allow bootstrap commands from the global installation (`install`, `list-skills`, `list-profiles`, and help)
- delegate to `./swiftnest` when the current directory already contains a repo-local installation
- print a clear error for commands like `init` when no repo-local installation exists yet
