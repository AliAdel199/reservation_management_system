import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../config/app_config.dart';

class LicenseFingerprint {
  const LicenseFingerprint({required this.value, required this.source});

  final String value;
  final String source;

  Map<String, dynamic> toJson() => {'fingerprint': value, 'source': source};
}

class LicenseStatus {
  const LicenseStatus({
    required this.enforced,
    required this.valid,
    required this.fingerprint,
    required this.message,
    this.code,
    this.customer,
    this.expiresAt,
  });

  final bool enforced;
  final bool valid;
  final LicenseFingerprint fingerprint;
  final String message;
  final String? code;
  final String? customer;
  final DateTime? expiresAt;

  Map<String, dynamic> toJson() => {
    'enforced': enforced,
    'valid': valid,
    'message': message,
    'code': code,
    'customer': customer,
    'expires_at': expiresAt?.toIso8601String(),
    ...fingerprint.toJson(),
  }..removeWhere((key, value) => value == null);
}

class LicenseService {
  const LicenseService(this._config);

  final AppConfig _config;

  Future<LicenseStatus> checkStatus() async {
    final fingerprint = await buildFingerprint();

    if (!_config.licenseEnforcementEnabled) {
      return LicenseStatus(
        enforced: false,
        valid: true,
        fingerprint: fingerprint,
        message: 'License enforcement is disabled.',
        code: 'LICENSE_DISABLED',
      );
    }

    final licenseFile = File(_config.licenseFilePath);
    if (!licenseFile.existsSync()) {
      return LicenseStatus(
        enforced: true,
        valid: false,
        fingerprint: fingerprint,
        message: 'License file was not found.',
        code: 'LICENSE_FILE_MISSING',
      );
    }

    final publicKeyFile = File(_config.licensePublicKeyPath);
    if (!publicKeyFile.existsSync()) {
      return LicenseStatus(
        enforced: true,
        valid: false,
        fingerprint: fingerprint,
        message: 'License public key was not found.',
        code: 'LICENSE_PUBLIC_KEY_MISSING',
      );
    }

    try {
      final licenseContent = _readLicenseContent(licenseFile);
      final token = licenseContent.token;
      final publicKey = RSAPublicKey(publicKeyFile.readAsStringSync());
      final jwt = JWT.verify(token, publicKey);
      final payload = Map<String, dynamic>.from(jwt.payload as Map);

      final product = payload['product']?.toString();
      if (product != 'reservation_management_system') {
        return LicenseStatus(
          enforced: true,
          valid: false,
          fingerprint: fingerprint,
          message: 'License belongs to a different product.',
          code: 'LICENSE_PRODUCT_MISMATCH',
        );
      }

      final licensedFingerprint = payload['server_fingerprint']?.toString();
      if (licensedFingerprint != fingerprint.value) {
        return LicenseStatus(
          enforced: true,
          valid: false,
          fingerprint: fingerprint,
          message: 'License does not match this server.',
          code: 'LICENSE_FINGERPRINT_MISMATCH',
          customer: payload['customer']?.toString(),
        );
      }

      final mirrorMismatch = _findMirrorMismatch(
        licenseContent.mirrors,
        payload,
      );
      if (mirrorMismatch != null) {
        return LicenseStatus(
          enforced: true,
          valid: false,
          fingerprint: fingerprint,
          message: 'License metadata was modified.',
          code: 'LICENSE_METADATA_MISMATCH',
          customer: payload['customer']?.toString(),
        );
      }

      return LicenseStatus(
        enforced: true,
        valid: true,
        fingerprint: fingerprint,
        message: 'License is valid.',
        code: 'LICENSE_VALID',
        customer: payload['customer']?.toString(),
        expiresAt: DateTime.tryParse(payload['expires_at']?.toString() ?? ''),
      );
    } on JWTExpiredException {
      return LicenseStatus(
        enforced: true,
        valid: false,
        fingerprint: fingerprint,
        message: 'License has expired.',
        code: 'LICENSE_EXPIRED',
      );
    } catch (_) {
      return LicenseStatus(
        enforced: true,
        valid: false,
        fingerprint: fingerprint,
        message: 'License is invalid or corrupted.',
        code: 'LICENSE_INVALID',
      );
    }
  }

  static Future<LicenseFingerprint> buildFingerprint() async {
    if (Platform.isWindows) {
      final machineGuid = await _readWindowsMachineGuid();
      if (machineGuid != null && machineGuid.isNotEmpty) {
        return LicenseFingerprint(
          value: _hash(machineGuid),
          source: 'windows_machine_guid',
        );
      }
    }

    return LicenseFingerprint(
      value: _hash(Platform.localHostname),
      source: 'hostname',
    );
  }

  static Future<String?> _readWindowsMachineGuid() async {
    try {
      final result = await Process.run('reg', [
        'query',
        r'HKLM\SOFTWARE\Microsoft\Cryptography',
        '/v',
        'MachineGuid',
      ]);
      if (result.exitCode != 0) return null;

      final output = result.stdout.toString();
      final match = RegExp(
        r'MachineGuid\s+REG_\w+\s+([^\r\n]+)',
        caseSensitive: false,
      ).firstMatch(output);
      return match?.group(1)?.trim();
    } catch (_) {
      return null;
    }
  }

  static String _hash(String input) {
    final normalized = input.trim().toLowerCase();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  _LicenseContent _readLicenseContent(File licenseFile) {
    final content = licenseFile.readAsStringSync().trim();
    if (!content.startsWith('{')) {
      return _LicenseContent(token: content, mirrors: const {});
    }

    final json = jsonDecode(content) as Map<String, dynamic>;
    final token = json['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const FormatException('Missing license token.');
    }
    return _LicenseContent(token: token, mirrors: json);
  }

  String? _findMirrorMismatch(
    Map<String, dynamic> mirrors,
    Map<String, dynamic> payload,
  ) {
    const protectedFields = {'customer', 'server_fingerprint', 'expires_at'};

    for (final field in protectedFields) {
      if (!mirrors.containsKey(field)) continue;
      if (mirrors[field]?.toString() != payload[field]?.toString()) {
        return field;
      }
    }
    return null;
  }
}

class _LicenseContent {
  const _LicenseContent({required this.token, required this.mirrors});

  final String token;
  final Map<String, dynamic> mirrors;
}
