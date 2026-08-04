import 'network_reachability_stub.dart'
    if (dart.library.io) 'network_reachability_io.dart' as platform;

Future<bool> hasNetworkConnection({
  required String host,
  Duration timeout = const Duration(seconds: 6),
}) {
  return platform.hasNetworkConnection(
    host: host,
    timeout: timeout,
  );
}
