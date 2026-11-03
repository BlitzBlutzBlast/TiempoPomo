#!/usr/bin/env bash
# Tiempo Pomo must never touch the network. This fails the build if:
#   1. the source uses a networking API,
#   2. the compiled binary imports networking symbols or frameworks, or
#   3. the signed app is not sandboxed, or holds a network entitlement.
#
#   scripts/check_no_network.sh                      # source checks only
#   scripts/check_no_network.sh "dist/Tiempo Pomo.app"   # source + binary + entitlements
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

echo "==> No-network check: source"
banned='URLSession|URLRequest|NSURLConnection|NWConnection|NWListener|NWBrowser|NWPathMonitor|import Network|CFNetwork|CFSocket|CFStream|Socket\(|socket\(|getaddrinfo|WKWebView|WebKit|Data\(contentsOf|String\(contentsOf|Sparkle|https?://'
if grep -rnE "$banned" Sources; then
  echo "error: networking API found in Sources/ (see above)" >&2
  fail=1
fi

APP="${1:-}"
if [[ -n "$APP" ]]; then
  BIN="$APP/Contents/MacOS/TiempoPomo"

  echo "==> No-network check: binary"
  if otool -L "$BIN" | grep -E "Network.framework|CFNetwork|WebKit"; then
    echo "error: binary links a networking framework" >&2
    fail=1
  fi
  if nm -u "$BIN" 2>/dev/null | grep -E "URLSession|NSURLConnection|NSURLRequest|_nw_|_socket$|_connect$|_getaddrinfo$|CFSocket|CFStreamCreatePairWithSocket"; then
    echo "error: binary imports networking symbols" >&2
    fail=1
  fi

  echo "==> No-network check: entitlements"
  ENT="$(codesign -d --entitlements - --xml "$APP" 2>/dev/null || true)"
  if ! grep -q "com.apple.security.app-sandbox" <<<"$ENT"; then
    echo "error: app is not sandboxed" >&2
    fail=1
  fi
  if grep -E "com.apple.security.network|temporary-exception" <<<"$ENT"; then
    echo "error: app holds a network or exception entitlement" >&2
    fail=1
  fi
fi

if [[ $fail -ne 0 ]]; then exit 1; fi
echo "==> No-network check passed"
