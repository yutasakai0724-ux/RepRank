// アプリ起動時に SQLite と SessionManager.init() が必要なため、
// ここではスモークテストとして main.dart が import できることのみ検証する。
// 実質的なロジックテストは test/models/ と test/services/ を参照。
import 'package:flutter_test/flutter_test.dart';
import 'package:kintorekioku/models/workout.dart';

void main() {
  test('defaultExercises list is not empty', () {
    expect(defaultExercises, isNotEmpty);
  });

  test('defaultExercises contains ベンチプレス', () {
    final names = defaultExercises.map((e) => e['name'] as String).toList();
    expect(names, contains('ベンチプレス'));
  });
}
