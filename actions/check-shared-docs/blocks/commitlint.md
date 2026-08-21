**commitlint is installed but never runs.** `@commitlint/cli`,
`@commitlint/config-conventional` and `.commitlintrc.json` are all present, and
`.husky/` carries a `pre-commit` hook — but that hook runs lint-staged, not
commitlint. There is no `commit-msg` hook and no workflow invoking one, so a
malformed type reaches `main` unnoticed and lands in the changelog, and the pull
request title is on the author to get right.
