# shellcheck shell=bash
# ABOUTME: Shared library for demo/*.sh — color/badge helpers + context display.
# ABOUTME: Source this from every demo script; never run it directly.

# Color/badge palette. Bright ANSI bg colors with bold white/black text.
readonly _RST=$'\033[0m'
readonly _BOLD=$'\033[1m'
readonly _DIM=$'\033[2m'
readonly _UL=$'\033[4m'

readonly _FG_RED=$'\033[31m'
readonly _FG_GRN=$'\033[32m'
readonly _FG_YEL=$'\033[33m'
readonly _FG_BLU=$'\033[34m'
readonly _FG_MAG=$'\033[35m'
readonly _FG_CYN=$'\033[36m'
readonly _FG_WHT=$'\033[97m'

readonly _BG_RED=$'\033[41m'
readonly _BG_GRN=$'\033[42m'
readonly _BG_YEL=$'\033[43m'
readonly _BG_BLU=$'\033[44m'
readonly _BG_MAG=$'\033[45m'
readonly _BG_CYN=$'\033[46m'

# Badges — bright bg, bold white text, padding for readability.
badge_success() { printf '%b SUCCESS %b' "${_BOLD}${_FG_WHT}${_BG_GRN}" "${_RST}"; }
badge_failure() { printf '%b FAILURE %b' "${_BOLD}${_FG_WHT}${_BG_RED}" "${_RST}"; }
badge_access()  { printf '%b ACCESS  %b' "${_BOLD}${_FG_WHT}${_BG_GRN}" "${_RST}"; }
badge_deny()    { printf '%b  DENY   %b' "${_BOLD}${_FG_WHT}${_BG_RED}" "${_RST}"; }
badge_info()    { printf '%b  INFO   %b' "${_BOLD}${_FG_WHT}${_BG_BLU}" "${_RST}"; }
badge_warn()    { printf '%b  WARN   %b' "${_BOLD}\033[30m${_BG_YEL}" "${_RST}"; }
badge_pending() { printf '%b PENDING %b' "${_BOLD}\033[30m${_BG_YEL}" "${_RST}"; }

# Big header banner — top of every demo
banner() {
    local title="$1"
    local width=72
    local pad=$(( (width - ${#title} - 2) / 2 ))
    printf '\n%b' "${_BOLD}${_FG_CYN}"
    printf '═%.0s' $(seq 1 "${width}"); printf '\n'
    printf '%*s' "$pad" ''
    printf ' %s \n' "$title"
    printf '═%.0s' $(seq 1 "${width}"); printf '\n'
    printf '%b\n' "${_RST}"
}

# Section divider mid-script
section() {
    printf '\n%b── %s %b\n' "${_BOLD}${_FG_CYN}" "$1" "${_RST}"
}

# Show what command we're about to run, then run it (visible narration)
narrate() {
    printf '%b$ %s%b\n' "${_DIM}${_FG_WHT}" "$*" "${_RST}"
}

run() {
    narrate "$@"
    "$@"
}

# Print a labeled line with a badge prefix
ok()    { printf '%s %s\n' "$(badge_success)" "$1"; }
fail()  { printf '%s %s\n' "$(badge_failure)" "$1"; }
allow() { printf '%s %s\n' "$(badge_access)"  "$1"; }
deny()  { printf '%s %s\n' "$(badge_deny)"    "$1"; }
info()  { printf '%s %s\n' "$(badge_info)"    "$1"; }
warn()  { printf '%s %s\n' "$(badge_warn)"    "$1"; }
pend()  { printf '%s %s\n' "$(badge_pending)" "$1"; }

# Show the kubectl context at the top of every demo so the audience knows
# exactly which cluster they're hitting.
context_card() {
    local ctx cluster ns user
    ctx="$(kubectl config current-context 2>/dev/null || echo '(none)')"
    cluster="$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null || echo '(none)')"
    ns="$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || echo 'default')"
    user="$(kubectl config view --minify -o jsonpath='{.users[0].name}' 2>/dev/null || echo '(none)')"
    [[ -z "${ns}" ]] && ns="default"

    printf '%b┌─ kubectl context ──────────────────────────────────────────────────┐%b\n' "${_FG_CYN}" "${_RST}"
    printf '%b│%b %bcontext:%b   %s\n' "${_FG_CYN}" "${_RST}" "${_BOLD}" "${_RST}" "${ctx}"
    printf '%b│%b %bcluster:%b   %s\n' "${_FG_CYN}" "${_RST}" "${_BOLD}" "${_RST}" "${cluster}"
    printf '%b│%b %buser:%b      %s\n' "${_FG_CYN}" "${_RST}" "${_BOLD}" "${_RST}" "${user}"
    printf '%b│%b %bnamespace:%b %s\n' "${_FG_CYN}" "${_RST}" "${_BOLD}" "${_RST}" "${ns}"
    printf '%b└────────────────────────────────────────────────────────────────────┘%b\n' "${_FG_CYN}" "${_RST}"
}

# Optional pause for live narration. Skipped if NO_PAUSE=1 set in env.
pause() {
    [[ "${NO_PAUSE:-0}" == "1" ]] && return 0
    printf '\n%b[ press ENTER to continue ]%b ' "${_DIM}${_FG_WHT}" "${_RST}"
    read -r _
}

# Require a command on PATH; abort early with FAILURE badge if missing.
require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fail "required command not found: $1"
        exit 2
    fi
}

# Check a namespace exists; emit DENY badge if not (so the audience sees
# which namespace was missing, not a generic kubectl error).
require_ns() {
    if ! kubectl get ns "$1" >/dev/null 2>&1; then
        deny "namespace '$1' not found in current context"
        return 1
    fi
    return 0
}

# Count pods Running (or Succeeded/Completed — Job pods that finished cleanly)
# matching a selector. 'kubectl get pods' shows column 3 as the human-readable
# status string: "Running", "Completed" (= phase Succeeded), "CrashLoopBackOff",
# etc. We accept Running and Completed as healthy.
pods_running() {
    local ns="$1" selector="${2:-}"
    local args=("get" "pods" "-n" "$ns" "--no-headers")
    [[ -n "$selector" ]] && args+=("-l" "$selector")
    kubectl "${args[@]}" 2>/dev/null \
        | awk '$3=="Running" || $3=="Succeeded" || $3=="Completed"' | wc -l
}

pods_total() {
    local ns="$1" selector="${2:-}"
    local args=("get" "pods" "-n" "$ns" "--no-headers")
    [[ -n "$selector" ]] && args+=("-l" "$selector")
    kubectl "${args[@]}" 2>/dev/null | wc -l
}
