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

  testWidgets('keeps percentages at two decimals without dimming', (
    tester,
  ) async {
    // 百分比是计算输出，不受工时限一位影响：保留两位、不镂空
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PrecisionText('完成率 37.50%'))),
    );

    expect(find.text('完成率 37.50%'), findsOneWidget);
    // 百分比不使用"第二位不计入"语义
    expect(find.bySemanticsLabel('完成率 37.50%'), findsOneWidget);
  });

  testWidgets('still dims hour hundredths inside mixed percentage text', (
    tester,
  ) async {
    // 混合串含百分比时整体不镂空（如"24.00% (8.9h/天)"），
    // 小时数本身已是一位显示，无需镂空
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PrecisionText('111.25% (44.5h/天)')),
      ),
    );

    expect(find.text('111.25% (44.5h/天)'), findsOneWidget);
  });
}
