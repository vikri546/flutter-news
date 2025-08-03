// Base exception class
class AppException implements Exception {
  final String message;
  
  AppException(this.message);
  
  @override
  String toString() => message;
}

// No internet connection
class NoInternetException extends AppException {
  NoInternetException(String message) : super(message);
}

// API returned an error
class ApiException extends AppException {
  ApiException(String message) : super(message);
}

// Unauthorized (invalid API key)
class UnauthorizedException extends AppException {
  UnauthorizedException(String message) : super(message);
}

// Too many requests
class TooManyRequestsException extends AppException {
  TooManyRequestsException(String message) : super(message);
}

// Request timeout
class TimeoutException extends AppException {
  TimeoutException(String message) : super(message);
}

// Unknown error
class UnknownException extends AppException {
  UnknownException(String message) : super(message);
}

// Cache exception
class CacheException extends AppException {
  CacheException(String message) : super(message);
}