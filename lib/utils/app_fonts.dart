import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

/// GoogleFonts のスタイル生成は呼び出しごとにフォント解決が走り、描画のたびに
/// 大量に呼ぶと重くなる。同じ引数の組み合わせはキャッシュして使い回す。
class AppFonts {
  AppFonts._();

  static final Map<String, TextStyle> _cache = {};

  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) =>
      _cache.putIfAbsent(
        'inter|$fontSize|${fontWeight?.value}|${color?.toARGB32()}|$letterSpacing|$height|$fontStyle',
        () => GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          height: height,
          fontStyle: fontStyle,
        ),
      );

  static TextStyle jetBrainsMono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) =>
      _cache.putIfAbsent(
        'mono|$fontSize|${fontWeight?.value}|${color?.toARGB32()}|$letterSpacing|$height|$fontStyle',
        () => GoogleFonts.jetBrainsMono(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          height: height,
          fontStyle: fontStyle,
        ),
      );
}
