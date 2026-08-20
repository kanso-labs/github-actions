# github-actions

Shared GitHub Actions workflows and composite actions for the `kanso-labs`
organization.

Every repository here is public, so nothing needs to be configured for one of
them to consume these. A private consumer would need
`Settings → Actions → General → Access` opened up first.

## What is here

| Thing                                                                | Kind              | Solves                                                                  |
| -------------------------------------------------------------------- | ----------------- | ----------------------------------------------------------------------- |
| [`actions/lint-workflows`](actions/lint-workflows)                   | Composite action  | Running actionlint, pinned, in every repository that has workflows      |
| [`actions/setup-node`](actions/setup-node)                           | Composite action  | The Node setup preamble repeated in every Node CI job                   |
| [`_publish-npm.yaml`](.github/workflows/_publish-npm.yaml)           | Reusable workflow | Publishing a package over trusted publishing, after a release is cut    |
| [`_release-please.yaml`](.github/workflows/_release-please.yaml)     | Reusable workflow | Proposing releases, with a token whose pull requests run CI             |
| [`_renovate-command.yaml`](.github/workflows/_renovate-command.yaml) | Reusable workflow | Answering `@renovate rebase` on a pull request, the way Dependabot does |

## Consuming them

Pin an exact version. Renovate opens the bump pull requests, the same way it
does for every other action these repositories pin.

```yaml
- name: Set up Node
  uses: kanso-labs/github-actions/actions/setup-node@v2.0.0
```

```yaml
concurrency:
  cancel-in-progress: false
  group: release-please

jobs:
  release-please:
    name: Propose releases
    uses: kanso-labs/github-actions/.github/workflows/_release-please.yaml@v2.0.0
    secrets:
      client-id: ${{ secrets.RELEASE_PLEASE_CLIENT_ID }}
      private-key: ${{ secrets.RELEASE_PLEASE_PRIVATE_KEY }}
```

That `concurrency` block is not optional — see below.

Tracking `@main` instead would mean a mistake here breaks CI in every consuming
repository at once, with no way to hold one back. That is the whole reason for
the tags.

## `actions/setup-node`

Reads the Node version from `.tool-versions`, restores the npm cache, and runs
`npm ci`. Full inputs are in [its README](actions/setup-node/README.md).

The npm cache comes from `actions/setup-node`'s own `cache: npm`, which is why
consumers do not need a separate `actions/cache` step for `~/.npm`. Any such
step left behind is doing nothing.

## `actions/lint-workflows`

Runs actionlint over `.github/workflows`, at a pinned version. Full inputs are
in [its README](actions/lint-workflows/README.md).

Put it in the job a ruleset already requires rather than in a job of its own. A
new job means a new check name, and a check name nothing requires can fail
without stopping anything — so a workflow linter added that way reports problems
to no one.

A repository silences a rule by committing `.github/actionlint.yaml`, which
actionlint discovers by itself. That file is also the escape hatch for
actionlint being stale: it carries its own copy of the valid permission scopes,
so a scope GitHub has added since the pinned release reads as an error on a
workflow that is perfectly correct. `kanso-ui` needs exactly that for
`code-quality`, which `actions/upload-code-coverage` requires.

## `_publish-npm.yaml`

Publishes a package to npm after `_release-please.yaml` has cut a release. It
checks out, installs, builds, and publishes — the four steps `kanso-ui` and
`unplugin-style-dictionary` each had their own copy of.

```yaml
publish:
  name: Publish to npm
  needs: release-please
  if: needs.release-please.outputs.release_created == 'true'
  permissions:
    contents: read
    id-token: write
  uses: kanso-labs/github-actions/.github/workflows/_publish-npm.yaml@v2.1.0
```

Compare `release_created` against the string. A bare truthiness test also passes
on `"false"`, which is what that output carries when release-please runs and
decides not to cut a release — so the package would be published on every merge.

### There is no token

Publishing goes over npm trusted publishing, so the caller passes no secrets at
all. `id-token: write` is what npm exchanges for a short-lived credential, and
it is what mints the provenance attestation alongside it.

