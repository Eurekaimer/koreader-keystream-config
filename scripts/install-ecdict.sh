#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SOURCE_COMMIT=c1643ac0235c55445b07b0bbe551c0f26899afbc
SOURCE_URL="https://raw.githubusercontent.com/skywind3000/ECDICT/$SOURCE_COMMIT/stardict.7z"
SOURCE_SHA256=f370a0ecb58ada758d9dfe739db1667fd4ed87ed3055a4a7cb6c7054ecdf83d6
EXPECTED_ENTRIES=3402564
BOOK_NAME='ECDICT 英汉词典（增强词形）'

usage() {
    cat <<'EOF'
Usage: scripts/install-ecdict.sh [OPTIONS]

Download the pinned ECDICT dataset, convert its 3.4 million entries to
StarDict, and install it for KOReader. Existing unrelated dictionaries are
left untouched.

Options:
  --archive FILE  Use an already downloaded copy of the pinned stardict.7z
  --force         Rebuild and replace an existing ECDICT installation
  --dry-run       Print the planned source and destination without changing files
  -h, --help      Show this help

STARDICT_DATA_DIR overrides the default destination root:
${XDG_CONFIG_HOME:-$HOME/.config}/koreader/data/dict
EOF
}

log() {
    printf '==> %s\n' "$*"
}

warn() {
    printf 'warning: %s\n' "$*" >&2
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

archive_source=
force=0
dry_run=0
while (($#)); do
    case "$1" in
        --archive)
            (($# >= 2)) || die '--archive requires a file path'
            archive_source=$2
            shift
            ;;
        --force) force=1 ;;
        --dry-run) dry_run=1 ;;
        -h|--help)
            usage
            exit 0
            ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

if [[ -n "$archive_source" ]]; then
    archive_source=$(realpath -e -- "$archive_source") || die "Archive not found: $archive_source"
fi

dictionary_root=${STARDICT_DATA_DIR:-"${XDG_CONFIG_HOME:-$HOME/.config}/koreader/data/dict"}
target="$dictionary_root/ecdict-en-zh"
ifo="$target/ecdict-en-zh.ifo"
source_marker="$target/.ecdict-source"
license_source="$SCRIPT_DIR/../licenses/ECDICT-LICENSE"
[[ -f "$license_source" ]] || die "Missing ECDICT license: $license_source"

valid_install() {
    [[ -s "$target/ecdict-en-zh.dict" && -s "$target/ecdict-en-zh.idx" && -f "$ifo" &&
        -f "$target/LICENSE-ECDICT" && -f "$source_marker" ]] &&
        grep -Fqx "bookname=$BOOK_NAME" "$ifo" &&
        grep -Fqx "wordcount=$EXPECTED_ENTRIES" "$ifo" &&
        grep -Fqx "commit=$SOURCE_COMMIT" "$source_marker" &&
        grep -Fqx "sha256=$SOURCE_SHA256" "$source_marker"
}

if (( ! force )) && valid_install; then
    log "ECDICT is already installed at $target"
    exit 0
fi

if (( dry_run )); then
    if [[ -n "$archive_source" ]]; then
        log "Would verify and use $archive_source"
    else
        log "Would download $SOURCE_URL"
    fi
    log "Would build $EXPECTED_ENTRIES StarDict entries and replace $target"
    exit 0
fi

require_command 7z
require_command python3
require_command sha256sum
[[ -n "$archive_source" ]] || require_command curl

mkdir -p -- "$dictionary_root"
work_dir=$(mktemp -d)
stage_parent=$(mktemp -d "$dictionary_root/.ecdict-install.XXXXXX")
backup=
cleanup() {
    rm -rf -- "$work_dir" "$stage_parent"
    if [[ -n "$backup" && -e "$backup" && ! -e "$target" ]]; then
        mv -- "$backup" "$target"
    fi
}
trap cleanup EXIT INT TERM

archive="$work_dir/stardict.7z"
if [[ -n "$archive_source" ]]; then
    log "Copying pinned ECDICT archive"
    cp -- "$archive_source" "$archive"
else
    log "Downloading pinned ECDICT archive ($SOURCE_COMMIT)"
    curl --fail --location --retry 3 --output "$archive" "$SOURCE_URL"
fi

read -r actual_sha256 _ < <(sha256sum "$archive")
[[ "$actual_sha256" == "$SOURCE_SHA256" ]] ||
    die "ECDICT archive checksum mismatch: expected $SOURCE_SHA256, got $actual_sha256"

source_dir="$work_dir/source"
mkdir -- "$source_dir"
log 'Extracting stardict.csv'
7z e -y -o"$source_dir" "$archive" stardict.csv >/dev/null
[[ -s "$source_dir/stardict.csv" ]] || die 'ECDICT archive did not contain stardict.csv'

stage="$stage_parent/ecdict-en-zh"
log 'Converting ECDICT to KOReader StarDict format'
python3 "$SCRIPT_DIR/ecdict_to_stardict.py" \
    "$source_dir/stardict.csv" "$stage" --expected-count "$EXPECTED_ENTRIES"
printf '%s\n' \
    "commit=$SOURCE_COMMIT" \
    "sha256=$SOURCE_SHA256" \
    > "$stage/.ecdict-source"
cp -- "$license_source" "$stage/LICENSE-ECDICT"

sdcv=
if command -v sdcv >/dev/null 2>&1; then
    sdcv=$(command -v sdcv)
elif [[ -x /usr/lib/koreader/sdcv ]]; then
    sdcv=/usr/lib/koreader/sdcv
fi
if [[ -n "$sdcv" ]]; then
    log "Validating the generated dictionary with $(basename -- "$sdcv")"
    sdcv_dir=$(dirname -- "$sdcv")
    lookup=$(
        cd -- "$sdcv_dir"
        "$sdcv" --utf8-input --utf8-output --json-output --non-interactive \
            --data-dir "$stage" --exact-search -- computational
    ) || die 'Generated dictionary could not look up computational'
    [[ "$lookup" == *'计算的'* ]] || die 'Generated dictionary returned an unexpected result for computational'
else
    warn 'sdcv was not found; skipping the lookup smoke test'
fi

if [[ -e "$target" ]]; then
    backup="$dictionary_root/.ecdict-en-zh.previous.$$"
    mv -- "$target" "$backup"
fi
if ! mv -- "$stage" "$target"; then
    [[ -z "$backup" || ! -e "$backup" ]] || mv -- "$backup" "$target"
    die "Could not install ECDICT at $target"
fi
if [[ -n "$backup" ]]; then
    rm -rf -- "$backup"
    backup=
fi

log "Installed $BOOK_NAME at $target"
warn 'Restart KOReader before looking up words; keep “Use external dictionary” disabled.'
