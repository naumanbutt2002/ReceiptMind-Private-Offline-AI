import 'package:flutter/material.dart';

/// Curated category icons, keyed by the `iconKey` stored in the database.
///
/// Only const [Icons] references appear here, so icon font tree-shaking keeps
/// working. Keys are stored data: add new ones, never rename or remove one.
const Map<String, IconData> _categoryIcons = {
  // The seeded categories (see lib/core/db/seed.dart).
  'groceries': Icons.local_grocery_store,
  'dining': Icons.restaurant,
  'transport': Icons.directions_car,
  'shopping': Icons.shopping_bag,
  'bills': Icons.receipt_long,
  'health': Icons.medical_services,
  'other': Icons.category,
  // Extra choices for user-created categories.
  'coffee': Icons.local_cafe,
  'drinks': Icons.local_bar,
  'fuel': Icons.local_gas_station,
  'parking': Icons.local_parking,
  'travel': Icons.flight,
  'home': Icons.home,
  'utilities': Icons.bolt,
  'phone': Icons.phone_iphone,
  'electronics': Icons.devices,
  'subscriptions': Icons.subscriptions,
  'entertainment': Icons.movie,
  'games': Icons.sports_esports,
  'education': Icons.school,
  'books': Icons.menu_book,
  'fitness': Icons.fitness_center,
  'pharmacy': Icons.local_pharmacy,
  'beauty': Icons.spa,
  'clothing': Icons.checkroom,
  'kids': Icons.child_care,
  'pets': Icons.pets,
  'gifts': Icons.card_giftcard,
  'work': Icons.work,
  'repairs': Icons.build,
  'insurance': Icons.shield,
};

/// Icon shown for an `iconKey` that is not in the curated map.
const IconData categoryFallbackIcon = Icons.category;

/// Icon shown for receipts without a category.
const IconData uncategorisedIcon = Icons.label_off_outlined;

/// Every selectable icon key, in display order.
final List<String> categoryIconKeys = List.unmodifiable(_categoryIcons.keys);

/// The icon for [iconKey], or [categoryFallbackIcon] for an unknown key.
IconData categoryIcon(String iconKey) =>
    _categoryIcons[iconKey] ?? categoryFallbackIcon;

/// Curated category colours (Material 600–900 shades). Each one has at least
/// 3:1 contrast with white (the WCAG level for icons), so a white icon on top
/// stays readable, and they are saturated enough to stand out on both light
/// and dark surfaces. The first seven are the seeded categories' colours.
const List<Color> categoryPalette = [
  Color(0xFF2E7D32), // green 800
  Color(0xFFE65100), // orange 900
  Color(0xFF1565C0), // blue 800
  Color(0xFF6A1B9A), // purple 800
  Color(0xFF00838F), // cyan 800
  Color(0xFFC62828), // red 800
  Color(0xFF546E7A), // blue grey 600
  Color(0xFFAD1457), // pink 800
  Color(0xFF283593), // indigo 800
  Color(0xFF00695C), // teal 800
  Color(0xFF5D4037), // brown 700
  Color(0xFF827717), // lime 900
];

/// A filled circle with the category's icon, for lists and pickers.
///
/// Pass `null` for both [iconKey] and [color] to show the "uncategorised"
/// style. [color] is an ARGB value as stored in the database.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    required this.iconKey,
    required this.color,
    this.size = 40,
    this.semanticLabel,
  });

  final String? iconKey;
  final int? color;
  final double size;

  /// Read by screen readers; usually the category name. When `null` the
  /// avatar is decorative and excluded from semantics.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final key = iconKey;
    final argb = color;
    final background = argb == null
        ? scheme.surfaceContainerHighest
        : Color(argb);
    final foreground = argb == null
        ? scheme.onSurfaceVariant
        : _foregroundOn(background);
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(
        key == null ? uncategorisedIcon : categoryIcon(key),
        size: size * 0.55,
        color: foreground,
      ),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: avatar);
    return Semantics(label: label, image: true, child: avatar);
  }
}

/// A small coloured dot that marks a receipt's category in dense rows.
///
/// A `null` [color] (uncategorised) draws an outlined, empty circle.
class CategoryDot extends StatelessWidget {
  const CategoryDot({
    super.key,
    required this.color,
    this.size = 12,
    this.semanticLabel,
  });

  /// ARGB value as stored in the database, or `null` for uncategorised.
  final int? color;
  final double size;

  /// Read by screen readers; usually the category name.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final argb = color;
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: argb == null ? null : Color(argb),
        border: argb == null
            ? Border.all(color: Theme.of(context).colorScheme.outline)
            : null,
      ),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: dot);
    return Semantics(label: label, child: dot);
  }
}

Color _foregroundOn(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black87;
