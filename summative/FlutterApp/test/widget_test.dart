import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:internet_access_predictor/input_fields.dart';
import 'package:internet_access_predictor/main.dart';

void main() {
  testWidgets(
    'page has one text field per input, a Predict button and a result area',
    (tester) async {
      await tester.pumpWidget(const MyApp());

      expect(
        find.byType(TextField, skipOffstage: false),
        findsNWidgets(inputs.length),
      );
      expect(find.text('Predict', skipOffstage: false), findsOneWidget);
      expect(
        find.text('The prediction will appear here.', skipOffstage: false),
        findsOneWidget,
      );
    },
  );
}
