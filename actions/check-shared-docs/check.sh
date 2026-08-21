#!/usr/bin/env bash
#
# Compares every marked shared block in a Markdown file against the canonical
# copy shipped beside this script, and fails with a diff when the two disagree.
#
# The blocks are duplicated across the kanso-labs repositories on purpose, so
# that an agent handed one repository on its own still gets them. Duplication
# without a check is what let the same paragraph go stale in three files at
# once, which is the failure this exists to make loud.

set -euo pipefail

# Drops blank lines from the start and end of stdin, leaving any blank line in
# the middle of a block alone.
trim_blank_lines() {
  awk '
    NF { if (pending) { for (i = 0; i < pending; i++) print ""; pending = 0 }; started = 1; print; next }
    started { pending++ }
  '
}

file="${INPUT_FILE:?INPUT_FILE is required}"
blocks="${GITHUB_ACTION_PATH:-$(dirname "${BASH_SOURCE[0]}")}/blocks"

if [[ ! -f "${file}" ]]; then
  echo "::error::${file} does not exist"
  exit 1
fi

if [[ ! -d "${blocks}" ]]; then
  echo "::error::no blocks directory at ${blocks}"
  exit 1
fi

# conventions-core is the first four bullets and conventions carries all six, so
# that a repository with no package manifest can mark the part that applies to
# it while everyone else keeps one unbroken list. The overlap is real
# duplication, so assert it rather than trusting it: the shorter file has to be
# a prefix of the longer one, or the two have drifted inside this action and
# every repository would then be checked against a contradiction.
if [[ -f "${blocks}/conventions.md" && -f "${blocks}/conventions-core.md" ]]; then
  core_bytes="$(wc -c <"${blocks}/conventions-core.md")"
  if ! head -c "${core_bytes}" "${blocks}/conventions.md" | diff -q - "${blocks}/conventions-core.md" >/dev/null; then
    echo "::error::blocks/conventions-core.md is no longer a prefix of blocks/conventions.md"
    exit 1
  fi
fi

# An opening marker is `<!-- shared:some-name -->`. The closing form carries a
# slash immediately after the angle bracket, so it never matches this pattern
# and the two cannot be confused for one another.
#
# The marker has to be the whole line, which is what the extraction below
# matches on too. Anchoring here as well is what stops prose that mentions the
# syntax — this action's own README does, and so does the AGENTS.md it checks —
# from registering as a block that is not there.
names="$(grep -o '^<!-- shared:[a-z0-9-]\{1,\} -->$' "${file}" | sed 's|<!-- shared:\(.*\) -->|\1|' | sort -u || true)"

if [[ -z "${names}" ]]; then
  echo "::error file=${file}::${file} marks no shared blocks, so this action has nothing to check"
  exit 1
fi

status=0
checked=0

while IFS= read -r name; do
  canonical="${blocks}/${name}.md"

  if [[ ! -f "${canonical}" ]]; then
    echo "::error file=${file}::unknown shared block '${name}' — this action ships no blocks/${name}.md"
    status=1
    continue
  fi

  # A block that opens and never closes would otherwise swallow the rest of the
  # file and report a diff nobody can read.
  if ! grep -qF "<!-- /shared:${name} -->" "${file}"; then
    echo "::error file=${file}::shared block '${name}' opens but never closes"
    status=1
    continue
  fi

  actual="$(mktemp)"
  expected="$(mktemp)"

  # Rule order is what keeps the markers themselves out of the extract: the
  # closing marker clears the flag before the print rule sees it, and the
  # opening marker sets the flag only after.
  #
  # The blank lines are trimmed because Prettier and oxfmt both insert one
  # between an HTML comment and the block beside it. That spacing is the
  # formatter's to decide, not drift, so comparing it would fail every
  # correctly-formatted file.
  awk -v name="${name}" '
    $0 == "<!-- /shared:" name " -->" { inside = 0 }
    inside                            { print }
    $0 == "<!-- shared:" name " -->"  { inside = 1 }
  ' "${file}" | trim_blank_lines >"${actual}"

  trim_blank_lines <"${canonical}" >"${expected}"

  if diff -q "${expected}" "${actual}" >/dev/null; then
    checked=$((checked + 1))
  else
    echo "::error file=${file}::shared block '${name}' has drifted from the canonical copy"
    diff -u --label "canonical ${name}.md" "${expected}" --label "${file} (${name})" "${actual}" || true
    status=1
  fi

  rm -f "${actual}" "${expected}"
done <<<"${names}"

if [[ "${status}" -eq 0 ]]; then
  echo "${checked} shared block(s) in ${file} match the canonical copies."
fi

exit "${status}"
