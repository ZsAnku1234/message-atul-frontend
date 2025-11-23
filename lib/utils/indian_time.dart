const Duration _istOffset = Duration(hours: 5, minutes: 30);

/// Converts any [DateTime] to India Standard Time while preserving the instant.
DateTime toIndianTime(DateTime date) {
  final utc = date.isUtc ? date : date.toUtc();
  final shifted = utc.add(_istOffset);

  return DateTime(
    shifted.year,
    shifted.month,
    shifted.day,
    shifted.hour,
    shifted.minute,
    shifted.second,
    shifted.millisecond,
    shifted.microsecond,
  );
}

/// Convenience helper for retrieving the current time in IST.
DateTime indianNow() => toIndianTime(DateTime.now());

extension IndianTimeExtension on DateTime {
  /// Shorthand to convert an existing [DateTime] to IST.
  DateTime get asIndianTime => toIndianTime(this);
}
