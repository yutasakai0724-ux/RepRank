import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../models/workout.dart';
import '../services/session_manager.dart';
import 'exercise_record_screen.dart';
import '../widgets/exercise_picker_sheet.dart';

class RoutineDetailScreen extends StatefulWidget {
  final Map<String, dynamic> routine;
  const RoutineDetailScreen({super.key, required this.routine});

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  late List<String> _exerciseNames;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    final exercises = widget.routine['exercises'] as List<String>;
    _exerciseNames = exercises.where((e) => !e.startsWith('+')).toList();
  }

  String get _routineName => widget.routine['name'] as String;
  String get _duration => widget.routine['duration'] as String;
  MuscleGroup get _group => widget.routine['group'] as MuscleGroup;

  IconData _groupIcon(MuscleGroup g) {
    return switch (g) {
      MuscleGroup.chest     => Icons.fitness_center,
      MuscleGroup.back      => Icons.rowing,
      MuscleGroup.legs      => Icons.directions_run,
      MuscleGroup.shoulders => Icons.sports_handball,
      MuscleGroup.arms      => Icons.sports_gymnastics,
      MuscleGroup.abs       => Icons.crop_square,
      _                     => Icons.fitness_center,
    };
  }

  Color _groupColor(MuscleGroup g) {
    return switch (g) {
      MuscleGroup.chest     => kPrimary,
      MuscleGroup.back      => kSecondary,
      MuscleGroup.legs      => kTertiary,
      MuscleGroup.shoulders => const Color(0xFFFFB693),
      MuscleGroup.arms      => const Color(0xFFADC6FF),
      _                     => kPrimary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface.withValues(alpha: 0.85),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _routineName.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: kPrimary,
            letterSpacing: -0.5,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: const [],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _buildHeroCard(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'EXERCISES',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: kOnSurfaceVariant,
                      letterSpacing: 1.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isEditMode = !_isEditMode),
                    child: Text(
                      _isEditMode ? '完了' : '編集',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isEditMode ? kTertiary : kPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._exerciseNames.map(_buildExerciseCard),
              if (_isEditMode) _buildAddExerciseButton(),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildStartButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final color = _groupColor(_group);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT ROUTINE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: kOnSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _routineName.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kOnSurface,
                    letterSpacing: -0.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      _duration,
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 11, color: kOnSurface),
                    ),
                    const SizedBox(width: 14),
                    Icon(Icons.fitness_center, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      '${_exerciseNames.length} 種目',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 11, color: kOnSurface),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(_groupIcon(_group), color: color, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(String name) {
    final color = _groupColor(_group);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _isEditMode
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseRecordScreen(
                            exercise: Exercise(name: name, muscleGroup: _group),
                          ),
                        ),
                      ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kSurfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: kSurfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_groupIcon(_group), color: color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _isEditMode ? kOnSurfaceVariant : kOnSurface,
                        ),
                      ),
                    ),
                    if (!_isEditMode)
                      const Icon(Icons.chevron_right,
                          size: 18, color: kOutlineVariant),
                  ],
                ),
              ),
            ),
          ),
          if (_isEditMode) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _exerciseNames.remove(name)),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.red, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddExerciseButton() {
    return GestureDetector(
      onTap: _showExercisePicker,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: kPrimary.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: kPrimary, size: 18),
            const SizedBox(width: 6),
            Text(
              '種目を追加',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExercisePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ExercisePickerSheet(
        title: '種目を追加',
        markedNames: Set<String>.from(_exerciseNames),
        onSelected: (exercise) {
          setState(() => _exerciseNames.add(exercise.name));
        },
      ),
    );
  }

  Widget _buildStartButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: GestureDetector(
          onTap: _startWorkout,
          child: Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B00).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Text(
                  'ワークアウト開始',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startWorkout() {
    if (_exerciseNames.isEmpty) return;
    // 新しいセッションをルーティン名付きで開始
    SessionManager.instance.reset();
    SessionManager.instance.getOrCreate(
      sessionName: _routineName,
      routineName: _routineName,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseRecordScreen(
          exercise: Exercise(
            name: _exerciseNames.first,
            muscleGroup: _group,
          ),
        ),
      ),
    );
  }
}
