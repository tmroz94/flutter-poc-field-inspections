/// A failed backend call with a machine-readable [code] and optional per-field
/// error codes (HTTP 422) that forms map back onto their fields.
class ApiException implements Exception {
  const ApiException(this.code, {this.status, this.fields = const {}});

  /// network | unauthorized | invalidCredentials | validation | notFound | server | unknown
  final String code;
  final int? status;
  final Map<String, String> fields;

  bool get isNetwork => code == 'network';

  @override
  String toString() => 'ApiException($code, $status, $fields)';
}
