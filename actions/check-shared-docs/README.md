# `check-shared-docs`

Compares the shared blocks marked in a repository's `AGENTS.md` against the
canonical copies held in this action, and fails with a diff when they disagree.

```yaml
- name: Check out repository
  uses: actions/checkout@v7.0.1

- name: Check shared documentation blocks
  uses: kanso-labs/github-actions/actions/check-shared-docs@v3.1.0
```

Checking out is the caller's job, the same way it is for
[`setup-node`](../setup-node) and [`lint-workflows`](../lint-workflows). The
file being checked has to be in the working directory already.

## Why the blocks are duplicated at all

Every `kanso-labs` `AGENTS.md` writes the shared conventions out in full, so
that an agent handed one repository on its own still gets them. `AGENTS.md` has
no include mechanism, and `CLAUDE.md`'s `@import` is specific to one tool, so
the duplication is deliberate and is not going away.

What is not deliberate is drift. The copies had been retyped rather than copied,
which left the same rule carrying different punctuation in each repository — and
a set of paragraphs nothing can diff is a set where a wrong fact in one copy is
invisible from the others. That is not hypothetical: one roster paragraph was
wrong about two different repositories on the same day, in three files at once.

This action is the other half of the arrangement. Keep the copies; check them.

## Marking a block

Wrap the copy in a matching pair of HTML comments, which render as nothing:

```markdown
<!-- shared:conventions -->

- **Keys in JSON and YAML are ordered by name.** …
- **A workflow's filename is the kebab-case of its `name:` field.** …

<!-- /shared:conventions -->
```

The markers are also the point of the exercise for a human. They say, at the
place someone is about to edit, that this text is shared and that editing it
here alone will fail a check.

Marking is opt-in per block, so there is no list of which repository carries
what to keep in step. A repository with no package manifest marks
`conventions-core` and never mentions the npm bullets; everyone else marks
`conventions`.

Blank lines directly inside the markers are ignored, because Prettier and oxfmt
both insert one between an HTML comment and the block beside it. Blank lines in
the middle of a block are compared like any other line.

## Blocks

| Block                   | What it is                                                       |
| ----------------------- | ---------------------------------------------------------------- |
| `conventions`           | All six shared Conventions bullets                               |
| `conventions-core`      | The first four, for a repository with no package manifest        |
| `branch-commits`        | Why branch commits still follow the convention after a squash    |
| `node-install`          | Installing under the pinned Node, and the lockfile hazard        |
| `job-name-check`        | A job name is a check name, so a rename edits the merge gate     |
| `pull-request-unscoped` | Why the `pull_request` trigger takes no `branches:` filter       |
| `commitlint`            | commitlint present, no `commit-msg` hook, so nothing enforces it |

`conventions-core` is a prefix of `conventions`, which is duplication inside
this action rather than across repositories. The script asserts the prefix on
every run and fails loudly if the two ever disagree, so the overlap cannot rot
into two contradictory canonical copies.

## Inputs

| Input  | Default     | Description            |
| ------ | ----------- | ---------------------- |
| `file` | `AGENTS.md` | Markdown file to check |

## What fails the check

- A marked block whose text differs from the canonical copy, reported as a
  unified diff of the two.
- A marker naming a block this action does not ship, so a typo is an error
  rather than a silent pass.
- A block that opens and never closes, which would otherwise swallow the rest of
  the file.
- A file that marks no blocks at all, since that means the action was wired up
  but is checking nothing.

## Where it runs

Put it in the job that already gates merges rather than in a job of its own, the
same as [`lint-workflows`](../lint-workflows). A new job means a new check name,
and a check name that no ruleset requires is advisory — it can fail without
stopping anything, which for a drift guard means not guarding.

## Changing a shared block

Change `blocks/<name>.md` here, release, then bump the pin in each repository
that marks it and update its copy in the same pull request. Until that lands,
the check fails there — which is the intended behaviour, and the reason the
blocks are ones that genuinely never need to differ.
