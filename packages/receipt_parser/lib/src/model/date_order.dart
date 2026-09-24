/// How to read an ambiguous numeric date such as `03/04/2026`.
enum DateOrder {
  /// 03/04/2026 = 3 April (most of the world).
  dmy,

  /// 03/04/2026 = March 4 (United States and a few others).
  mdy,

  /// 2026/04/03 (ISO style; China, Japan, Korea, …).
  ymd,
}
