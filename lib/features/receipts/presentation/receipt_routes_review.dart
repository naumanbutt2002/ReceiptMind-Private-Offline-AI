import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'review/review_screen.dart';

/// Locations of the review screen (PLAN §9).
abstract final class ReviewRoutes {
  /// Review of the scan held by `scanControllerProvider`.
  static const scanReview = '/scan/review';

  /// An empty receipt form (manual entry, no photo).
  static const newReceipt = '/receipts/new';

  /// Edit the saved receipt [id].
  static String edit(String id) => '/receipts/$id/edit';
}

/// Top-level routes: `/scan/review`.
final List<RouteBase> reviewTopLevelRoutes = [
  GoRoute(
    path: ReviewRoutes.scanReview,
    builder: (context, state) => const ReviewScreen(mode: ReviewMode.newScan),
  ),
];

/// Children of `/receipts`: `new` and `:id/edit`. List them before a
/// `:id` detail route so `new` isn't read as an id.
final List<RouteBase> reviewReceiptChildRoutes =
    buildReviewReceiptChildRoutes();

/// [reviewReceiptChildRoutes] with a [parentNavigatorKey], e.g. the root
/// navigator's key so the form covers the bottom navigation bar.
List<RouteBase> buildReviewReceiptChildRoutes({
  GlobalKey<NavigatorState>? parentNavigatorKey,
}) => [
  GoRoute(
    path: 'new',
    parentNavigatorKey: parentNavigatorKey,
    builder: (context, state) => const ReviewScreen(mode: ReviewMode.manual),
  ),
  GoRoute(
    path: ':id/edit',
    parentNavigatorKey: parentNavigatorKey,
    builder: (context, state) => ReviewScreen(
      mode: ReviewMode.edit,
      receiptId: state.pathParameters['id'],
    ),
  ),
];
