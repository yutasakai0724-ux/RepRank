#!/usr/bin/env bash
# =============================================================
# Rep Rank — リリースビルドスクリプト
# 使い方:
#   chmod +x scripts/build_release.sh
#   ./scripts/build_release.sh
#
# 実行前に確認すること:
#   1. Xcode で Bundle ID と署名チームが設定済みであること
#   2. Apple Developer アカウントで Provisioning Profile が有効であること
#   3. flutter pub get が通ること
# =============================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "================================================"
echo "  Rep Rank — Release Build"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================"

# ── 1. 依存関係を最新化 ────────────────────────────────────
echo ""
echo "▶ flutter pub get..."
flutter pub get

# ── 2. コード生成が必要な場合は build_runner を実行 ──────
# flutter pub run build_runner build --delete-conflicting-outputs

# ── 3. クリーンビルド ────────────────────────────────────
echo ""
echo "▶ flutter clean..."
flutter clean
flutter pub get

# ── 4. リリース IPA をビルド ─────────────────────────────
echo ""
echo "▶ flutter build ipa --release..."
flutter build ipa --release

IPA_DIR="$PROJECT_DIR/build/ios/ipa"
IPA_FILE=$(find "$IPA_DIR" -name "*.ipa" 2>/dev/null | head -n 1)

if [ -z "$IPA_FILE" ]; then
  echo ""
  echo "⚠️  IPA ファイルが見つかりませんでした。"
  echo "   署名設定を確認してください。"
  exit 1
fi

echo ""
echo "================================================"
echo "  ✅ ビルド成功！"
echo "  IPA: $IPA_FILE"
echo "================================================"
echo ""
echo "次のステップ — TestFlight にアップロードする方法:"
echo ""
echo "  方法 A: Xcode の Organizer を使う（推奨）"
echo "    1. Xcode > Window > Organizer を開く"
echo "    2. 生成された Archive を選択"
echo "    3. 'Distribute App' → 'App Store Connect' を選択"
echo ""
echo "  方法 B: xcrun altool でコマンドラインからアップロード"
echo "    xcrun altool --upload-app \\"
echo "      --type ios \\"
echo "      --file \"$IPA_FILE\" \\"
echo "      --username \"your@apple.id\" \\"
echo "      --password \"@keychain:AC_PASSWORD\""
echo ""
echo "  ※ App Store Connect の App-Specific Password は"
echo "     https://appleid.apple.com で発行できます。"
echo ""
