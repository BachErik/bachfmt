# bachfmt: interim shell version (only stage 1 of the detection chain).
# Will be replaced by the Go CLI with the same interface.
#
#   bachfmt --stdin <path>   read a buffer on stdin, print it formatted
#   bachfmt                  format the current repo
#
# Stage 1 only: if the project provides its own `treefmt` (devShell via
# direnv), use it. Otherwise leave the buffer unchanged — never fall back to
# a global style without opt-in.

# Run a command inside the project's direnv environment if possible, so
# this works no matter which environment the editor started us in.
in_project_env() {
    local dir=$1
    shift
    if command -v direnv >/dev/null 2>&1; then
        direnv exec "$dir" "$@"
    else
        "$@"
    fi
}

stdin_mode() {
    local path dir
    # Absolute, because we cd below (the file itself may not exist yet)
    path=$(realpath -m -- "$1")
    dir=$(dirname -- "$path")
    [[ -d $dir ]] || dir=$PWD

    # Globals on purpose: the EXIT trap runs after this function returned,
    # when its locals no longer exist (and `set -u` would abort).
    tmp=$(mktemp)
    out=$(mktemp)
    trap 'rm -f "${tmp:-}" "${out:-}"' EXIT
    cat >"$tmp"

    # treefmt finds its tree root (flake.nix) upwards from the working
    # directory, not from the file, and rejects paths outside of it. `direnv
    # exec` does not cd, and the editor may start us anywhere: so cd first.
    cd -- "$dir"

    # shellcheck disable=SC2016
    if in_project_env "$dir" bash -c 'command -v treefmt >/dev/null || exit 3; exec treefmt --stdin "$1"' _ "$path" \
        <"$tmp" >"$out" 2>/dev/null &&
        { [[ -s $out ]] || [[ ! -s $tmp ]]; }; then
        cat "$out"
    else
        # No project formatter, or it failed: hand the buffer back untouched
        cat "$tmp"
    fi
}

case "${1:-}" in
--stdin)
    [[ $# -eq 2 ]] || {
        echo "usage: bachfmt --stdin <path>" >&2
        exit 2
    }
    stdin_mode "$2"
    ;;
"")
    in_project_env "$PWD" bash -c 'command -v treefmt >/dev/null || { echo "bachfmt: no treefmt in this project (yet). The fallback comes with the Go CLI." >&2; exit 1; }; exec treefmt'
    ;;
-h | --help)
    echo "usage: bachfmt [--stdin <path>]"
    ;;
*)
    echo "bachfmt: unknown argument '$1' (try --stdin <path>)" >&2
    exit 2
    ;;
esac
