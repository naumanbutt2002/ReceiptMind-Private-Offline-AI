// Development only: fake receipts for the 1,000-receipt scroll performance
// check (see integration_test/seed_demo_data_test.dart). Nothing in the app
// imports this file, so it is tree-shaken out of release builds.
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

import '../core/date/local_date.dart';
import '../core/db/app_database.dart';

/// Kinds of spending, in the same order as the seeded categories
/// (Groceries, Dining, Transport, Shopping, Bills, Health, Other).
enum _Kind { groceries, dining, transport, shopping, bills, health, other }

typedef _Merchant = ({String name, _Kind kind});

const _merchantsByCurrency = <String, List<_Merchant>>{
  'AUD': [
    (name: 'Woolworths', kind: _Kind.groceries),
    (name: 'Coles', kind: _Kind.groceries),
    (name: 'ALDI', kind: _Kind.groceries),
    (name: 'IGA Fresh', kind: _Kind.groceries),
    (name: 'Harris Farm Markets', kind: _Kind.groceries),
    (name: 'Grill\'d', kind: _Kind.dining),
    (name: 'Guzman y Gomez', kind: _Kind.dining),
    (name: 'Bean Counter Cafe', kind: _Kind.dining),
    (name: 'Pho Saigon', kind: _Kind.dining),
    (name: 'The Local Tavern', kind: _Kind.dining),
    (name: 'Ampol', kind: _Kind.transport),
    (name: 'BP Connect', kind: _Kind.transport),
    (name: '13cabs', kind: _Kind.transport),
    (name: 'Wilson Parking', kind: _Kind.transport),
    (name: 'Kmart', kind: _Kind.shopping),
    (name: 'JB Hi-Fi', kind: _Kind.shopping),
    (name: 'Bunnings Warehouse', kind: _Kind.shopping),
    (name: 'Officeworks', kind: _Kind.shopping),
    (name: 'Big W', kind: _Kind.shopping),
    (name: 'Origin Energy', kind: _Kind.bills),
    (name: 'Sydney Water', kind: _Kind.bills),
    (name: 'Telstra', kind: _Kind.bills),
    (name: 'Chemist Warehouse', kind: _Kind.health),
    (name: 'Priceline Pharmacy', kind: _Kind.health),
    (name: 'City Dental', kind: _Kind.health),
    (name: 'Australia Post', kind: _Kind.other),
    (name: 'Dymocks', kind: _Kind.other),
    (name: 'Petbarn', kind: _Kind.other),
  ],
  'USD': [
    (name: 'Whole Foods Market', kind: _Kind.groceries),
    (name: 'Trader Joe\'s', kind: _Kind.groceries),
    (name: 'Chipotle', kind: _Kind.dining),
    (name: 'Blue Bottle Coffee', kind: _Kind.dining),
    (name: 'Uber', kind: _Kind.transport),
    (name: 'Shell', kind: _Kind.transport),
    (name: 'Target', kind: _Kind.shopping),
    (name: 'Best Buy', kind: _Kind.shopping),
    (name: 'CVS Pharmacy', kind: _Kind.health),
    (name: 'Hudson News', kind: _Kind.other),
  ],
  'EUR': [
    (name: 'Lidl', kind: _Kind.groceries),
    (name: 'REWE', kind: _Kind.groceries),
    (name: 'Café Central', kind: _Kind.dining),
    (name: 'Trattoria da Luca', kind: _Kind.dining),
    (name: 'Deutsche Bahn', kind: _Kind.transport),
    (name: 'Galeries Lafayette', kind: _Kind.shopping),
    (name: 'dm-drogerie markt', kind: _Kind.health),
    (name: 'Relay', kind: _Kind.other),
  ],
};

/// Typical total range per kind, in minor units (min inclusive, max exclusive).
const _amountRange = <_Kind, (int, int)>{
  _Kind.groceries: (450, 24000),
  _Kind.dining: (550, 12000),
  _Kind.transport: (300, 9500),
  _Kind.shopping: (900, 45000),
  _Kind.bills: (2500, 38000),
  _Kind.health: (800, 22000),
  _Kind.other: (200, 15000),
};

