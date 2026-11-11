#!/bin/zsh
# Exercise the same sync implementation on macOS or an explicitly selected simulator.
set -euo pipefail
ROOT=${0:A:h:h}
cd "$ROOT"
test_platform=${1:-macos}
test_device=${2:-}
test_arch=$(uname -m)
test_cache=$HOME/Library/Caches/baby-days/Tests
case $test_platform in
  macos) test_sdk=macosx; test_target=$test_arch-apple-macos14 ;;
  ios) test_sdk=iphonesimulator; test_target=$test_arch-apple-ios17-simulator ;;
  tvos) test_sdk=appletvsimulator; test_target=$test_arch-apple-tvos17-simulator ;;
  *) print -u2 '用法: scripts/test-sync.sh macos|ios|tvos [模拟器 UDID]'; exit 1 ;;
esac
if [[ $test_platform != macos && -z $test_device ]]; then
  print -u2 '请明确指定测试模拟器, 避免操作用户的其他模拟器'
  exit 1
fi
mkdir -p "$test_cache"
test_sdk_path=$(xcrun --sdk "$test_sdk" --show-sdk-path)
test_executable=$test_cache/cloud-sync-$test_platform
xcrun --sdk "$test_sdk" swiftc -swift-version 5 -parse-as-library \
  -target "$test_target" -sdk "$test_sdk_path" \
  -module-cache-path "$test_cache/ModuleCache-$test_platform" \
  Shared/BabyAge.swift Shared/BabyProfile.swift Shared/BabySyncRecord.swift Shared/Zodiac.swift \
  Shared/BabyCloudSync.swift Tests/CloudSyncTests.swift -o "$test_executable"
if [[ $test_platform == macos ]]; then
  "$test_executable"
else
  xcrun simctl spawn "$test_device" "$test_executable"
fi
