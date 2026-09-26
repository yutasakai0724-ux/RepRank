import 'package:flutter/material.dart';

/// アプリ全体で共有するルート Navigator の GlobalKey。
/// MaterialApp.builder 内など、Navigator の外側（兄弟要素）に配置されたウィジェット
/// （例: RestTimerOverlay）から画面遷移する際に使う。
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// 現在選択中のメインタブ（0:分析 1:カレンダー 2:ルーチン 3:設定）。
/// 全画面共通のフッターと MainNavigation が共有する。
final ValueNotifier<int> mainTabIndex = ValueNotifier<int>(0);

/// 全画面共通フッターを表示するか（メイン画面が出ている間だけ true。
/// プライバシー同意・チュートリアルなどの全画面表示中は false にする）。
final ValueNotifier<bool> mainFooterVisible = ValueNotifier<bool>(false);

/// フッターのタブ押下: メイン画面まで戻って、そのタブを表示する。
void goToMainTab(int index) {
  mainTabIndex.value = index;
  rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
}
