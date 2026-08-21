# AGENTS.md

Guidance for coding agents working in this repository.

## What this is

The shared CI surface for the `kanso-labs` organization: composite actions under
`actions/`, reusable workflows under `.github/workflows/` with a leading
underscore. [`README.md`](README.md) documents what each one does and how to
call it — read it first, and keep it correct when you change behaviour, because
it is what consumers read.

Consumers today:

| Repository                                                                               | Uses                                                                                                                  |
| ---------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| [home-assistant-applications](https://github.com/kanso-labs/home-assistant-applications) | `_release-please.yaml`                                                                                                |
| [kanso-ui](https://github.com/kanso-labs/kanso-ui)                                       | `_publish-npm.yaml`, `_release-please.yaml`, `_renovate-command.yaml`, `actions/lint-workflows`, `actions/setup-node` |
| [renovate](https://github.com/kanso-labs/renovate)                                       | `_renovate-command.yaml`                                                                                              |
| [unplugin-style-dictionary](https://github.com/kanso-labs/unplugin-style-dictionary)     | `_publish-npm.yaml`, `_release-please.yaml`, `_renovate-command.yaml`, `actions/lint-workflows`, `actions/setup-node` |

Nothing here is used by one repository alone. A change that looks obviously
right in the shape one consumer calls it can still be wrong for the other two,
so check all of them before changing an input's meaning or a default.

## Conventions

Shared with the other `kanso-labs` repositories:

- **Keys in JSON and YAML are ordered by name.** Files whose order carries
  meaning are exempt: workflows, where step order is execution order;
  changelogs, which are chronological; and `package.json`, where the npm
  ecosystem expects `name` and `version` first.
- **A workflow's filename is the kebab-case of its `name:` field.** Reusable
  workflows, meaning those triggered only by `workflow_call`, take a leading
  underscore.
- **Job names and step names are imperative verb phrases.** Job ids, step ids,
  and matrix keys are exempt.
- **Actions are pinned to exact release tags**, `actions/checkout@v7.0.1`, never
  a moving major or `@main`. Renovate opens the bump pull requests.

Formatting is not shared, and assuming it is will send you to a command that
does not exist. **Prettier formats the YAML, JSON and Markdown here**, and CI
checks it — run `npm run format` before pushing. Elsewhere in the organization:
`home-assistant-applications` matches this, `kanso-ui` uses oxfmt
(`npm run format`, checked inside `npm run lint`), `unplugin-style-dictionary`
has no `format` script and runs Prettier only through `eslint-plugin-prettier`
inside `npm run lint`, and `renovate` has no formatter at all.

## Versioning

Consumers pin exact tags — `@v1.2.3`, never `@main` or `@v1`. Renovate opens the
bump pull requests.

That is what makes an error here survivable: it reaches one repository at a
time, in a pull request, rather than all four the moment it merges. Do not
"simplify" a consumer to `@main`.

release-please owns `version.txt` and `.release-please-manifest.json`. Nobody
edits either by hand. Pull requests are squash-merged, so the pull request title
is the only commit that reaches `main` and the single input to the release:
`feat` for a minor, `fix` and `deps` for a patch, `!` for a breaking change,
anything else releases nothing.

`deps` is not a Conventional Commits type, and it is here because Renovate's
default `chore(deps)` is hidden in release-please's defaults — which makes
release-please decide there are no user-facing commits and open no release pull
request at all. A run of nothing but upgrades therefore released nothing, and
consumers pin exact tags, so an upgrade that cuts no release is one nobody can
pin. `.github/renovate.json` sets `semanticCommitType: deps` in a `packageRule`
— see Traps for why it cannot be a top-level key — and
`release-please-config.json` gives it a visible **Dependencies** section. That
section list supersedes release-please's defaults rather than extending them, so
a type dropped from it becomes invisible rather than merely unstyled.

**Breaking means "a consumer must edit something to keep working"** — removing
an input, renaming an output, changing a default. Exact pins mean nothing breaks
at release time. It breaks when Renovate's bump lands somewhere that never read
the changelog, so the major is the only warning that arrives with the change.

## Verifying a change

`npm run lint` and actionlint cover syntax. Neither proves a workflow does what
it claims — most of what has gone wrong in CI here was valid YAML.

**Both composite actions have a live smoke test**, in
[`lint.yaml`](.github/workflows/lint.yaml): `check-formatting` calls
`./actions/setup-node` and `lint-workflows` calls `./actions/lint-workflows`, so
a change that breaks either fails on the pull request rather than in whichever
repository next bumps its pin. Those are the only jobs in this repository that
exercise them — keep them that way round, and do not "tidy" either into a plain
`actions/setup-node` or `raven-actions/actionlint` step.

A local `./` reference is safe there and is not safe inside a reusable workflow;
see the trap below before copying the pattern into one.

**The reusable workflow has one too, in dry-run.** `Dry run release-please` in
[`test.yaml`](.github/workflows/test.yaml) calls
`./.github/workflows/_release-please.yaml` with `dry-run: true`, so
release-please resolves the config, walks the commits and computes versions
while opening no pull request and cutting no release. It passes no secrets, so
it covers the `GITHUB_TOKEN` fallback and its warning as well. That path
reference is deliberate and is the opposite of what `release-please.yaml` does:
the test has to run the version in the pull request, which is the only version
not yet released.

**`_publish-npm.yaml` has no smoke test here, and cannot have one.** Its
`dry-run` input runs everything through `npm publish --dry-run`, which uploads
nothing — but `package.json` in this repository is `private: true`, and npm
refuses to publish a private package even as a dry run. Canary it in
`unplugin-style-dictionary` with the recipe below, which is what `dry-run`
exists to make safe.

What none of this covers is the application-token path, or anything that only
happens on a real push to a default branch. For a change touching those, canary
it by hand as well:

1. Push a branch here with the change.
2. On a branch in one consumer, flip its `uses:` ref to that branch.
3. Merge nothing — dispatch or push the consumer branch and read the run.
4. Delete both branches, then merge the real pull request.

Do this in `unplugin-style-dictionary` rather than
`home-assistant-applications`: it has one package, no application token, and
nothing installed depends on its releases.

`_renovate-command` canaries in `renovate`, its only consumer and the one place
an open Renovate pull request is always available to comment on. Two things
about it differ from the recipe above:

**The caller cannot be canaried from a branch.** `issue_comment` is a
repository-level event, so GitHub runs whatever version of the workflow file is
on the default branch and ignores every other copy. Step 2 above is impossible.
The caller has to be merged to `main` first, with its `uses:` ref pointed at the
branch here, and the pin moved to the released tag afterwards.

**A green run is not evidence.** The job exits 0 on an unrecognised command, on
an unauthorised author, and on a comment that turns out not to hold a command at
all — all deliberate, so that a stranger's typo does not put a red X on a pull
request. Read what the run logged and check the reaction that landed on the
comment, rather than its colour.

## Traps

**`semanticCommitType` has to be a `packageRule`, not a top-level key.** It was
top-level at first and did nothing at all: `config:recommended` extends
`:semanticPrefixFixDepsChoreOthers`, which sets the type through `packageRules`
— `matchPackageNames: ["*"] -> chore`, plus a narrower `dependencies -> fix` —
and `packageRules` beat top-level config. So every upgrade kept the type the
preset chose, and Renovate went on writing `chore:` while the setting sat there
looking correct.

The rule this repository carries is therefore first in `packageRules`, where a
later rule can still override it for specific packages.

**A called workflow cannot request more permissions than its caller granted.**
Not a silent intersection — the run fails outright with a message naming the
scope. That is why `_release-please.yaml` declares no `permissions` block at
all: its callers do not need the same ones, because a caller supplying an
application token leaves `GITHUB_TOKEN` on `contents: read` while one falling
back to it needs three write scopes. Adding a block here would break the first
kind.

**Merging a release pull request is only half a release, and who merges it
decides whether the other half happens.** The merge pushes the default branch,
and the run that push starts is what cuts the tag and the GitHub release. A push
made with `GITHUB_TOKEN` starts no run, so auto-merging in the fallback path
leaves the release half-applied: the version is bumped and the changelog written
on the branch, but nothing is tagged and no GitHub release exists. That is why
the auto-merge step tests `env.CLIENT_ID != ''` as well as its own input.

It recovers on its own, which is what makes it easy to miss. The next push to
the default branch — any push, for any reason — starts a run that finds the
merged release pull request still labelled `autorelease: pending` and cuts the
tag then. On a quiet repository that is however long it takes somebody to push
something else, and until it happens the version in `version.txt` is one no
consumer can pin, because the tag it names does not exist. Both v1.0.1 and
v1.0.2 of this repository were released that way.

**The concurrency guard lives in the caller, and that is deliberate.** Do not
move it into `_release-please.yaml` to save the repetition. GitHub documents
`concurrency` at the caller and says nothing about a group declared in a called
workflow, so moving it there would bet a guard that only matters during a rare
race on undocumented behaviour — and if it turned out to be a no-op, all three
consumers would lose it silently and simultaneously.

**The `secrets` context is not available to an `if:` condition.** Not at job
level and not at step level. Checking whether a secret was supplied means
copying it to a job-level `env` first and testing `env.X != ''`, which is what
`_release-please.yaml` does to decide whether to mint an application token.

**A skipped step's outputs are empty strings, not null.** That is load-bearing:
`steps.app-token.outputs.token || github.token` is the whole token fallback. It
works precisely because the skipped step yields `''`.

**A `./` reference inside a reusable workflow does not mean what it means in an
ordinary one.** In `lint.yaml`, `./actions/setup-node` resolves against this
repository and is the documented way to reference a sibling action. Inside a
workflow called through `workflow_call`, the same string resolves against the
checkout sitting in the workspace — and that checkout belongs to the _caller_,
so it would look for the action in the consuming repository and not find it.
GitHub documents `./` for referencing a workflow in the same repository and says
nothing either way about an action referenced from inside a called workflow.
That is why `_publish-npm.yaml` inlines `actions/setup-node@v7.0.0` and its
`npm ci` rather than calling the composite next door. Do not "de-duplicate" it.

Naming the composite by tag is the other obvious fix and is worse: it pins this
repository to a version of itself that does not exist until the release carrying
the change is cut.

**`_publish-npm.yaml` declares `permissions` and `_release-please.yaml` does
not, and the difference is not an inconsistency.** A called workflow may always
request less than its caller granted; requesting more fails the run. So a block
is safe exactly when every caller needs the same scopes. Publishing callers all
need `contents: read` and `id-token: write`, so naming them turns a forgotten
scope into an immediate error instead of an npm-side refusal. Release callers do
not agree with each other — one supplying an application token leaves
`GITHUB_TOKEN` on `contents: read`, one falling back needs three write scopes —
so any block there would break one kind.

**Hyphens are fine in `uses:` refs and property names.** `steps.app-token`,
`inputs.auto-merge` and `secrets.private-key` all parse as property access, not
subtraction. There is no need to rename anything to underscores.

**`npm ci` takes `--ignore-scripts` as a flag, not a value.** The two forms
cannot be collapsed into one interpolated command line, which is why the
composite action branches in shell instead of interpolating the flag.

**This repository's own `release-please.yaml` pins a tag, not `./`.** So a
freshly cut release is not what proposes the next one — Renovate has to bump the
pin first. Leave it: it is the same lag consumers have, and it is the only place
that lag is visible from the inside.
