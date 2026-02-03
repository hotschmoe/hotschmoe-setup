Part 1: Repository Settings (GitHub UI)
To protect master and ensure only approved, passing PRs can be merged:
Go to your GitHub repository > Settings > Branches.
Click Add branch protection rule.
Branch name pattern: master (or main if that is your default).
Check Require a pull request before merging.
Optional: Check "Require approvals" if you have collaborators. If you are the only person working on this, leave "Require approvals" unchecked. GitHub prevents you from approving your own PRs, so checking this on a solo repo will block you from merging. As the owner, your act of merging is the acceptance.
Check Require status checks to pass before merging.
In the search box that appears, search for build-and-test (this is the job name we will define in the workflow below).
Note: This option might not appear until you have pushed the workflow file once. You can come back and check this after setting up Part 2.
Check Do not allow bypassing the above settings.
This ensures even you (the admin) must use a PR and pass tests.
Click Create.

How to use this workflow
Development: Create a branch (e.g., feature/login), write code, and push.
Pull Request: Open a PR to master. The CI workflow will run automatically. You will see a green checkmark if zig build test passes.
Merge: If tests pass, you merge the PR.
Release:
If you did not change the version in build.zig.zon, the Release workflow runs, sees the tag exists, and does nothing.
If you did change the version (e.g., 0.1.0 -> 0.2.0) in the PR, the Release workflow will automatically tag the commit v0.2.0 and create a GitHub Release.