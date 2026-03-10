# Homebrew Packaging

This directory contains the release-time Homebrew formula template for SwiftNest.

## Files

- `swiftnest.rb.template`: starter formula that should be copied into the separate tap repository as `Formula/swiftnest.rb`
- `render_formula.sh`: renders the template with a concrete Git tag archive and SHA256
- Homebrew installs should also ship a `VERSION` file in `libexec` so `swiftnest --version` / `swiftnest -v` can report the packaged release version exactly
- Homebrew installs should also ship `resources/agents/...`, including `resources/agents/codex/bundled-skills/...`, so `swiftnest onboard --skill-agent codex` can render repo-local generated bundles and bundled shared Codex skills

## Release Checklist

Release the Homebrew formula in this order:

1. Create and push a new Git tag from `swift-nest`.
2. Download the matching tag archive from GitHub.
3. Compute the archive SHA256.
4. Render the formula into the tap repository, typically `oozoofrog/homebrew-swiftnest`.

For the feature-to-release handoff sequence after work lands on `main`, see the repository `AGENTS.md`.

   ```bash
   ./packaging/homebrew/render_formula.sh \
     --tag v0.1.3 \
     --archive /tmp/swift-nest-v0.1.3.tar.gz \
     --output /path/to/homebrew-swiftnest/Formula/swiftnest.rb
   ```

   or

   ```bash
   make render-homebrew-formula \
     RELEASE_TAG=v0.1.3 \
     RELEASE_ARCHIVE=/tmp/swift-nest-v0.1.3.tar.gz \
     FORMULA_OUTPUT=/path/to/homebrew-swiftnest/Formula/swiftnest.rb
   ```

5. Commit the rendered formula to the tap repository.
6. Verify with:

   ```bash
   brew tap oozoofrog/swiftnest https://github.com/oozoofrog/homebrew-swiftnest
   brew install swiftnest
   swiftnest --version
   swiftnest onboard --target /tmp/sample-repo --skill-agent codex --non-interactive
   brew test swiftnest
   ```

## Wrapper Behavior

The rendered Homebrew wrapper should:

- set `SWIFTNEST_ASSET_ROOT` (and compatibility aliases) to the formula `libexec`
- run the global `swiftnest` binary for all commands, including repo-targeting commands inside an onboarded repository
- avoid installing repo-local CLI wrappers or `tools/swiftnest-cli` into target repositories
