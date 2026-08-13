# github-actions

Shared GitHub Actions workflows and composite actions for the `kanso-labs`
organization.

Every repository here is public, so nothing needs to be configured for one of
them to consume these. A private consumer would need
`Settings → Actions → General → Access` opened up first.

## What is here

| Thing                                                            | Kind              | Solves                                                      |
| ---------------------------------------------------------------- | ----------------- | ----------------------------------------------------------- |
| [`actions/setup-node`](actions/setup-node)                       | Composite action  | The Node setup preamble repeated in every Node CI job       |
| [`_release-please.yaml`](.github/workflows/_release-please.yaml) | Reusable workflow | Proposing releases, with a token whose pull requests run CI |

## Consuming them

Pin an exact version. Renovate opens the bump pull requests, the same way it
does for every other action these repositories pin.

```yaml
- name: Set up Node
  uses: kanso-labs/github-actions/actions/setup-node@v1.0.0
```

```yaml
concurrency:
  cancel-in-progress: false
  group: release-please

jobs:
  release-please:
    name: Propose releases
    uses: kanso-labs/github-actions/.github/workflows/_release-please.yaml@v1.0.0
    secrets:
      app-id: ${{ secrets.RELEASE_PLEASE_APP_ID }}
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

## `_release-please.yaml`

Wraps `googleapis/release-please-action` with the things that were only ever
configured in one repository:

**An application token, when the caller supplies one.** Pull requests opened
with the default `GITHUB_TOKEN` do not start workflow runs. Their checks sit at
`action_required` until somebody approves them by hand, so a release stalls
there — and if the repository requires status checks to merge, auto-merge can
never fire, because the checks it is waiting for never report. Requests made
with a GitHub App token trigger checks like any other.

Both `app-id` and `private-key` are optional. Without them the run falls back to
`GITHUB_TOKEN`, warns in the job log, and still opens a correct release pull
request — it just has to be merged by a person. That fallback is what lets a
repository adopt this workflow before its secrets are in place.

**In fallback mode, auto-merge is disabled no matter what `auto-merge` is set
to.** Merging the release pull request is only half of a release: that merge
pushes the default branch, and the run it starts is what cuts the tag and the
GitHub release. A push made with `GITHUB_TOKEN` starts no run, so auto-merging
as it strands the release — version bumped on the branch, nothing tagged, and no
pull request left to merge. A person's merge does start that run, so the
fallback leaves the merge to them.

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

| Caller supplies            | Needs at workflow level                                    |
| -------------------------- | ---------------------------------------------------------- |
| `app-id` and `private-key` | `contents: read` — the app token does the writing          |
| Neither                    | `contents: write`, `issues: write`, `pull-requests: write` |

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

### Outputs

`release_created`, `releases_created`, `paths_released`, `prs`, `tag_name` and
`version`, passed straight through from the action. A caller that publishes on
release reads `release_created`:

```yaml
publish:
  needs: release-please
  if: needs.release-please.outputs.release_created == 'true'
```

## Releasing this repository

release-please owns `version.txt` and `.release-please-manifest.json`. Nobody
edits either by hand.

The type of the pull request title decides what happens, and because pull
requests are squash-merged, that title is the only commit that reaches `main`:

| Title type    | Effect        |
| ------------- | ------------- |
| `feat`        | Minor release |
| `fix`         | Patch release |
| anything else | No release    |

A release that changes how a consumer must call something is a breaking change,
and it needs `!` so the major moves. Consumers pin exact versions, so nothing
breaks the moment it is released — but a Renovate bump landing on a repository
that never read the changelog is the same failure a day later.

This repository's own `release-please.yaml` pins a tag rather than referencing
`./`, so it runs exactly what consumers run. Renovate bumps that pin like any
other, which means the workflow lags one Renovate cycle behind its own latest
release. That is deliberate: it is the same lag every consumer has.
