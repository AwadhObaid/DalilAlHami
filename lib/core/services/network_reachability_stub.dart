Future<bool> hasNetworkConnection({
  required String host,
  required Duration timeout,
}) async {
  return host.trim().isNotEmpty;
}
