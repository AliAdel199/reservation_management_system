import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../src/services/license_service.dart';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final privateKeyPath = options['private-key'];
  final customer = options['customer'];
  final expires = options['expires'];
  final output = options['output'] ?? 'license.json';

  if (privateKeyPath == null || customer == null || expires == null) {
    _printUsage();
    exitCode = 64;
    return;
  }

  final expiresAt = DateTime.tryParse(expires);
  if (expiresAt == null) {
    stderr.writeln('Invalid --expires value. Use YYYY-MM-DD.');
    exitCode = 64;
    return;
  }

  var fingerprint = options['fingerprint'];
  if (fingerprint == null || fingerprint.isEmpty) {
    fingerprint = (await LicenseService.buildFingerprint()).value;
  }

  final now = DateTime.now().toUtc();
  final expiresUtc = DateTime.utc(
    expiresAt.year,
    expiresAt.month,
    expiresAt.day,
    23,
    59,
    59,
  );

  if (!expiresUtc.isAfter(now)) {
    stderr.writeln('License expiry must be in the future.');
    exitCode = 64;
    return;
  }

  final privateKey = RSAPrivateKey(File(privateKeyPath).readAsStringSync());
  final jwt = JWT({
    'product': 'reservation_management_system',
    'customer': customer,
    'server_fingerprint': fingerprint,
    'issued_at': now.toIso8601String(),
    'expires_at': expiresUtc.toIso8601String(),
  }, issuer: 'reservation_management_system_license');

  final token = jwt.sign(
    privateKey,
    algorithm: JWTAlgorithm.RS256,
    expiresIn: expiresUtc.difference(now),
  );

  final payload = {
    'token': token,
    'customer': customer,
    'server_fingerprint': fingerprint,
    'expires_at': expiresUtc.toIso8601String(),
  };

  final outputFile = File(output);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(payload),
  );
  stdout.writeln('License written to ${outputFile.path}');
}

Map<String, String> _parseArgs(List<String> args) {
  final result = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final key = arg.substring(2);
    if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
      result[key] = 'true';
      continue;
    }
    result[key] = args[++i];
  }
  return result;
}

void _printUsage() {
  stdout.writeln('''
Usage:
dart run bin/generate_license.dart --private-key PATH --customer "Customer Name" --fingerprint SERVER_FINGERPRINT --expires YYYY-MM-DD --output license.json

If --fingerprint is omitted, the current machine fingerprint is used.
''');
}
