#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
usage: render_formula.sh --tag <git-tag> --archive <path-to-tag-archive> --output <formula-path> [--archive-url <url>]

Examples:
  ./packaging/homebrew/render_formula.sh \
    --tag v0.1.0 \
    --archive /tmp/swift-nest-v0.1.0.tar.gz \
    --output /tmp/homebrew-swiftnest/Formula/swiftnest.rb
EOF
}

sha256_file() {
  file_path=$1
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file_path" | awk '{print $1}'
    return 0
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file_path" | awk '{print $1}'
    return 0
  fi

  echo "error: need shasum or sha256sum to compute SHA256." >&2
  exit 1
}

TAG=""
ARCHIVE_PATH=""
OUTPUT_PATH=""
ARCHIVE_URL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --tag)
      TAG=${2:-}
      shift 2
      ;;
    --archive)
      ARCHIVE_PATH=${2:-}
      shift 2
      ;;
    --output)
      OUTPUT_PATH=${2:-}
      shift 2
      ;;
    --archive-url)
      ARCHIVE_URL=${2:-}
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[ -n "$TAG" ] || { echo "error: --tag is required." >&2; usage >&2; exit 1; }
[ -n "$ARCHIVE_PATH" ] || { echo "error: --archive is required." >&2; usage >&2; exit 1; }
[ -n "$OUTPUT_PATH" ] || { echo "error: --output is required." >&2; usage >&2; exit 1; }
[ -f "$ARCHIVE_PATH" ] || { echo "error: archive not found: $ARCHIVE_PATH" >&2; exit 1; }

if [ -z "$ARCHIVE_URL" ]; then
  ARCHIVE_URL="https://github.com/oozoofrog/swift-nest/archive/refs/tags/$TAG.tar.gz"
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
TEMPLATE_PATH="$SCRIPT_DIR/swiftnest.rb.template"
[ -f "$TEMPLATE_PATH" ] || { echo "error: template not found: $TEMPLATE_PATH" >&2; exit 1; }

SHA256=$(sha256_file "$ARCHIVE_PATH")
mkdir -p "$(dirname -- "$OUTPUT_PATH")"

sed \
  -e "s#__SWIFTNEST_RELEASE_TAG__#$TAG#g" \
  -e "s#__SWIFTNEST_RELEASE_SHA256__#$SHA256#g" \
  -e "s#https://github.com/oozoofrog/swift-nest/archive/refs/tags/$TAG.tar.gz#$ARCHIVE_URL#g" \
  "$TEMPLATE_PATH" > "$OUTPUT_PATH"

if command -v ruby >/dev/null 2>&1; then
  ruby -c "$OUTPUT_PATH" >/dev/null
fi

echo "Rendered formula: $OUTPUT_PATH"
echo "Release tag: $TAG"
echo "Archive URL: $ARCHIVE_URL"
echo "SHA256: $SHA256"
