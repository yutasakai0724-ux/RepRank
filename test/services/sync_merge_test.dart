import 'package:flutter_test/flutter_test.dart';
import 'package:RepRank/models/workout.dart';
import 'package:RepRank/services/settings_sync_service.dart';
import 'package:RepRank/services/sync_service.dart';

void main() {
  final t0 = DateTime(2026, 9, 1, 10);
  final t1 = DateTime(2026, 9, 1, 11);
  final t2 = DateTime(2026, 9, 1, 12);

  WorkoutSession s(DateTime? updated) => WorkoutSession(
        id: 'x',
        date: t0,
        startedAt: t0,
        updatedAt: updated,
      );

  group('記録の同期（削除の印）', () {
    test('削除より前に更新された記録は削除対象、後に編集された記録は残す', () {
      expect(SyncService.isEditedAfterDeletion(s(t0), t1), isFalse);
      expect(SyncService.isEditedAfterDeletion(s(t2), t1), isTrue);
      expect(SyncService.isEditedAfterDeletion(s(null), t1), isFalse);
      expect(SyncService.isEditedAfterDeletion(null, t1), isFalse);
    });

    test('端末とクラウドの削除の印は、新しい方の時刻でまとめる', () {
      final m = SyncService.mergeTombstones(
        {'a': t0, 'b': t2},
        {'a': t1, 'c': t0},
      );
      expect(m, {'a': t1, 'b': t2, 'c': t0});
    });

    test('差分同期の基準は最も新しい時刻', () {
      expect(SyncService.maxMark([t0, null, t2.toIso8601String(), t1]),
          t2.toIso8601String());
      expect(SyncService.maxMark([null]), isNull);
    });

    test('更新日時の新旧（なしは最も古い）', () {
      expect(SyncService.isNewer(s(t1), than: s(t0)), isTrue);
      expect(SyncService.isNewer(s(t0), than: s(t1)), isFalse);
      expect(SyncService.isNewer(s(t0), than: s(null)), isTrue);
      expect(SyncService.isNewer(s(null), than: s(t0)), isFalse);
    });
  });

  group('設定の同期', () {
    test('値ごとに新しい方を採用する', () {
      final m = SettingsSyncService.mergeSettings(
        {
          'body_weight': SettingValue(70.0, t2),
          'username': SettingValue('端末', t0),
        },
        {
          'body_weight': SettingValue(68.0, t1),
          'username': SettingValue('クラウド', t1),
          'gender': SettingValue('女性', t1),
        },
      );
      expect(m['body_weight']!.value, 70.0);
      expect(m['username']!.value, 'クラウド');
      expect(m['gender']!.value, '女性');
    });

    test('変更時刻の無い端末の初回はクラウド優先、ルーチンは名前で和集合', () {
      final m = SettingsSyncService.mergeSettings(
        {
          'body_weight': const SettingValue(80.0, null),
          'routines_v1': const SettingValue(
              ['{"name":"胸の日"}', '{"name":"脚の日"}'], null),
        },
        {
          'body_weight': SettingValue(75.0, t0),
          'routines_v1': SettingValue(['{"name":"胸の日","x":1}'], t0),
        },
      );
      expect(m['body_weight']!.value, 75.0);
      expect(m['routines_v1']!.value,
          ['{"name":"胸の日","x":1}', '{"name":"脚の日"}']);
    });

    test('追加した種目は和集合から削除済みを除く', () {
      final m = SettingsSyncService.mergeSettings(
        {
          'custom_exercises': SettingValue(['A|chest', '新名|back'], t2),
          'deleted_custom_exercises': SettingValue(['旧名'], t2),
        },
        {
          'custom_exercises': SettingValue(['A|legs', '旧名|back', 'B|arms'], t1),
          'deleted_custom_exercises': SettingValue(<String>[], t1),
        },
      );
      expect((m['custom_exercises']!.value as List).toSet(),
          {'A|chest', '新名|back', 'B|arms'});
    });
  });
}
