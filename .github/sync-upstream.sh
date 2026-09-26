#!/usr/bin/env bash
# Fork-side upstream sync driver (.github/sync-upstream.sh).
#
# Mechanical policy per AGENTS.md maintenance rules:
#   - merge upstream into the fork branch;
#   - conflicts on fork-owned files resolve to OUR side, everything else to
#     upstream's side;
#   - owned files must NEVER change as a result of a merge — even when upstream
#     modified them WITHOUT a conflict — so after any produced merge commit,
#     every owned path is restored to its pre-merge content and the merge
#     commit is amended. Owned files upstream deleted are resurrected too.
#   - never commit an unresolved merge: if conflicts cannot be resolved
#     mechanically, exit 1 and leave the tree for the caller to inspect
#     (the workflow files a "Upstream sync failed" issue).
#
# Outputs (GitHub Actions none, stdout always):
#   MERGE_STATE=clean|resolved|noop   human-readable decision
#   merged=true|false                 written to $GITHUB_OUTPUT when present
#
# Exit codes: 0 = noop / clean / resolved (merge completed);
#             1 = unresolved conflicts (or unusable state), nothing committed.
#
# Env overrides, all optional (sandbox testing):
#   UPSTREAM_REPO    default https://github.com/Vencord/Installer.git
#   UPSTREAM_BRANCH  default main
#   TARGET_BRANCH    default feat/vencord-main
#   OWNED            default "vencord-setup.ps1 AGENTS.md README.md
#                     .github/sync-upstream.sh .github/workflows/sync-upstream.yml"

set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/Vencord/Installer.git}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
TARGET_BRANCH="${TARGET_BRANCH:-feat/vencord-main}"
OWNED="${OWNED:-vencord-setup.ps1 AGENTS.md README.md .github/sync-upstream.sh .github/workflows/sync-upstream.yml}"

# Write the merge decision as step outputs when running under GitHub Actions.
# Locally $GITHUB_OUTPUT is unset, so the table stays empty: graceful no-op.
emit_merged() {
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf 'merged=%s\n' "$1" >> "$GITHUB_OUTPUT"
  fi
}

CURRENT_BRANCH="$(git branch --show-current)"
if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]; then
  printf 'ERROR: on branch %r, expected %r\n' "$CURRENT_BRANCH" "$TARGET_BRANCH" >&2
  exit 1
fi

# Tolerate an upstream remote that already exists.
if git remote get-url upstream >/dev/null 2>&1; then
  git remote set-url upstream "$UPSTREAM_REPO"
else
  git remote add upstream "$UPSTREAM_REPO"
fi
git fetch upstream --tags

PRE="$(git rev-parse HEAD)"

# Nothing to do: upstream ref identical to current head.
if [ "$(git rev-parse "refs/remotes/upstream/$UPSTREAM_BRANCH" 2>/dev/null || true)" = "$PRE" ]; then
  echo "MERGE_STATE=noop"
  emit_merged "false"
  exit 0
fi

MODE="clean"
# --no-ff guarantees any effective merge is a merge commit WE created, which
# the owned-file amend below requires (a fast-forward would leave no commit
# of ours to amend).
if ! git merge --no-edit --no-ff "refs/remotes/upstream/$UPSTREAM_BRANCH"; then
  MODE="resolved"

  # Owned files resolve to OUR side (tolerates owned paths that are not
  # conflicted or not present upstream).
  for path in $OWNED; do
    if git checkout --ours -- "$path" 2>/dev/null; then
      git add -- "$path"
    fi
  done

  # Every remaining unmerged path resolves to upstream's side.
  for path in $(git diff --name-only --diff-filter=U || true); do
    if git checkout --theirs -- "$path" 2>/dev/null; then
      git add -- "$path"
    fi
  done

  if [ -n "$(git diff --name-only --diff-filter=U || true)" ]; then
    printf 'ERROR: unresolved conflicts remain after resolution:\n%s\n' \
      "$(git diff --name-only --diff-filter=U)" >&2
    exit 1
  fi

  git commit --no-edit
fi

if [ "$(git rev-parse HEAD)" = "$PRE" ]; then
  echo "MERGE_STATE=noop"
  emit_merged "false"
  exit 0
fi

# Policy enforcement for BOTH clean and resolved merges: owned files must
# never change as a result of a merge. Also resurrects owned files that
# upstream deleted.
for path in $OWNED; do
  git checkout "$PRE" -- "$path" 2>/dev/null || true
done
git commit --amend --no-edit

echo "MERGE_STATE=$MODE"
emit_merged "true"
exit 0
