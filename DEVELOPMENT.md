# Development Guide

This guide describes how to develop, test, and release the `repository-installer` submodule.

## Running Tests

Tests are written using the [Bats-core (Bash Automated Testing System)](https://github.com/bats-core/bats-core) framework.

To run the full test suite locally:
1. Navigate to the `test/` directory:
   ```bash
   cd test
   ```
2. Execute the Bats binary:
   ```bash
   ./bats/bin/bats .
   ```

---

## Release Process

A GitHub Actions workflow is configured to automatically create a GitHub Release when version tags are pushed.

To publish a new version:

1. **Bump Version:** Update the `INSTALLER_VERSION` constant at the top of `src/installer.sh` (e.g. `INSTALLER_VERSION="2.9.0"`).
2. **Commit:** Commit the version bump:
   ```bash
   git add src/installer.sh
   git commit -m "chore: bump version to 2.9.0"
   ```
3. **Tag:** Tag the commit using semantic versioning prefixed with `v`:
   ```bash
   git tag -a v2.9.0 -m "Release v2.9.0"
   ```
4. **Push:** Push both the commit and the tag to GitHub:
   ```bash
   git push origin main
   git push origin v2.9.0
   ```

Once pushed, the Release GitHub Actions workflow will trigger and publish a new GitHub Release with auto-generated release notes.
