The `pull_request` trigger is deliberately unscoped. Adding `branches: [main]`
would match the sibling repositories, but a pull request opened against any
other base would then post none of the checks the ruleset requires, which reads
as a hang rather than a failure because nothing will ever report.
