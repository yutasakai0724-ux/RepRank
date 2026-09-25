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
  List<String> _favorites = [];
  List<String> _exerciseOrder = [];
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
    final order = await UserPreferences.instance.getExerciseOrder();
    if (mounted) {
      setState(() {
        if (custom.isNotEmpty) _exercises.addAll(custom);
        _favorites = favs;
        _exerciseOrder = order;
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
    final updated = List<String>.from(_favorites);
    if (updated.contains(name)) {
      updated.remove(name);
    } else {
      updated.add(name);
    }
    await UserPreferences.instance.setFavoriteExercises(updated);
    if (mounted) setState(() => _favorites = updated);
  }

  /// 部位内の並び替え結果をグローバルな表示順リストに反映する。
  /// このリストは部位をまたいだ全種目のフラットな順序だが、表示時は
  /// 部位でフィルタしてからこの順序でソートするため、他部位の並びには影響しない。
  Future<void> _persistGroupOrder(List<String> namesInNewOrder) async {
    final updated = List<String>.from(_exerciseOrder)
      ..removeWhere((n) => namesInNewOrder.contains(n));
    updated.addAll(namesInNewOrder);
    setState(() => _exerciseOrder = updated);
    await UserPreferences.instance.setExerciseOrder(updated);
  }

  Future<void> _persistFavoriteOrder(List<String> namesInNewOrder) async {
    setState(() => _favorites = namesInNewOrder);
    await UserPreferences.instance.setFavoriteExercises(namesInNewOrder);
  }

  /// items を _exerciseOrder の順序でソートする。未登録の種目は元の相対順序のまま末尾に続く。
  List<Map<String, dynamic>> _sortByOrder(List<Map<String, dynamic>> items) {
    final orderIndex = <String, int>{
      for (int i = 0; i < _exerciseOrder.length; i++) _exerciseOrder[i]: i,
    };
    final sorted = List<Map<String, dynamic>>.from(items);
    sorted.sort((a, b) {
      final ai = orderIndex[a['name']] ?? (_exerciseOrder.length + items.indexOf(a));
      final bi = orderIndex[b['name']] ?? (_exerciseOrder.length + items.indexOf(b));
      return ai.compareTo(bi);
    });
    return sorted;
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

  Widget _buildExerciseItem(
    String name,
    MuscleGroup group, {
    Key? key,
    bool isPriority = false,
    bool reorderable = false,
    int? dragIndex,
  }) {
    final isMarked = widget.markedNames.contains(name);
    final isFav = _favorites.contains(name);
    return GestureDetector(
      key: key,
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
            if (reorderable && dragIndex != null) ...[
              ReorderableDragStartListener(
                index: dragIndex,
                child: Icon(Icons.drag_handle, size: 18, color: context.cBorder),
              ),
              const SizedBox(width: 8),
            ],
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

  // 検索結果はフラットリスト（並び替えなし）
  Widget _buildSearchResults() {
    final q = _searchQuery.toLowerCase();
    final filtered = _exercises
        .where((e) => (e['name'] as String).toLowerCase().contains(q))
        .toList();
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text('該当する種目が見つかりません',
              style: GoogleFonts.inter(fontSize: 13, color: context.cTextSub)),
        ),
      );
    }
    return Column(
      children: filtered
          .map((e) => _buildExerciseItem(
                e['name'] as String,
                e['group'] as MuscleGroup,
                key: ValueKey('search_${e['name']}'),
              ))
          .toList(),
    );
  }

  // 通常表示：部位別アコーディオン（部位内は並び替え可能）
  List<Widget> _buildGroupedItems() {
    final grouped = <MuscleGroup, List<Map<String, dynamic>>>{};
    for (final e in _exercises) {
      final g = e['group'] as MuscleGroup;
      grouped.putIfAbsent(g, () => []).add(e);
    }
    return _groupOrder
        .where((g) => grouped.containsKey(g))
        .map((group) {
          final items = _sortByOrder(grouped[group]!);
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
              children: [
                ReorderableListView(
                  // ExpansionTile 自体が PageStorageKey(group) で開閉状態(bool)を
                  // 保存しているため、内側の ReorderableListView には別キーを
                  // 与えてスクロール位置(double)の復元先を分離する
                  // （同一キーだと型不一致でクラッシュする）。
                  key: PageStorageKey('reorder_${group.name}'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: (oldIndex, newIndex) {
                    final reordered = List<Map<String, dynamic>>.from(items);
                    final moved = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, moved);
                    _persistGroupOrder(
                        reordered.map((e) => e['name'] as String).toList());
                  },
                  children: [
                    for (int i = 0; i < items.length; i++)
                      _buildExerciseItem(
                        items[i]['name'] as String,
                        items[i]['group'] as MuscleGroup,
                        key: ValueKey('group_${items[i]['name']}'),
                        reorderable: true,
                        dragIndex: i,
                      ),
                  ],
                ),
              ],
            ),
          );
        })
        .toList();
  }

  Widget _buildFavoritesSection() {
    final favList =
        _favorites.where((n) => _exercises.any((e) => e['name'] == n)).toList();
    if (favList.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        ReorderableListView(
          key: const PageStorageKey('reorder_favorites'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (oldIndex, newIndex) {
            final reordered = List<String>.from(favList);
            final moved = reordered.removeAt(oldIndex);
            reordered.insert(newIndex, moved);
            _persistFavoriteOrder(reordered);
          },
          children: [
            for (int i = 0; i < favList.length; i++)
              _buildExerciseItem(
                favList[i],
                (_exercises.firstWhere(
                  (e) => e['name'] == favList[i],
                  orElse: () => {'group': MuscleGroup.chest},
                )['group'] as MuscleGroup),
                key: ValueKey('fav_${favList[i]}'),
                reorderable: true,
                dragIndex: i,
              ),
          ],
        ),
        Divider(height: 20, color: context.cCardHigh),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
              child: _searchQuery.isNotEmpty
                  ? SingleChildScrollView(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: _buildSearchResults(),
                    )
                  : ListView(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        if (widget.priorityNames.isNotEmpty) ...[
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
                            return _buildExerciseItem(
                              name,
                              ex['group'] as MuscleGroup,
                              key: ValueKey('priority_$name'),
                              isPriority: true,
                            );
                          }),
                          Divider(height: 20, color: context.cCardHigh),
                        ],
                        _buildFavoritesSection(),
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
