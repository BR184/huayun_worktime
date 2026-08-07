import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hikiot_worktime/core/theme/app_colors.dart';
import 'package:hikiot_worktime/widgets/precision_text.dart';

void main() {
  testWidgets('dims only the hundredths digit of every decimal value', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PrecisionText('8.59h / 10.40h'))),
    );

    final richText = tester.widget<RichText>(find.byType(RichText).last);
    final root = richText.text as TextSpan;
    final spans = <TextSpan>[];

    void collectSpans(TextSpan span) {
      spans.add(span);
      for (final child in span.children ?? const <InlineSpan>[]) {
        if (child is TextSpan) collectSpans(child);
      }
    }

    collectSpans(root);

    expect(root.toPlainText(), '8.59h / 10.40h');
    final outlined = spans
        .where((span) => span.style?.foreground != null)
        .map((span) => span.text);
    expect(outlined, ['9', '0']);
    final outlinePaint = spans
        .firstWhere((span) => span.style?.foreground != null)
        .style!
        .foreground!;
    expect(outlinePaint.style, PaintingStyle.stroke);
    expect(outlinePaint.color.toARGB32(), AppColors.decimalMuted.toARGB32());
    expect(
      find.bySemanticsLabel('8.59h / 10.40h，小数点后第二位不计入工时'),
      findsOneWidget,
    );
  });

  testWidgets('shows percentages with one decimal place', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PrecisionText('完成率 37.50%'))),
    );

    expect(find.text('完成率 37.5%'), findsOneWidget);
  });
}
