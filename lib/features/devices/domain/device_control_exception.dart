class DeviceControlException implements Exception {
  const DeviceControlException(this.message);

  final String message;

  @override
  String toString() => message;
}
