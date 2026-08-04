import 'dart:async';
import 'dart:io';

Future<bool> hasNetworkConnection({
  required String host,
  required Duration timeout,
}) async {
  final normalizedHost = host.trim();
  if (normalizedHost.isEmpty) {
    return false;
  }

  try {
    final addresses = await InternetAddress.lookup(
      normalizedHost,
    ).timeout(timeout);
    return addresses.any((address) => address.rawAddress.isNotEmpty);
  } on Object {
    return false;
  }
}
