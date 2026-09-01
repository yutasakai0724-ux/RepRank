# ビルド方法早見表

目的別のビルド・実行コマンド一覧。バージョン番号確認は `grep "^version" pubspec.yaml`。

---

## 1. iOS シミュレータでの動作確認（コード修正後）

シミュレータの一覧を確認:

```bash
flutter devices
```

デバッグ実行（ホットリロード対応・最速）:

```bash
cd /Users/bossen/Desktop/kintorekioku
flutter run -d <シミュレータのID>
```

起動後、ターミナルで `r` を押すとホットリロード、`R` でホットリスタート。

ビルドのみ行いたい場合:

```bash
flutter build ios --simulator --debug
```

---

## 2. iOS 実機での動作確認

実機を USB 接続し、`設定 → プライバシーとセキュリティ → デベロッパモード` を有効化してから:

```bash
flutter devices
flutter run -d <実機のID>
```

リリース署名と同条件で確認したい場合（広告 ID・AdMob 動作確認など）:

```bash
flutter run --release -d <実機のID>
```

> Apple Sign-In や AdMob は **シミュレータでは正しく動作しない**機能があるため、これらの検証は実機必須。

---

## 3. Android エミュレータ・実機での動作確認

```bash
flutter devices
flutter run -d <デバイスID>
```

実機の場合は USB デバッグを有効化した上で接続。

デバッグ APK をビルドしてインストールのみ行う場合:

```bash
flutter build apk --debug
flutter install --debug
```

Play Store と同じ署名でのリリース確認:

```bash
flutter build apk --release
flutter install --release
# または
adb install build/app/outputs/flutter-apk/app-release.apk
```

> Play Store からインストール済みの場合は署名競合のため先にアンインストールが必要。

複数端末が接続されている場合は `-d <device-id>` で対象を指定。

---

## 4. App Store 提出用ビルド（iOS）

```bash
flutter clean
flutter pub get
flutter build ios --release
open ios/Runner.xcworkspace
```

Xcode 側の操作:
1. デバイスターゲットを **Any iOS Device (arm64)** に切り替え
2. **Product → Archive**
3. Organizer が開いたら **Distribute App → App Store Connect → Upload**

詳細手順は [release/ios.md](release/ios.md) を参照。

> ⚠️ **重要**: `pubspec.yaml` の `version` を編集しただけでは Xcode 側の設定は更新されない。
> Xcode は `ios/Flutter/Generated.xcconfig` の `FLUTTER_BUILD_NUMBER` を参照しており、
> このファイルは `flutter build ios` 等の実行時に pubspec.yaml から自動生成される。
> **Archive 前に必ず `flutter build ios --release` を実行**しないと、
> 古いビルド番号のままアーカイブされ App Store Connect で「使用済みビルド番号」エラーになる。

---

## 5. Google Play 提出用ビルド（Android）

```bash
cd /Users/bossen/Desktop/kintorekioku
flutter build appbundle --release
```

出力先: `build/app/outputs/bundle/release/app-release.aab`

Play Console の「本番」または「内部テスト」トラックにこの AAB をアップロードする。
詳細手順は [release/android.md](release/android.md) を参照。

---

## 6. Web での動作確認（簡易確認用）

```bash
flutter run -d chrome
```

> Firebase Auth・AdMob 等ネイティブ依存の機能は正しく動作しない場合がある。UI 確認用途のみ推奨。

---

## 目的別クイックリファレンス

| 目的 | コマンド |
|---|---|
| コード修正を素早く確認したい | `flutter run -d <device>` |
| リリース同等の挙動を確認したい（広告等） | `flutter run --release -d <device>` |
| ビルドが通るかだけ確認したい | `flutter build ios --simulator --debug` / `flutter build apk --debug` |
| App Store に提出する | `flutter build ios --release` → Xcode Archive |
| Play Store に提出する | `flutter build appbundle --release` |
