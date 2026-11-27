import 'package:flutter/widgets.dart';
import 'package:receipt_parser/receipt_parser.dart' show ReceiptField;

/// Keys of the review screen's widgets, for widget and integration tests.
abstract final class ReviewKeys {
  static const closeButton = Key('review.close');
  static const saveButton = Key('review.save');
  static const loading = Key('review.loading');
  static const unavailable = Key('review.unavailable');

  static const photo = Key('review.photo');
  static const photoFullScreenButton = Key('review.photo.fullScreen');
  static const photoViewer = Key('review.photo.viewer');

  static const form = Key('review.form');
  static const ocrFailedBanner = Key('review.ocrFailedBanner');
  static const recognisedTextButton = Key('review.recognisedText');
  static const recognisedTextSheet = Key('review.recognisedText.sheet');

  static const merchantField = Key('review.field.merchant');
  static const dateField = Key('review.field.date');
  static const datePickerButton = Key('review.field.date.pick');
  static const totalField = Key('review.field.total');
  static const currencyField = Key('review.field.currency');
  static const moreToggle = Key('review.more');
  static const subtotalField = Key('review.field.subtotal');
  static const taxField = Key('review.field.tax');
  static const tipField = Key('review.field.tip');
  static const paymentMethod = Key('review.field.paymentMethod');
  static const notesField = Key('review.field.notes');

  static const discardDialog = Key('review.discard');
  static const discardConfirm = Key('review.discard.confirm');
  static const discardCancel = Key('review.discard.cancel');

  static const photoMissingDialog = Key('review.photoMissing');
  static const saveWithoutPhoto = Key('review.photoMissing.saveWithout');

  /// The chip of the category with [id].
  static Key category(int id) => Key('review.category.$id');

  /// The ⚠️ icon (or row) shown next to a flagged [field].
  static Key warning(ReceiptField field) => Key('review.warning.${field.name}');
}