Unlike `_release-please.yaml`, this workflow does declare its `permissions`,
because here they do not vary: every caller publishes the same way and needs the
same two scopes. A caller that forgets `id-token` then fails immediately with a
message naming the scope, rather than reaching npm and being refused there for a
reason that reads as an npm problem.

**The first publish of a package cannot use this.** npm configures a trusted
publisher on the package page, and the package has to exist before there is a
page to configure, so a new package is pushed by hand once and this takes over
afterwards. Both packages in this organization were bootstrapped that way.

### `ignore-scripts` defaults to true here

The composite action defaults it to `false` and this defaults it to `true`,
which is worth explaining rather than lining up.

`npm` runs `prepare` on publish as well as on install. A repository whose
`prepare` downloads Playwright's browsers therefore pays for that download twice
in this job — once installing, once as a step of the publish itself, where
failing to fetch a browser aborts a release that has already been tagged.
Nothing either package ships is produced by a lifecycle script; the build step
is the whole of it.

Set it to `false` only for a package with a native dependency to compile.

### Inputs

| Input               | Default                      | Description                                     |
| ------------------- | ---------------------------- | ----------------------------------------------- |
| `build-script`      | `build`                      | npm script producing what is published          |
| `dry-run`           | `false`                      | Publish with `--dry-run`, uploading nothing     |
| `ignore-scripts`    | `true`                       | Pass `--ignore-scripts` to `npm ci` and publish |
| `node-version-file` | `.tool-versions`             | File the Node version is read from              |
| `registry-url`      | `https://registry.npmjs.org` | Registry to publish to                          |

Pass `build-script: ''` for a package with nothing to build; the step is then
skipped rather than running `npm run` with an empty argument.

### It inlines the Node setup rather than calling `actions/setup-node`

Deliberately, and it is the one duplication here that should stay.

A `./` reference inside a reusable workflow resolves against the checkout in the
workspace, and that checkout belongs to the caller — so it would look for the
composite in the consuming repository and not find it. GitHub documents `./` for
referencing a workflow in the same repository and says nothing either way about
an action referenced from inside a called workflow, which is not a thing to rest
on when every consumer publishes through here.

Naming the composite by tag would work and introduces a worse problem: it pins
this repository to a version of itself that does not exist until the release
carrying the change is cut.

What inlining gives up is the cache handling, and this job turns that off
regardless — it installs once and throws the runner away, so restoring the cache
costs more than the single install it would save.

### Verifying a change to it

`dry-run` runs everything including `npm publish --dry-run`, which resolves the
manifest and prints the file list without uploading. It cannot be exercised in
this repository: `package.json` here is `private: true`, and npm refuses to
publish — even a dry run — for a private package.

Canary it in `unplugin-style-dictionary` instead, following the recipe in
[`AGENTS.md`](AGENTS.md).

## `_release-please.yaml`

Wraps `googleapis/release-please-action` with the things that were only ever
configured in one repository:

**An application token, when the caller supplies one.** Pull requests opened
with the default `GITHUB_TOKEN` do not start workflow runs. Their checks sit at
`action_required` until somebody approves them by hand, so a release stalls
there — and if the repository requires status checks to merge, auto-merge can
never fire, because the checks it is waiting for never report. Requests made
with a GitHub App token trigger checks like any other.

Both `client-id` and `private-key` are optional. Without them the run falls back
to `GITHUB_TOKEN`, warns in the job log, and still opens a correct release pull
request — it just has to be merged by a person. That fallback is what lets a
repository adopt this workflow before its secrets are in place.

**There is no `app-id` input.** Both workflows took one as a deprecated alias
through v1.x and dropped it in v2.0.0, which is what makes v2 a major. A caller
bumping to v2 has to rename the secret it passes; the value need not change,
since a GitHub App id and a client id are interchangeable where it lands — each
is accepted as the JWT issuer. Passing an app id under the `client-id` name
still works, so the rename can be done before the secret is.

