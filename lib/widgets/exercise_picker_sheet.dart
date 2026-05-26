import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../models/workout.dart';

/// 部位別アコーディオン形式の種目選択ボトムシート。
/// showModalBottomSheet の builder に直接渡して使う。
class ExercisePickerSheet extends StatefulWidget {
  final void Function(Exercise) onSelected;
  final String title;
  final Set<String> markedNames;   // チェックマーク表示 & タップ無効
  final Widget? headerSlot;         // リスト上部に差し込む任意ウィジェット

  const ExercisePickerSheet({
    super.key,
    required this.onSelected,
    this.title = '種目を選択',
    this.markedNames = const {},
    this.headerSlot,
  });

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  late List<Map<String, dynamic>> _exercises;

  static const _groupOrder = [
    MuscleGroup.chest,
    MuscleGroup.back,
    MuscleGroup.legs,
    MuscleGroup.shoulders,
    MuscleGroup.arms,
    MuscleGroup.abs,
  ];

  @override
  void initState() {
    super.initState();
    _exercises = List.from(defaultExercises);
  }

  void _showAddExerciseDialog() {
    final nameCtrl = TextEditingController();
    MuscleGroup selectedGroup = MuscleGroup.chest;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: kSurfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('種目を追加',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: kOnSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: GoogleFonts.inter(color: kOnSurface),
                decoration: InputDecoration(
                  hintText: '種目名',
                  hintStyle: GoogleFonts.inter(color: kOnSurfaceVariant),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: kOutlineVariant)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: kPrimary)),
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: '部位',
                  labelStyle:
                      GoogleFonts.inter(color: kOnSurfaceVariant, fontSize: 12),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: kOutlineVariant)),
                ),
                child: DropdownButton<MuscleGroup>(
                  value: selectedGroup,
                  isExpanded: true,
                  dropdownColor: kSurfaceContainerLow,
                  underline: const SizedBox.shrink(),
                  style: GoogleFonts.inter(color: kOnSurface, fontSize: 14),
                  items: _groupOrder
                      .map((g) => DropdownMenuItem(value: g, child: Text(g.label)))
                      .toList(),
                  onChanged: (g) => setDlgState(() => selectedGroup = g!),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('キャンセル',
                  style: GoogleFonts.inter(color: kOnSurfaceVariant)),
            ),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  setState(() =>
                      _exercises.add({'name': name, 'group': selectedGroup}));
                  Navigator.pop(ctx);
                }
              },
              child: Text('追加',
                  style: GoogleFonts.inter(
                      color: kPrimary, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedItems() {
    final grouped = <MuscleGroup, List<Map<String, dynamic>>>{};
    for (final e in _exercises) {
      final g = e['group'] as MuscleGroup;
      grouped.putIfAbsent(g, () => []).add(e);
    }
    return _groupOrder
        .where((g) => grouped.containsKey(g))
        .map((group) {
          final items = grouped[group]!;
          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(
                group.label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kPrimary,
                  letterSpacing: 1.5,
                ),
              ),
              iconColor: kPrimary,
              collapsedIconColor: kOnSurfaceVariant,
              childrenPadding: EdgeInsets.zero,
              children: items.map((e) {
                final name = e['name'] as String;
                final isMarked = widget.markedNames.contains(name);
                return GestureDetector(
                  onTap: isMarked
                      ? null
                      : () {
                          Navigator.pop(context);
                          widget.onSelected(Exercise(
                            name: name,
                            muscleGroup: e['group'] as MuscleGroup,
                          ));
                        },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isMarked
                          ? kSurfaceContainerHigh
                          : kSurfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isMarked ? kOnSurfaceVariant : kOnSurface,
                            ),
                          ),
                        ),
                        if (isMarked)
                          const Icon(Icons.check, color: kTertiary, size: 16)
                        else
                          const Icon(Icons.chevron_right,
                              color: kOutline, size: 18),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kOnSurface,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showAddExerciseDialog,
                    icon: const Icon(Icons.add, size: 16, color: kPrimary),
                    label: Text(
                      '種目を追加',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kPrimary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.headerSlot != null) ...[
              widget.headerSlot!,
              const Divider(height: 1, color: kSurfaceContainerHigh),
            ],
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: _buildGroupedItems(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
