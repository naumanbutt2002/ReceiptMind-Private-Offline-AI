import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_mind/core/db/seed.dart';
import 'package:receipt_mind/core/widgets/category_icons.dart';

void main() {
  group('categoryIcon', () {
    test('maps every seeded category icon key', () {
      for (final c in defaultCategories) {
        expect(categoryIconKeys, contains(c.iconKey), reason: c.name);
      }
      expect(categoryIcon('groceries'), Icons.local_grocery_store);
      expect(categoryIcon('dining'), Icons.restaurant);
      expect(categoryIcon('other'), Icons.category);
    });

    test('falls back for an unknown key', () {
      expect(categoryIcon('no-such-key'), categoryFallbackIcon);
      expect(categoryIcon(''), categoryFallbackIcon);
    });

    test('offers about two dozen distinct keys and icons', () {
      expect(categoryIconKeys.length, greaterThanOrEqualTo(24));
      expect(categoryIconKeys.toSet().length, categoryIconKeys.length);
      final icons = categoryIconKeys.map(categoryIcon).toSet();
      expect(icons.length, categoryIconKeys.length);
    });
  });

  group('categoryPalette', () {
    test('contains every seeded colour and has 12 distinct colours', () {
      final argb = categoryPalette.map((c) => c.toARGB32()).toSet();
      expect(argb.length, categoryPalette.length);
      expect(categoryPalette.length, 12);
      for (final c in defaultCategories) {
        expect(argb, contains(c.color), reason: c.name);
      }
    });

    test('every colour is opaque and has 3:1 contrast with white', () {
      for (final color in categoryPalette) {
        expect(color.a, 1.0);
        final contrast = 1.05 / (color.computeLuminance() + 0.05);
        expect(contrast, greaterThanOrEqualTo(3.0), reason: '$color');
      }
    });
  });

  group('widgets', () {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('CategoryAvatar shows the icon on the colour', (tester) async {
      await tester.pumpWidget(
        host(
          const CategoryAvatar(
            iconKey: 'dining',
            color: 0xFFE65100,
            semanticLabel: 'Dining',
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.restaurant);
      expect(icon.color, Colors.white);
      expect(find.bySemanticsLabel('Dining'), findsOneWidget);
    });

    testWidgets('CategoryAvatar has an uncategorised style', (tester) async {
      await tester.pumpWidget(
        host(const CategoryAvatar(iconKey: null, color: null)),
      );
      expect(find.byIcon(uncategorisedIcon), findsOneWidget);
    });

    testWidgets('CategoryDot renders filled and empty dots', (tester) async {
      await tester.pumpWidget(
        host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CategoryDot(color: 0xFF2E7D32),
              CategoryDot(color: null),
            ],
          ),
        ),
      );
      final boxes = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration! as BoxDecoration)
          .toList();
      expect(boxes[0].color, const Color(0xFF2E7D32));
      expect(boxes[1].color, isNull);
      expect(boxes[1].border, isNotNull);
    });
  });
}
