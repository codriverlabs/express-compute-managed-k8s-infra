# Development Workflow

## Dependency Updates (Including Dependabot PRs)

All dependency updates — including those proposed by Dependabot — must follow the standard development workflow:

1. **Create a feature branch** from `main` (do not merge Dependabot PRs directly).
2. **Apply the dependency change** on the feature branch (bump the version in `pom.xml`).
3. **Run the full test suite** and ensure all tests pass.
4. **Only if tests are successful**, create a PR from the feature branch.

Dependabot PRs should be treated as notifications of available updates, not as merge-ready contributions. Close the Dependabot PR after the change has been landed through the standard workflow.
