String maskPhoneNumber(String phoneNumber) {
  if (phoneNumber.length < 4) {
    return phoneNumber;
  }
  // Keep the last 4 digits visible
  String visible = phoneNumber.substring(phoneNumber.length - 4);
  // Mask the rest with asterisks
  String masked = '*' * (phoneNumber.length - 4);
  return masked + visible;
}
