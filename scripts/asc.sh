#!/bin/zsh
# App Store Connect CLI 的项目入口, 配置与凭据不放进仓库
set -euo pipefail
if ! command -v asc >/dev/null; then
  print -u2 '请先安装 App Store Connect CLI: brew install asc'
  exit 1
fi
export ASC_CONFIG_PATH=${ASC_CONFIG_PATH:-$HOME/.config/baby-days/asc.json}
export ASC_WEB_SESSION_CACHE_DIR=${ASC_WEB_SESSION_CACHE_DIR:-$HOME/Library/Caches/baby-days/asc-web}
export ASC_APP_ID=6817262216
export ASC_TELEMETRY_DISABLED=1
exec asc "$@"
