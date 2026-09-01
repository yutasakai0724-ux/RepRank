import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../models/workout.dart';
import '../services/auth_service.dart';
import '../services/user_preferences.dart';

/// 部位別アコーディオン形式の種目選択ボトムシート。
/// showModalBottomSheet の builder に直接渡して使う。
class ExercisePickerSheet extends StatefulWidget {
  final void Function(Exercise) onSelected;
  final String title;
  final Set<String> markedNames;
  final Widget? headerSlot;
  final List<String> priorityNames;
  final bool allowMarkedTap;

  const ExercisePickerSheet({
    super.key,
    required this.onSelected,
    this.title = '種目を選択',
    this.markedNames = const {},
    this.headerSlot,
    this.priorityNames = const [],
    this.allowMarkedTap = false,
  });

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  late List<Map<String, dynamic>> _exercises;
  Set<String> _favorites = {};
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // ExpansionTileの開閉状態をグループごとに管理（お気に入り操作で崩れないよう）
  final Map<MuscleGroup, bool> _expanded = {};

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
    for (final g in _groupOrder) {
      _expanded[g] = false;
    }
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final custom = await UserPreferences.instance.getCustomExercises();
    final favs = await UserPreferences.instance.getFavoriteExercises();
    if (mounted) {
      setState(() {
        if (custom.isNotEmpty) _exercises.addAll(custom);
        _favorites = favs;
      });
    }
  }

  Future<void> _syncExerciseToFirestore(String name, MuscleGroup group) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || AuthService.instance.isAnonymous) return;
    try {
      final doc = FirebaseFirestore.instance.collection('exercises').doc(name);
      final snap = await doc.get();
      if (!snap.exists) {
        await doc.set({
          'name': name,
          'group': group.name,
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[Exercises] Firestore sync failed: $e');
    }
  }

  Future<void> _toggleFavorite(String name) async {
    final updated = Set<String>.from(_favorites);
    if (updated.contains(name)) {
      updated.remove(name);
    } else {
      updated.add(name);
    }
    await UserPreferences.instance.setFavoriteExercises(updated);
    if (mounted) setState(() => _favorites = updated);
  }

  void _showAddExerciseDialog() {
    final nameCtrl = TextEditingController();
    MuscleGroup selectedGroup = MuscleGroup.chest;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: context.cCardLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('種目を追加',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: context.cText)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: GoogleFonts.inter(color: context.cText),
                decoration: InputDecoration(
                  hintText: '種目名',
                  hintStyle: GoogleFonts.inter(color: context.cTextSub),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: context.cBorderSub)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: kPrimary)),
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: '部位',
                  labelStyle:
                      GoogleFonts.inter(color: context.cTextSub, fontSize: 12),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: context.cBorderSub)),
                ),
                child: DropdownButton<MuscleGroup>(
                  value: selectedGroup,
                  isExpanded: true,
                  dropdownColor: context.cCardLow,
                  underline: const SizedBox.shrink(),
                  style: GoogleFonts.inter(color: context.cText, fontSize: 14),
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
                  style: GoogleFonts.inter(color: context.cTextSub)),
            ),
            TextButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  setState(() =>
                      _exercises.add({'name': name, 'group': selectedGroup}));
                  await UserPreferences.instance.addCustomExercise(name, selectedGroup);
                  await _syncExerciseToFirestore(name, selectedGroup);
                  if (ctx.mounted) Navigator.pop(ctx);
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

  Widget _buildExerciseItem(String name, MuscleGroup group, {bool isPriority = false}) {
    final isMarked = widget.markedNames.contains(name);
    final isFav = _favorites.contains(name);
    return GestureDetector(
      onTap: (isMarked && !widget.allowMarkedTap)
          ? null
          : () {
              Navigator.pop(context);
              widget.onSelected(Exercise(name: name, muscleGroup: group));
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isPriority
              ? (isMarked ? context.cCardHigh : context.cCard)
              : (isMarked ? context.cCardHigh : context.cCardLow),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPriority
                ? kPrimary.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            if (isPriority) ...[
              Icon(Icons.star, size: 14, color: kPrimary.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isMarked ? context.cTextSub : context.cText,
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleFavorite(name),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  size: 18,
                  color: isFav ? const Color(0xFFFFB300) : context.cBorder,
                ),
              ),
            ),
            if (isMarked)
              const Icon(Icons.check, color: kTertiary, size: 16)
            else
              Icon(Icons.chevron_right, color: context.cBorder, size: 18),
          ],
        ),
      ),
    );
  }

  // 検索中はフラットリスト、通常時はアコーディオン
  List<Widget> _buildGroupedItems() {
    final q = _searchQuery.toLowerCase();
    final isSearching = q.isNotEmpty;

    if (isSearching) {
      final filtered = _exercises
          .where((e) => (e['name'] as String).toLowerCase().contains(q))
          .toList();
      if (filtered.isEmpty) {
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text('該当する種目が見つかりません',
                  style: GoogleFonts.inter(fontSize: 13, color: context.cTextSub)),
            ),
          ),
        ];
      }
      return filtered
          .map((e) => _buildExerciseItem(e['name'] as String, e['group'] as MuscleGroup))
          .toList();
    }

    // 通常表示：開閉状態を _expanded で管理
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
              key: PageStorageKey(group),
              initiallyExpanded: _expanded[group] ?? false,
              onExpansionChanged: (v) => _expanded[group] = v,
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
              collapsedIconColor: context.cTextSub,
              childrenPadding: EdgeInsets.zero,
              children: items.map((e) {
                final name = e['name'] as String;
                return _buildExerciseItem(name, e['group'] as MuscleGroup);
              }).toList(),
            ),
          );
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final favList = _searchQuery.isEmpty
        ? _favorites.where((n) => _exercises.any((e) => e['name'] == n)).toList()
        : <String>[];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Material(
        color: context.cBg,
        shape: RoundedRectangleBorder(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
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
                      color: context.cText,
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
            // 検索バー
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.inter(fontSize: 14, color: context.cText),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: '種目を検索...',
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: context.cTextSub),
                  prefixIcon: Icon(Icons.search, size: 18, color: context.cTextSub),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Icon(Icons.close, size: 18, color: context.cTextSub),
                        )
                      : null,
                  filled: true,
                  fillColor: context.cCardLow,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (widget.headerSlot != null) ...[
              widget.headerSlot!,
              Divider(height: 1, color: context.cCardHigh),
            ],
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (widget.priorityNames.isNotEmpty && _searchQuery.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 6),
                      child: Text(
                        'ルーチン種目',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kPrimary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    ...widget.priorityNames.map((name) {
                      final ex = _exercises.firstWhere(
                        (e) => e['name'] == name,
                        orElse: () => {'name': name, 'group': MuscleGroup.chest},
                      );
                      return _buildExerciseItem(name, ex['group'] as MuscleGroup, isPriority: true);
                    }),
                    Divider(height: 20, color: context.cCardHigh),
                  ],
                  if (favList.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 6),
                      child: Text(
                        'お気に入り',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFFB300),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    ...favList.map((name) {
                      final ex = _exercises.firstWhere(
                        (e) => e['name'] == name,
                        orElse: () => {'name': name, 'group': MuscleGroup.chest},
                      );
                      return _buildExerciseItem(name, ex['group'] as MuscleGroup);
                    }),
                    Divider(height: 20, color: context.cCardHigh),
                  ],
                  ..._buildGroupedItems(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
