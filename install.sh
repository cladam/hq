#!/bin/sh
set -e

REPO="cladam/hq"
INSTALL_DIR="${HQ_INSTALL_DIR:-$HOME/.local/bin}"
TMP_DIR=""

main() {
  need_cmd curl
  need_cmd tar
  need_cmd uname

  TMP_DIR="$(mktemp -d)"

  local os arch artifact
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Linux)  os="linux" ;;
    Darwin) os="macos" ;;
    *)      err "unsupported OS: $os" ;;
  esac

  case "$arch" in
    x86_64|amd64)  arch="x86_64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)             err "unsupported architecture: $arch" ;;
  esac

  artifact="hq-${os}-${arch}"
  local url="https://github.com/${REPO}/releases/latest/download/${artifact}.tar.gz"

  echo "Installing hq..."
  echo "  os:      $os"
  echo "  arch:    $arch"
  echo "  install: $INSTALL_DIR"
  echo ""

  curl -fsSL "$url" -o "$TMP_DIR/${artifact}.tar.gz" \
    || err "download failed — check that a release exists for ${artifact}"

  tar xzf "$TMP_DIR/${artifact}.tar.gz" -C "$TMP_DIR"

  mkdir -p "$INSTALL_DIR"
  mv "$TMP_DIR/hq" "$INSTALL_DIR/hq"
  chmod +x "$INSTALL_DIR/hq"

  echo "hq installed to $INSTALL_DIR/hq"

  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
    echo ""
    echo "Add hq to your PATH by adding this to your shell profile:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
  fi

  echo ""
  "$INSTALL_DIR/hq" --version
}

need_cmd() {
  if ! command -v "$1" > /dev/null 2>&1; then
    err "need '$1' (not found)"
  fi
}

err() {
  echo "error: $1" >&2
  exit 1
}

cleanup() {
  if [ -n "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR" 2>/dev/null
  fi
}

trap cleanup EXIT
main
