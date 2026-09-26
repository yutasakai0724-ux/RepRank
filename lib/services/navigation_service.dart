import 'package:flutter/material.dart';

/// アプリ全体で共有するルート Navigator の GlobalKey。
/// MaterialApp.builder 内など、Navigator の外側（兄弟要素）に配置されたウィジェット
/// （例: RestTimerOverlay）から画面遷移する際に使う。
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// 詳細画面（過去記録の編集画面など）のフッターからメインタブの切替を要求する。
/// MainNavigation が listen して該当タブへ切り替える。
final ValueNotifier<int?> mainTabRequest = ValueNotifier<int?>(null);
