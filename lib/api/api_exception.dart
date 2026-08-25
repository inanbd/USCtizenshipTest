/// An error the backend reported, carrying a message worth showing the user.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// The caller is not signed in, or the session has expired.
  bool get isUnauthorized => statusCode == 401;

  /// The device could not reach the backend at all.
  bool get isOffline => statusCode == null;

  @override
  String toString() => message;
}
