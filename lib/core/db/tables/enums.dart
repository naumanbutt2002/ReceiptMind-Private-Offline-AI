/// How a receipt's fields were filled in. Stored by name, so values can be
/// added but never renamed.
enum ExtractionMethod { rules, aiText, aiVision, manual }

/// How a receipt was paid. Stored by name.
enum PaymentMethod { card, cash, other }
