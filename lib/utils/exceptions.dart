class NetworkException implements Exception {
  final String? message;
  NetworkException([this.message]);
  @override
  String toString() => message ?? "Network error";
}

class NotProduceException implements Exception {
  final String? message;
  NotProduceException([this.message]);
  @override
  String toString() => message ?? "Not a produce";
}
