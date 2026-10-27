import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokoku/core/theme/app_theme.dart';
import 'package:tokoku/core/widgets/labeled_field.dart';

void main() {
  testWidgets('the label sits above the field with a gap, never on its border', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: LabeledField(
            label: 'Full name',
            child: TextField(decoration: InputDecoration(prefixIcon: Icon(Icons.person_outline))),
          ),
        ),
      ),
    );

    final labelBottom = tester.getBottomLeft(find.text('Full name')).dy;
    final fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
    expect(fieldTop - labelBottom, greaterThanOrEqualTo(4));
  });

  testWidgets('screen readers announce the label with the field', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LabeledField(label: 'Email', child: TextField())),
      ),
    );

    expect(find.bySemanticsLabel('Email'), findsOneWidget);
    semantics.dispose();
  });
}
