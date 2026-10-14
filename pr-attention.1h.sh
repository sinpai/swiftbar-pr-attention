#!/bin/bash
# SwiftBar plugin that runs every hour (the ".1h." in the file name).
# Lists your open GitHub PRs that have unresolved review threads where someone
# else wrote the last comment, or failing CI checks.
#
# <bitbar.title>PRs needing attention</bitbar.title>
# <bitbar.desc>Your open PRs with unresolved review comments or failing checks</bitbar.desc>
# <bitbar.author.github>sinpai</bitbar.author.github>
# <bitbar.dependencies>gh,jq</bitbar.dependencies>

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# A check whose only failed steps are in this list is not reported.
# "Run bundle-audit" fails on branches that are behind master, which is not a test failure.
# Set IGNORE_STEPS=() to report every failure.
IGNORE_STEPS=("Run bundle-audit")

QUERY='{
  viewer { login }
  search(query: "is:pr is:open author:@me archived:false", type: ISSUE, first: 50) {
    nodes { ... on PullRequest {
      number title url repository { name }
      reviewThreads(first: 100) { nodes { isResolved comments(last: 1) { nodes { author { login } } } } }
      commits(last: 1) { nodes { commit { statusCheckRollup { contexts(first: 50) { nodes {
        ... on CheckRun { name conclusion steps(first: 50) { nodes { name conclusion } } }
        ... on StatusContext { context state }
      } } } } } }
    } }
  }
}'

if ! DATA=$(gh api graphql -f query="$QUERY" 2>&1); then
  echo "PR ⚠ | color=orange"
  echo "---"
  echo "$DATA" | head -5 | tr '|' '/'
  echo "Refresh | refresh=true"
  exit 0
fi

echo "$DATA" | jq -r '
  def bad: test("^(FAILURE|ERROR|TIMED_OUT|CANCELLED|ACTION_REQUIRED|STARTUP_FAILURE)$");
  $ARGS.positional as $ignore
  | .data.viewer.login as $me
  | [ .data.search.nodes[] | {
      label: "\(.repository.name)#\(.number) \(.title | gsub("\\|"; "/") | if length > 60 then .[:57] + "..." else . end)",
      url,
      comments: [ .reviewThreads.nodes[] | select(.isResolved | not)
                  | .comments.nodes[0].author.login // "ghost" | select(. != $me) ],
      failed: ([ .commits.nodes[0].commit.statusCheckRollup.contexts.nodes[]?
                 | select(.conclusion // .state // "" | bad)
                 | [ .steps.nodes[]? | select(.conclusion // "" | bad) | .name ] as $steps
                 | ($steps - $ignore) as $real
                 | if $steps == [] then (.name // .context)
                   elif $real == [] then empty
                   else "\(.name): \($real | join(", "))" end ] | unique)
    } ]
  | map(select(.comments != [])) as $c
  | map(select(.failed != [])) as $f
  | ([$c[], $f[]] | map(.url) | unique | length) as $n
  | (if $n == 0 then "PR ✓ | color=gray" else "PR \($n) | color=red" end),
    "---",
    (if $c != [] then "Unresolved comments | color=gray",
       ($c[] | "\(.label) (\(.comments | length)) | href=\(.url)") else empty end),
    (if $f != [] then "Failing checks | color=gray",
       ($f[] | "\(.label) (\(.failed | join("; "))) | href=\(.url)/checks") else empty end)
' --args "${IGNORE_STEPS[@]}"
echo "---"
echo "Checked $(date +%H:%M) | color=gray"
echo "Refresh | refresh=true"