**In fallback mode, auto-merge is disabled no matter what `auto-merge` is set
to.** Merging the release pull request is only half of a release: that merge
pushes the default branch, and the run it starts is what cuts the tag and the
GitHub release. A push made with `GITHUB_TOKEN` starts no run, so auto-merging
as it leaves the release half-applied: the version is bumped and the changelog
written, but nothing is tagged. The next push to the default branch, whenever
that happens and whatever it is for, cuts the tag late — so on a quiet
repository the released version spends an unbounded stretch being one that
nobody can pin. A person's merge starts the run immediately, so the fallback
leaves the merge to them.

A repository whose ruleset requires status checks cannot really use the fallback
at all: the release pull request never starts the checks it is required to pass,
so nobody without bypass can merge it. `kanso-ui` and
`unplugin-style-dictionary` are both in that position, which is the real reason
they need the app installed rather than a stylistic one.

**Auto-merge on the release pull requests.** Enabled by default; pass
`auto-merge: false` to turn it off. Note that `--auto` only queues when
something is already blocking the pull request. With no required checks it
merges on the spot.

### Permissions

The workflow deliberately declares no `permissions` block, because what the
caller needs depends on which token it uses:

| Caller supplies               | Needs at workflow level                                    |
| ----------------------------- | ---------------------------------------------------------- |
| `client-id` and `private-key` | `contents: read` — the app token does the writing          |
| Neither                       | `contents: write`, `issues: write`, `pull-requests: write` |

A called workflow cannot request more than its caller granted, so declaring
write here would force the first kind to widen its `GITHUB_TOKEN` for no reason.

### The caller owns the concurrency group

Overlapping release-please runs race each other. Every release merge pushes the
default branch, every push starts a run, and two runs landing together try to
cut the same tags and strip the same labels — one then dies on the other's
half-finished work. `cancel-in-progress` stays off, because the last push must
still get a run or the release it carries is never proposed.

The guard is required, and it goes in the caller. GitHub documents `concurrency`
at the caller and says nothing either way about a group declared inside a called
workflow, and a guard that only matters during a rare race is the worst thing to
rest on undocumented behaviour: if it quietly did nothing, every consumer would
lose it at once and nobody would learn that until the race happened. In the
caller it is supported, it is visible in review, and forgetting it costs one
repository instead of all of them.

### `dry-run`

Runs release-please without opening a pull request or cutting a release. It
exists so this workflow can be tested on a pull request, and
`Dry run release-please` in `test.yaml` is its only caller. A repository
releasing for real has no reason to set it.

### Outputs

`release_created`, `releases_created`, `paths_released`, `prs`, `tag_name` and
`version`, passed straight through from the action. A caller that publishes on
release reads `release_created`:

```yaml
publish:
  needs: release-please
  if: needs.release-please.outputs.release_created == 'true'
```

## `_renovate-command.yaml`

Renovate has no comment commands. Asking it to redo a pull request means ticking
a checkbox in the body and then waiting for its next scheduled run, which in
this organization is up to three hours away. This workflow closes both halves of
that gap, so `@renovate rebase` behaves the way `@dependabot rebase` does.

```yaml
on:
  issue_comment:
    types:
      - created

concurrency:
  cancel-in-progress: false
  group: renovate-command-${{ github.event.issue.number }}

permissions: {}

jobs:
  renovate-command:
    name: Run the command
    uses: kanso-labs/github-actions/.github/workflows/_renovate-command.yaml@v2.0.0
    secrets:
      client-id: ${{ secrets.RENOVATE_CLIENT_ID }}
      private-key: ${{ secrets.RENOVATE_APP_PRIVATE_KEY }}
```

| Comment                                                     | Effect                                                               |
| ----------------------------------------------------------- | -------------------------------------------------------------------- |
| `@renovate rebase`, `@renovate retry`, `@renovate recreate` | Ticks the pull request's rebase checkbox, then dispatches the runner |
| `@renovate run`                                             | Dispatches the runner without touching the pull request              |

The three pull request commands are one command under three names, because which
name is right depends on what Renovate decides to do with the branch, and nobody
asking for it knows that yet. Renovate's own checkbox says "rebase/retry", and
it recreates the branch when the rebase is not enough.

