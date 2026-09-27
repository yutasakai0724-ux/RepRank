import 'package:flutter/material.dart';
import '../utils/app_fonts.dart';
import '../theme.dart';
import '../models/workout.dart';
import '../services/user_preferences.dart';
import 'exercise_record_screen.dart';
import 'routine_detail_screen.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  int _tabIndex = 0;
  bool _isEditMode = false;

  final List<Map<String, dynamic>> _routines = [];

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    final saved = await UserPreferences.instance.getRoutines();
    if (mounted && saved.isNotEmpty) {
      setState(() {
        _routines.clear();
        _routines.addAll(saved);
      });
    }
  }

  Future<void> _saveRoutines() async {
    await UserPreferences.instance.saveRoutines(_routines);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor: context.cBg.withValues(alpha: 0.85),
        elevation: 0,
        title: Text(
          'ROUTINES',
          style: AppFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: kPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTabs(),
          if (_tabIndex == 0) ...[
            const SizedBox(height: 10),
            // ─── "ルーチンを編集" / "完了" ピルボタン ───
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => setState(() => _isEditMode = !_isEditMode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isEditMode
                        ? kPrimary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: _isEditMode ? kPrimary : context.cBorderSub,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isEditMode
                            ? Icons.check
                            : Icons.manage_accounts_outlined,
                        size: 14,
                        color: _isEditMode ? kPrimary : context.cTextSub,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isEditMode ? '完了' : 'ルーチンを編集',
                        style: AppFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _isEditMode ? kPrimary : context.cTextSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ─── マイセット一覧 ───
            ..._routines.asMap().entries.map(
              (e) => _buildRoutineCard(e.key, e.value),
            ),
            if (!_isEditMode) _buildAddRoutineCard(),
          ] else ...[
            const SizedBox(height: 16),
            ...defaultExercises.map((e) => _buildExerciseItem(context, e)),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ─── タブバー ───────────────────────────────────────────────
  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          _tabBtn('マイセット', 0),
          _tabBtn('すべての種目', 1),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int idx) {
    final active = _tabIndex == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? kPrimary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? kPrimary : context.cTextSub,
            ),
          ),
        ),
      ),
    );
  }

  // ─── ルーティンカード ────────────────────────────────────────
  Widget _buildRoutineCard(int idx, Map<String, dynamic> routine) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isEditMode
              ? context.cBorderSub.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: InkWell(
        // 編集モード中はタップ遷移を無効化
        onTap: _isEditMode
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoutineDetailScreen(routine: routine),
                  ),
                ).then((_) {
                  _saveRoutines();
                  setState(() {});
                }),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─ ヘッダー行 ─
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 編集モード：左側にドラッグハンドル
                  if (_isEditMode) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 10),
                      child: Icon(Icons.drag_handle,
                          size: 18,
                          color: context.cTextSub.withValues(alpha: 0.5)),
                    ),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine['name'] as String,
                          style: AppFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.cText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(routine['exercises'] as List).length} 種目 • ${routine['duration']}',
                          style: AppFonts.jetBrainsMono(
                            fontSize: 10,
                            color: context.cTextSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 編集モード：削除ボタン / 通常：ドット3つ（詳細）
                  if (_isEditMode)
                    GestureDetector(
                      onTap: () {
                        setState(() => _routines.removeAt(idx));
                        _saveRoutines();
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 15, color: Colors.redAccent),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () {},
                      child: Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.more_horiz,
                            size: 20, color: context.cTextSub),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // ─ 種目タグ ─
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    (routine['exercises'] as List<String>).map((ex) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.cCardHigh,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      ex,
                      style: AppFonts.jetBrainsMono(
                        fontSize: 10,
                        color: context.cTextSub,
                      ),
                    ),
                  );
                }).toList(),
              ),
              // 編集モード中はボタン行を非表示
              if (!_isEditMode) ...[
                const SizedBox(height: 14),
                // ─ 開始ボタン ─
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RoutineDetailScreen(routine: routine),
                    ),
                  ),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: kPrimary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '開始',
                          style: AppFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateRoutineDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cCardLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '新しいルーチン',
          style: AppFonts.inter(
            fontWeight: FontWeight.w700,
            color: context.cText,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppFonts.inter(color: context.cText),
          decoration: InputDecoration(
            hintText: 'ルーチン名を入力',
            hintStyle: AppFonts.inter(color: context.cTextSub),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.cBorderSub),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: kPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: AppFonts.inter(color: context.cTextSub)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _routines.add({
                    'name': name,
                    'duration': '—',
                    'exercises': <String>[],
                    'group': MuscleGroup.chest,
                  });
                });
                _saveRoutines();
                Navigator.pop(ctx);
              }
            },
            child: Text('作成',
                style: AppFonts.inter(
                    color: kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRoutineCard() {
    return GestureDetector(
      onTap: _showCreateRoutineDialog,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline,
                size: 22, color: context.cTextSub.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            Text(
              '新しいルーチンを作成',
              style: AppFonts.inter(
                fontSize: 13,
                color: context.cTextSub.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── すべての種目リスト ──────────────────────────────────────
  Widget _buildExerciseItem(BuildContext context, Map<String, dynamic> e) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExerciseRecordScreen(
            exercise: Exercise(
              name: e['name'] as String,
              muscleGroup: e['group'] as MuscleGroup,
            ),
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.cCardLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e['name'] as String,
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.cText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.cCardHigh,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      (e['group'] as MuscleGroup).label,
                      style: AppFonts.jetBrainsMono(
                        fontSize: 10,
                        color: context.cTextSub,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.cBorder, size: 18),
          ],
        ),
      ),
    );
  }
}
