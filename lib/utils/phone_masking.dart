/// Masks a phone number showing only the last 2 digits.
/// Example: "+919876543210" becomes "**********10"
String maskPhoneNumber(String phoneNumber) {
  if (phoneNumber.isEmpty) {
    return phoneNumber;
  }
  
  if (phoneNumber.length <= 2) {
    return phoneNumber;
  }
  
  final lastTwoDigits = phoneNumber.substring(phoneNumber.length - 2);
  final maskedPart = '*' * (phoneNumber.length - 2);
  
  return maskedPart + lastTwoDigits;
}
