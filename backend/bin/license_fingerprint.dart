import 'dart:convert';

import '../src/services/license_service.dart';

Future<void> main() async {
  final fingerprint = await LicenseService.buildFingerprint();
  const encoder = JsonEncoder.withIndent('  ');
  print(encoder.convert(fingerprint.toJson()));
}