const _notes = [
  'Work lunch',
  'Split with flatmates',
  'Claim on tax',
  'Birthday present',
  'Weekly shop',
  'Reimbursable',
];

/// Number of days back from `now` that demo purchase dates spread over
/// (about 18 months).
const demoDaySpan = 548;

/// Currencies used by [demoReceipts]: mostly AUD, some USD and EUR.
const demoCurrencies = {'AUD', 'USD', 'EUR'};

/// Generates [count] realistic, deterministic fake receipts.
///
/// The same [seed] and [now] always give the same receipts. Purchase dates
/// fall within the [demoDaySpan] days up to and including [now]'s date.
/// [categoryIds] should be the category ids in sort order: when there are at
/// least seven they are taken to be the seeded categories, so merchants land
/// in a matching category (a grocery store in Groceries); otherwise
/// categories are picked at random. About 10 % of receipts are left
/// uncategorised. No receipt has an image.
List<ReceiptsCompanion> demoReceipts({
  required int count,
  required List<int> categoryIds,
  required DateTime now,
  int seed = 42,
}) {
  RangeError.checkNotNegative(count, 'count');
  final random = Random(seed);
  final today = LocalDate.fromDateTime(now);
  final matchKinds = categoryIds.length >= _Kind.values.length;

  T pick<T>(List<T> items) => items[random.nextInt(items.length)];
  int between(int min, int max) => min + random.nextInt(max - min);

  return List.generate(count, (_) {
    final roll = random.nextInt(100);
    final currency = roll < 80 ? 'AUD' : (roll < 92 ? 'USD' : 'EUR');
    final merchant = pick(_merchantsByCurrency[currency]!);
    final (min, max) = _amountRange[merchant.kind]!;
    // Round most amounts to 5 cents like real prices tend to be.
    final total = between(min, max) ~/ 5 * 5 + (random.nextBool() ? 0 : 4);

    final date = today.addDays(-random.nextInt(demoDaySpan));
    final scanned = DateTime(
      date.year,
      date.month,
      date.day,
      between(7, 22),
      random.nextInt(60),
      random.nextInt(60),
    );
    // A receipt dated today can't have been saved later than now.
    final createdAt = scanned.isAfter(now) ? now : scanned;

    int? categoryId;
    if (categoryIds.isNotEmpty && random.nextInt(10) != 0) {
      categoryId = matchKinds
          ? categoryIds[merchant.kind.index]
          : pick(categoryIds);
    }

    final payRoll = random.nextInt(100);
    final payment = payRoll < 72
        ? PaymentMethod.card
        : payRoll < 92
        ? PaymentMethod.cash
        : payRoll < 96
        ? PaymentMethod.other
        : null;

    final fromRules = random.nextInt(4) != 0;
    // Australian prices include 10 % GST: tax is 1/11 of the total,
    // rounded to the nearest cent in integer arithmetic (money is never a
    // double).
    final tax = currency == 'AUD' && merchant.kind != _Kind.groceries
        ? (total * 2 + 11) ~/ 22
        : null;
    final note = random.nextInt(10) == 0 ? pick(_notes) : null;
    final randomBytes = List<int>.generate(10, (_) => random.nextInt(256));

    return ReceiptsCompanion.insert(
      id: const Uuid().v7(
        config: V7Options(createdAt.millisecondsSinceEpoch, randomBytes),
      ),
      merchant: merchant.name,
      purchaseDate: date,
      totalMinor: total,
      taxMinor: Value(tax),
      currency: currency,
      paymentMethod: Value(payment),
      categoryId: Value(categoryId),
      notes: Value(note),
      rawOcrText: Value(
        fromRules
            ? '${merchant.name.toUpperCase()}\n'
                  '${date.toIso()}\n'
                  'TOTAL ${_decimal(total)}'
            : null,
      ),
      extractionMethod: fromRules
          ? ExtractionMethod.rules
          : ExtractionMethod.manual,
      confidence: Value(fromRules ? between(60, 100) / 100 : null),
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  });
}

String _decimal(int minor) =>
    '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';
