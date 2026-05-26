import 'package:flutter_test/flutter_test.dart';
import 'package:kintorekioku/models/workout.dart';

void main() {
  // ── WorkoutSet ──────────────────────────────────────────────────
  group('WorkoutSet', () {
    test('oneRM: 0 reps returns weight', () {
      final s = WorkoutSet(setNumber: 1, weight: 100.0, reps: 0);
      expect(s.oneRM, 100.0);
    });

    test('oneRM: 1 rep returns weight * (1/40 + 1) = weight * 1.025', () {
      final s = WorkoutSet(setNumber: 1, weight: 100.0, reps: 1);
      expect(s.oneRM, closeTo(102.5, 0.001));
    });

    test('oneRM: 10 reps — Epley formula', () {
      // weight * reps / 40 + weight = 80 * 10 / 40 + 80 = 20 + 80 = 100
      final s = WorkoutSet(setNumber: 1, weight: 80.0, reps: 10);
      expect(s.oneRM, closeTo(100.0, 0.001));
    });

    test('weightInLbs converts correctly', () {
      final s = WorkoutSet(setNumber: 1, weight: 100.0, reps: 5);
      expect(s.weightInLbs, closeTo(220.462, 0.001));
    });

    test('toJson / fromJson round-trip', () {
      final original = WorkoutSet(
        setNumber: 2,
        weight: 60.0,
        reps: 8,
        recordedAt: DateTime(2026, 1, 15, 10, 30),
      );
      final json = original.toJson();
      final restored = WorkoutSet.fromJson(json);

      expect(restored.setNumber, original.setNumber);
      expect(restored.weight, original.weight);
      expect(restored.reps, original.reps);
      expect(restored.recordedAt, original.recordedAt);
    });

    test('unique id generated when not provided', () {
      final a = WorkoutSet(setNumber: 1, weight: 50.0, reps: 5);
      final b = WorkoutSet(setNumber: 1, weight: 50.0, reps: 5);
      expect(a.id, isNotEmpty);
      expect(a.id, isNot(equals(b.id)));
    });
  });

  // ── Exercise ────────────────────────────────────────────────────
  group('Exercise', () {
    test('toJson / fromJson round-trip preserves sets', () {
      final exercise = Exercise(
        name: 'ベンチプレス',
        muscleGroup: MuscleGroup.chest,
        sets: [
          WorkoutSet(setNumber: 1, weight: 80.0, reps: 5),
          WorkoutSet(setNumber: 2, weight: 85.0, reps: 3),
        ],
      );
      final json = exercise.toJson();
      final restored = Exercise.fromJson(json);

      expect(restored.name, 'ベンチプレス');
      expect(restored.muscleGroup, MuscleGroup.chest);
      expect(restored.sets.length, 2);
      expect(restored.sets[1].weight, 85.0);
    });

    test('fromJson defaults unknown muscleGroup to chest', () {
      final json = {
        'id': 'test-id',
        'name': 'Test',
        'muscleGroup': 'unknown_value',
        'sets': <Map<String, dynamic>>[],
      };
      final exercise = Exercise.fromJson(json);
      expect(exercise.muscleGroup, MuscleGroup.chest);
    });
  });

  // ── WorkoutSession ──────────────────────────────────────────────
  group('WorkoutSession', () {
    test('totalVolume sums weight * reps across all exercises', () {
      final session = WorkoutSession(
        date: DateTime.now(),
        startedAt: DateTime.now(),
        exercises: [
          Exercise(
            name: 'ベンチプレス',
            muscleGroup: MuscleGroup.chest,
            sets: [
              WorkoutSet(setNumber: 1, weight: 80.0, reps: 5), // 400
              WorkoutSet(setNumber: 2, weight: 80.0, reps: 5), // 400
            ],
          ),
          Exercise(
            name: 'スクワット',
            muscleGroup: MuscleGroup.legs,
            sets: [
              WorkoutSet(setNumber: 1, weight: 100.0, reps: 5), // 500
            ],
          ),
        ],
      );
      expect(session.totalVolume, closeTo(1300.0, 0.001));
    });

    test('totalVolume is 0 for empty session', () {
      final session = WorkoutSession(
        date: DateTime.now(),
        startedAt: DateTime.now(),
      );
      expect(session.totalVolume, 0.0);
    });

    test('duration is calculated from startedAt to finishedAt', () {
      final start = DateTime(2026, 5, 1, 10, 0, 0);
      final finish = DateTime(2026, 5, 1, 10, 45, 0);
      final session = WorkoutSession(
        date: start,
        startedAt: start,
        finishedAt: finish,
      );
      expect(session.duration.inMinutes, 45);
    });

    test('toJson / fromJson round-trip with exercises', () {
      final original = WorkoutSession(
        sessionName: '胸の日',
        routineName: '胸の日',
        date: DateTime(2026, 5, 1),
        startedAt: DateTime(2026, 5, 1, 10, 0),
        finishedAt: DateTime(2026, 5, 1, 10, 45),
        exercises: [
          Exercise(
            name: 'ベンチプレス',
            muscleGroup: MuscleGroup.chest,
            sets: [WorkoutSet(setNumber: 1, weight: 80.0, reps: 5)],
          ),
        ],
      );
      final json = original.toJson();
      final restored = WorkoutSession.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.sessionName, '胸の日');
      expect(restored.routineName, '胸の日');
      expect(restored.exercises.length, 1);
      expect(restored.exercises.first.name, 'ベンチプレス');
      expect(restored.finishedAt!.hour, 10);
      expect(restored.finishedAt!.minute, 45);
    });
  });
}
