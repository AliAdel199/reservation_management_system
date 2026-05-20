import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../models/request_user.dart';

class JwtService {
  const JwtService(this._config);

  final AppConfig _config;

  String generateToken(AppUser user) {
    final jwt = JWT({
      'sub': user.id,
      'username': user.username,
      'full_name': user.fullName,
      'role_code': user.roleCode,
      'role_name': user.roleName,
    }, issuer: _config.appName);

    return jwt.sign(
      SecretKey(_config.jwtSecret),
      expiresIn: Duration(hours: _config.jwtExpiresInHours),
    );
  }

  RequestUser verifyToken(String token) {
    final jwt = JWT.verify(token, SecretKey(_config.jwtSecret));
    final payload = Map<String, dynamic>.from(jwt.payload as Map);
    return RequestUser.fromClaims(payload);
  }
}
