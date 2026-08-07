import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// 将两位小数的最后一位弱化，提示该位不计入工时。
class PrecisionText extends StatelessWidget {
  const PrecisionText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.mutedColor,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final Color? mutedColor;

  static final RegExp _twoDecimalPattern = RegExp(r'-?\d+\.\d{2}');

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    return Text.rich(
      TextSpan(children: _buildSpans(effectiveStyle)),
      style: effectiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      semanticsLabel: _twoDecimalPattern.hasMatch(data)
          ? '$data，小数点后第二位不计入工时'
          : data,
    );
  }

  List<InlineSpan> _buildSpans(TextStyle effectiveStyle) {
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in _twoDecimalPattern.allMatches(data)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: data.substring(cursor, match.start)));
      }

      final value = match.group(0)!;
      spans.add(TextSpan(text: value.substring(0, value.length - 1)));
      spans.add(
        TextSpan(
          text: value.substring(value.length - 1),
          style: effectiveStyle.copyWith(
            color: mutedColor ?? AppColors.decimalMuted,
          ),
        ),
      );
      cursor = match.end;
    }

    if (cursor < data.length) {
      spans.add(TextSpan(text: data.substring(cursor)));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: data));
    }
    return spans;
  }
}