The bot reacts as it goes: 👀 accepted, 🚀 dispatched, 😕 refused. A refusal is
never a failed run, so somebody's typo does not put a red X on the pull request.

### It ticks the box rather than replacing it

There is no API for "rebase this Renovate branch", and the workflow does not try
to rebase anything itself. It edits the pull request body, turning
`- [ ] <!-- rebase-check -->` into `- [x] <!-- rebase-check -->` — byte for byte
what GitHub records when a person clicks that checkbox — and then dispatches the
runner so Renovate reads it now instead of in three hours.

Everything that decides what "rebase" means stays inside Renovate. That is the
point: the workflow adds a way to ask, not a second implementation of the
answer.

It follows that the commands only work on pull requests Renovate opened. On
anything else the marker is absent and the run fails loudly, which is the honest
outcome — the alternative is a 👍 on a request nothing will ever act on.

### Both secrets are required

Unlike `_release-please.yaml`, there is no `GITHUB_TOKEN` fallback, because
`GITHUB_TOKEN` cannot dispatch a workflow in another repository under any
permissions. The app must be installed on the calling repository and on the
runner, and needs `actions: write` there — the permission nothing else in this
organization uses.

The caller grants no permissions at all. Every write goes through the app token,
so this workflow can and does declare `permissions: {}`, which is the opposite
of `_release-please.yaml` above and for a reason worth keeping straight: a
called workflow may always request _less_ than its caller granted. It is
requesting more that fails the run.

### Adopting it takes two merges, not one

`issue_comment` is a repository-level event. GitHub runs the copy of the
workflow that is on the default branch and ignores every other copy, so a caller
sitting on a branch does nothing no matter how many comments it gets — and
neither does a change to one.

A repository adopting this therefore merges the caller first and finds out
whether it works second. Point the `uses:` ref at a branch of this repository
for that first merge if the workflow itself is what is being tried out, then
move it to a tag.

### Who may run a command

The comment author must have `write` or `admin` on the repository the comment is
in. The check asks GitHub for the permission level rather than reading
`author_association`, which is free but reports `NONE` for a member whose
organization membership is private — silently ignoring the person most likely to
be using this.

The mention must also open a line. GitHub prefixes a quoted reply with `> `, so
quoting a command repeats it without running it.

## Releasing this repository

release-please owns `version.txt` and `.release-please-manifest.json`. Nobody
edits either by hand.

The type of the pull request title decides what happens, and because pull
requests are squash-merged, that title is the only commit that reaches `main`:

| Title type    | Effect        |
| ------------- | ------------- |
| `feat`        | Minor release |
| `fix`         | Patch release |
| `deps`        | Patch release |
| anything else | No release    |

`deps` is not a Conventional Commits type. It exists because Renovate's default
type is `chore(deps)`, and `chore` is hidden in release-please's defaults —
release-please decides there are no user-facing commits and opens no release
pull request at all. So a run of nothing but dependency upgrades released
nothing, and an upgrade shipped only when a feature happened to land beside it.

Consumers pin exact tags, so an upgrade that cuts no release is one nobody can
pin. `.github/renovate.json` therefore sets `semanticCommitType: deps`, and
`release-please-config.json` gives that type a visible **Dependencies** section.
The section list there replaces release-please's defaults wholesale rather than
extending them, so dropping `feat` or `fix` from it would silently stop those
releases too.

A plain `chore:` still publishes nothing, which is the point: housekeeping
should not cut a release.

A release that changes how a consumer must call something is a breaking change,
and it needs `!` so the major moves. Consumers pin exact versions, so nothing
breaks the moment it is released — but a Renovate bump landing on a repository
that never read the changelog is the same failure a day later.

This repository's own `release-please.yaml` pins a tag rather than referencing
`./`, so it runs exactly what consumers run. Renovate bumps that pin like any
other, which means the workflow lags one Renovate cycle behind its own latest
release. That is deliberate: it is the same lag every consumer has.
