# AGENTS.md

Guidance for coding agents working in this repository.

## What this is

The shared CI surface for the `kanso-labs` organization: composite actions under
`actions/`, reusable workflows under `.github/workflows/` with a leading
underscore. [`README.md`](README.md) documents what each one does and how to
call it — read it first, and keep it correct when you change behaviour, because
it is what consumers read.

Consumers today:

| Repository                                                                               | Uses                   |
| ---------------------------------------------------------------------------------------- | ---------------------- |
| [home-assistant-applications](https://github.com/kanso-labs/home-assistant-applications) | `_release-please.yaml` |
| [kanso-ui](https://github.com/kanso-labs/kanso-ui)                                       | both                   |
| [unplugin-style-dictionary](https://github.com/kanso-labs/unplugin-style-dictionary)     | both                   |

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
- **Prettier formats the YAML, JSON and Markdown here**, and CI checks it. Run
  `npm run format` before pushing.

## Versioning

Consumers pin exact tags — `@v1.2.3`, never `@main` or `@v1`. Renovate opens the
bump pull requests.

That is what makes an error here survivable: it reaches one repository at a
time, in a pull request, rather than all three the moment it merges. Do not
"simplify" a consumer to `@main`.

release-please owns `version.txt` and `.release-please-manifest.json`. Nobody
edits either by hand. Pull requests are squash-merged, so the pull request title
is the only commit that reaches `main` and the single input to the release:
`feat` for a minor, `fix` for a patch, `!` for a breaking change, anything else
releases nothing.

**Breaking means "a consumer must edit something to keep working"** — removing
an input, renaming an output, changing a default. Exact pins mean nothing breaks
at release time. It breaks when Renovate's bump lands somewhere that never read
the changelog, so the major is the only warning that arrives with the change.

## Verifying a change

`npm run lint` and actionlint cover syntax. Neither proves a workflow does what
it claims — most of what has gone wrong in CI here was valid YAML.

**The composite action has a live smoke test.** `check-formatting` in
[`lint.yaml`](.github/workflows/lint.yaml) calls `./actions/setup-node`, so a
change that breaks it fails on the pull request rather than in whichever
repository next bumps its pin. That is the only job in this repository that
exercises it — keep it that way round, and do not "tidy" it into a plain
`actions/setup-node` step.

**A reusable workflow has no equivalent, so canary it by hand.**
`_release-please` only does anything on a push to a default branch with a real
token, which no pull request here reproduces. Before merging a change to it:

1. Push a branch here with the change.
2. On a branch in one consumer, flip its `uses:` ref to that branch.
3. Merge nothing — dispatch or push the consumer branch and read the run.
4. Delete both branches, then merge the real pull request.

Do this in `unplugin-style-dictionary` rather than
`home-assistant-applications`: it has one package, no application token, and
nothing installed depends on its releases.

## Traps

**A called workflow cannot request more permissions than its caller granted.**
Not a silent intersection — the run fails outright with a message naming the
scope. That is why `_release-please.yaml` declares no `permissions` block at
all: its callers do not need the same ones, because a caller supplying an
application token leaves `GITHUB_TOKEN` on `contents: read` while one falling
back to it needs three write scopes. Adding a block here would break the first
kind.

**The `secrets` context is not available to an `if:` condition.** Not at job
level and not at step level. Checking whether a secret was supplied means
copying it to a job-level `env` first and testing `env.X != ''`, which is what
`_release-please.yaml` does to decide whether to mint an application token.

**A skipped step's outputs are empty strings, not null.** That is load-bearing:
`steps.app-token.outputs.token || github.token` is the whole token fallback. It
works precisely because the skipped step yields `''`.

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
