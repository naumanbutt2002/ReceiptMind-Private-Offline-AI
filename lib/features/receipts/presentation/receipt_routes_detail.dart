import 'package:go_router/go_router.dart';

import 'detail/receipt_detail_screen.dart';

/// Locations the receipt list and detail screens navigate to.
abstract final class ReceiptPaths {
  static const list = '/receipts';
  static const newManual = '/receipts/new';
  static const scanCamera = '/scan?source=camera';
  static const scanGallery = '/scan?source=gallery';

  static String detail(String id) => '/receipts/$id';
  static String edit(String id) => '/receipts/$id/edit';
}

/// Child routes of `/receipts` for the detail screen (`/receipts/:id`).
///
/// List them after `new`, so `/receipts/new` isn't read as an id. Pass the
/// edit route (path `edit`) as [detailRoutes] to nest it under the detail.
List<RouteBase> receiptDetailRoutes({
  List<RouteBase> detailRoutes = const [],
}) => [
  GoRoute(
    path: ':id',
    builder: (context, state) =>
        ReceiptDetailScreen(id: state.pathParameters['id']!),
    routes: detailRoutes,
  ),
];
