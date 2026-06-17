#!/bin/bash
#
# run-first-three.sh — One-shot runner for the first three pass-through demos.
#
# Builds and runs the first three demos in order:
#     1-simple      borrow the host's zlib
#     2-callback    host -> guest callbacks (reentry)
#     3-minizip     a whole library, running a stock minizip
#
# Usage:
#     export QEMU_BUILD_DIR=/path/to/qemu/build/release   # see README "Setup Environment"
#     ./run-first-three.sh
#
# Each demo is built (build.sh) and then run (run.sh). The script keeps going
# even if one demo fails, and prints a summary at the end.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ---- pretty output -----------------------------------------------------------
if [[ -t 1 ]]; then
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'
    GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
else
    BOLD=''; DIM=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; RESET=''
fi

info()  { printf '%s\n' "${BLUE}${BOLD}::${RESET} ${BOLD}$*${RESET}"; }
ok()    { printf '%s\n' "  ${GREEN}✔${RESET} $*"; }
warn()  { printf '%s\n' "  ${YELLOW}!${RESET} $*"; }
err()   { printf '%s\n' "  ${RED}✗${RESET} $*"; }
rule()  { printf '%s\n' "${DIM}────────────────────────────────────────────────────────────${RESET}"; }

# Run "$@", measure wall-clock time. Result seconds land in LAST_ELAPSED.
LAST_ELAPSED=""
time_cmd() {
    local start end rc
    start=$(date +%s.%N)
    "$@"
    rc=$?
    end=$(date +%s.%N)
    LAST_ELAPSED=$(awk -v s="$start" -v e="$end" 'BEGIN { printf "%.2f", e - s }')
    return "$rc"
}

# ---- the demos to run, in order ----------------------------------------------
DEMOS=(1-simple 2-callback 3-minizip)

# ---- preflight ---------------------------------------------------------------
printf '\n%s\n' "${BOLD}QEMU pass-through — run the first three demos${RESET}"
rule

if [[ -z "${QEMU_BUILD_DIR:-}" || ! -d "${QEMU_BUILD_DIR:-}" ]]; then
    err "QEMU_BUILD_DIR is not set or does not point to a directory."
    printf '%s\n' "    Build QEMU first, then e.g.:"
    printf '%s\n' "    ${DIM}export QEMU_BUILD_DIR=/home/user/qemu/build/release${RESET}"
    printf '%s\n' "    See README.md → \"Setup Environment\"."
    exit 1
fi
ok "QEMU_BUILD_DIR = ${QEMU_BUILD_DIR}"

if [[ ! -x "$QEMU_BUILD_DIR/qemu-x86_64" ]]; then
    warn "qemu-x86_64 not found under QEMU_BUILD_DIR — demos may fail to run."
fi
if [[ ! -f "$QEMU_BUILD_DIR/contrib/plugins/libpassthrough.so" ]]; then
    warn "libpassthrough.so not found — did you build QEMU with --enable-plugins?"
fi

# 3-minizip can pack the same archive three ways; we run and time them all so
# you can compare native vs. pass-through vs. plain emulation.
MINIZIP_MODES=(native passthrough emulated)
declare -A MINIZIP_TIME MINIZIP_STATUS

# ---- run each demo -----------------------------------------------------------
declare -a RESULTS
overall=0

for demo in "${DEMOS[@]}"; do
    dir="$SCRIPT_DIR/$demo"
    printf '\n'
    info "Demo ${BOLD}$demo${RESET}"
    rule

    if [[ ! -d "$dir" ]]; then
        err "directory not found: $dir"
        RESULTS+=("$demo|missing")
        overall=1
        continue
    fi

    # build
    printf '%s\n' "  ${DIM}building...${RESET}"
    if ( cd "$dir" && ./build.sh ); then
        ok "build succeeded"
    else
        err "build failed"
        RESULTS+=("$demo|build-failed")
        overall=1
        continue
    fi

    # run
    if [[ "$demo" == "3-minizip" ]]; then
        # Pre-generate the archive once so its creation cost is not charged to
        # whichever mode happens to run first.
        if [[ ! -f "$dir/archive.bin" ]]; then
            printf '%s\n' "  ${DIM}generating 512M test archive...${RESET}"
            python3 "$dir/GenerateArchive.py" "$dir/archive.bin" 512M
        fi

        demo_rc=0
        for mode in "${MINIZIP_MODES[@]}"; do
            printf '%s\n' "  ${DIM}running [${mode}]...${RESET}"
            if time_cmd bash -c 'cd "$1" && ./run.sh "$2"' _ "$dir" "$mode"; then
                ok "[${mode}] ok  ${DIM}(${LAST_ELAPSED}s)${RESET}"
                MINIZIP_STATUS[$mode]="ok"
            else
                err "[${mode}] failed  ${DIM}(${LAST_ELAPSED}s)${RESET}"
                MINIZIP_STATUS[$mode]="failed"
                demo_rc=1
            fi
            MINIZIP_TIME[$mode]="$LAST_ELAPSED"
        done

        if [[ "$demo_rc" -eq 0 ]]; then
            RESULTS+=("$demo|ok")
        else
            RESULTS+=("$demo|run-failed")
            overall=1
        fi
    else
        printf '%s\n' "  ${DIM}running...${RESET}"
        if ( cd "$dir" && ./run.sh ); then
            ok "run succeeded"
            RESULTS+=("$demo|ok")
        else
            err "run failed"
            RESULTS+=("$demo|run-failed")
            overall=1
        fi
    fi
done

# ---- summary -----------------------------------------------------------------
printf '\n'
info "Summary"
rule
for entry in "${RESULTS[@]}"; do
    name="${entry%%|*}"
    status="${entry##*|}"
    case "$status" in
        ok)           ok    "$name" ;;
        build-failed) err   "$name  (build failed)" ;;
        run-failed)   err   "$name  (run failed)" ;;
        missing)      err   "$name  (directory missing)" ;;
        *)            warn  "$name  ($status)" ;;
    esac
done
rule

# ---- 3-minizip timing comparison ---------------------------------------------
if [[ ${#MINIZIP_TIME[@]} -gt 0 ]]; then
    printf '\n'
    info "3-minizip timings (pack a 512M archive)"
    rule
    printf '  %-14s %10s   %s\n' "mode" "time (s)" "result"
    for mode in "${MINIZIP_MODES[@]}"; do
        t="${MINIZIP_TIME[$mode]:-—}"
        if [[ "${MINIZIP_STATUS[$mode]:-}" == "ok" ]]; then
            mark="${GREEN}✔${RESET}"
        else
            mark="${RED}✗${RESET}"
        fi
        printf '  %-14s %10s   %b\n' "$mode" "$t" "$mark"
    done
    rule
fi

if [[ "$overall" -eq 0 ]]; then
    printf '%s\n\n' "${GREEN}${BOLD}All demos passed.${RESET}"
else
    printf '%s\n\n' "${RED}${BOLD}Some demos failed — see the log above.${RESET}"
fi

exit "$overall"
