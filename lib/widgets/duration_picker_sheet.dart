import 'package:flutter/material.dart';
import '../utils/app_fonts.dart';
import '../theme.dart';
import '../utils/time_format.dart';

/// 休憩時間ピッカーボトムシート。
/// プリセット8種類 + カスタム秒数入力。
/// 選択された秒数を Navigator.pop で返す。
class DurationPickerSheet extends StatefulWidget {
  final int currentSec;
  const DurationPickerSheet({super.key, required this.currentSec});

  @override
  State<DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<DurationPickerSheet> {
  late int _selected;
  final _customCtrl = TextEditingController();

  static const _presets = [30, 45, 60, 90, 120, 180, 240, 300];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentSec;
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cBorderSub,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '休憩時間を選択',
              style: AppFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.cText,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((s) {
                final isSelected = _selected == s;
                return GestureDetector(
                  onTap: () => setState(() => _selected = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? kSecondary : context.cCardHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? kSecondary : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      formatMMSS(s),
                      style: AppFonts.jetBrainsMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : context.cText,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'カスタム（秒）',
              style: AppFonts.jetBrainsMono(
                fontSize: 10,
                color: context.cTextSub,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _customCtrl,
              keyboardType: TextInputType.number,
              style: AppFonts.jetBrainsMono(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.cText,
              ),
              decoration: InputDecoration(
                hintText: '例: 75',
                hintStyle: AppFonts.jetBrainsMono(
                  color: context.cTextSub.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                suffixText: '秒',
                suffixStyle: AppFonts.jetBrainsMono(
                  color: context.cTextSub,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: context.cCardHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kSecondary, width: 1.5),
                ),
              ),
              onChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null && parsed > 0) {
                  setState(() => _selected = parsed);
                }
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: context.cCardHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'キャンセル',
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.cTextSub,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: kSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '${formatMMSS(_selected)} に設定',
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
