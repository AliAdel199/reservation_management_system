import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class ApiConnectionPage extends ConsumerStatefulWidget {
  const ApiConnectionPage({super.key});

  @override
  ConsumerState<ApiConnectionPage> createState() => _ApiConnectionPageState();
}

class _ApiConnectionPageState extends ConsumerState<ApiConnectionPage> {
  final _controller = TextEditingController();
  bool _isLoading = true;
  bool _isTesting = false;
  String? _statusMessage;
  bool _statusSuccess = false;
  _ConnectionCheckResult? _lastCheck;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUrl() async {
    final storage = ref.read(appStorageProvider);
    final savedUrl = await storage.readApiBaseUrl();
    if (!mounted) return;
    setState(() {
      _controller.text = savedUrl ?? AppConstants.apiBaseUrl;
      _isLoading = false;
    });
    await _testConnection(savedUrl ?? AppConstants.apiBaseUrl, silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              colorScheme.primary.withValues(alpha: 0.95),
              const Color(0xFF0B1F33),
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إعداد الاتصال بالخادم',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'اكتب عنوان السيرفر الذي يعمل عليه الـ API. كل حاسبة عميلة تحفظ هذا العنوان محلياً.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _controller,
                            textDirection: ui.TextDirection.ltr,
                            decoration: const InputDecoration(
                              labelText: 'رابط الـ API',
                              hintText: 'مثال: 192.168.1.10:7070',
                              prefixIcon: Icon(Icons.dns_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'سيتم تحويله تلقائياً إلى صيغة مثل: http://192.168.1.10:7070/api',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          _ConnectionStatusCard(
                            result: _lastCheck,
                            isTesting: _isTesting,
                            message: _statusMessage,
                            success: _statusSuccess,
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: _isTesting ? null : _saveAndTest,
                                icon: _isTesting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.check_circle_outline),
                                label: const Text('اختبار وحفظ'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isTesting ? null : _testOnly,
                                icon: const Icon(Icons.wifi_tethering_outlined),
                                label: const Text('اختبار فقط'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isTesting ? null : _resetDefault,
                                icon: const Icon(Icons.restore_outlined),
                                label: const Text('الافتراضي'),
                              ),
                              TextButton(
                                onPressed: () => context.go('/login'),
                                child: const Text('رجوع لتسجيل الدخول'),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _testOnly() async {
    await _testConnection(_normalizedUrl);
  }

  Future<void> _saveAndTest() async {
    final url = _normalizedUrl;
    final connected = await _testConnection(url);
    if (!connected || !mounted) return;

    final storage = ref.read(appStorageProvider);
    await storage.saveApiBaseUrl(url);
    await storage.clearSession();

    if (!mounted) return;
    setState(() {
      _controller.text = url;
      _statusSuccess = true;
      _statusMessage = 'تم حفظ الاتصال بنجاح. يمكنك تسجيل الدخول الآن.';
    });
  }

  Future<void> _resetDefault() async {
    final storage = ref.read(appStorageProvider);
    await storage.clearApiBaseUrl();
    await storage.clearSession();

    if (!mounted) return;
    setState(() {
      _controller.text = AppConstants.apiBaseUrl;
      _statusSuccess = true;
      _statusMessage = 'تم الرجوع إلى الرابط الافتراضي المحلي.';
    });
    await _testConnection(AppConstants.apiBaseUrl, silent: true);
  }

  Future<bool> _testConnection(String apiBaseUrl, {bool silent = false}) async {
    setState(() {
      _isTesting = true;
      if (!silent) {
        _statusMessage = null;
      }
    });

    final stopwatch = Stopwatch()..start();
    final checkedAt = DateTime.now();
    final healthUrl = _healthUrlFromApiBaseUrl(apiBaseUrl);
    try {
      final response = await Dio().get<dynamic>(
        healthUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      stopwatch.stop();

      final ok =
          response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
      final healthData = _healthData(response.data);
      final uri = Uri.tryParse(healthUrl);

      if (!mounted) return ok;
      setState(() {
        _statusSuccess = ok;
        _statusMessage = silent
            ? _statusMessage
            : ok
            ? 'الاتصال ناجح وتم استلام رد من الخادم.'
            : 'الخادم رد بحالة غير متوقعة: ${response.statusCode}';
        _lastCheck = _ConnectionCheckResult(
          ok: ok,
          apiBaseUrl: apiBaseUrl,
          healthUrl: healthUrl,
          serverHost: uri?.host ?? '-',
          serverName: healthData['server_name']?.toString(),
          serverIps:
              (healthData['server_ips'] as List<dynamic>?)
                  ?.map((item) => item.toString())
                  .where((item) => item.isNotEmpty)
                  .toList() ??
              const [],
          databaseStatus: healthData['database']?.toString(),
          responseTimeMs: stopwatch.elapsedMilliseconds,
          checkedAt: checkedAt,
        );
      });
      return ok;
    } on DioException catch (error) {
      stopwatch.stop();
      if (!mounted) return false;
      setState(() {
        _statusSuccess = false;
        _statusMessage = silent
            ? _statusMessage
            : 'فشل الاتصال. تأكد من IP السيرفر والمنفذ 7070 وتشغيل خدمة الـ API. (${error.message})';
        _lastCheck = _ConnectionCheckResult(
          ok: false,
          apiBaseUrl: apiBaseUrl,
          healthUrl: healthUrl,
          serverHost: Uri.tryParse(healthUrl)?.host ?? '-',
          responseTimeMs: stopwatch.elapsedMilliseconds,
          checkedAt: checkedAt,
          error: error.message,
        );
      });
      return false;
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  String get _normalizedUrl {
    var value = _controller.text.trim();
    if (value.isEmpty) {
      return AppConstants.apiBaseUrl;
    }

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }

    value = value.replaceAll(RegExp(r'/+$'), '');
    if (!value.toLowerCase().endsWith('/api')) {
      value = '$value/api';
    }

    return value;
  }

  String _healthUrlFromApiBaseUrl(String apiBaseUrl) {
    final normalized = apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    if (normalized.toLowerCase().endsWith('/api')) {
      return '${normalized.substring(0, normalized.length - 4)}/health';
    }
    return '$normalized/health';
  }

  Map<String, dynamic> _healthData(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final data = responseData['data'];
      if (data is Map<String, dynamic>) return data;
    }
    return const <String, dynamic>{};
  }
}

class _ConnectionCheckResult {
  const _ConnectionCheckResult({
    required this.ok,
    required this.apiBaseUrl,
    required this.healthUrl,
    required this.serverHost,
    required this.responseTimeMs,
    required this.checkedAt,
    this.serverName,
    this.serverIps = const [],
    this.databaseStatus,
    this.error,
  });

  final bool ok;
  final String apiBaseUrl;
  final String healthUrl;
  final String serverHost;
  final int responseTimeMs;
  final DateTime checkedAt;
  final String? serverName;
  final List<String> serverIps;
  final String? databaseStatus;
  final String? error;
}

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({
    required this.result,
    required this.isTesting,
    required this.message,
    required this.success,
  });

  final _ConnectionCheckResult? result;
  final bool isTesting;
  final String? message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = success ? const Color(0xFF176B4C) : const Color(0xFF9F2D2D);
    final background = success
        ? const Color(0xFFE8F6EF)
        : const Color(0xFFFFF1F1);
    final border = success ? const Color(0xFF9FD8BD) : const Color(0xFFE8A4A4);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    if (result == null && isTesting) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('جاري فحص الاتصال بالخادم...'),
            ],
          ),
        ),
      );
    }

    if (result == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result!.ok ? Icons.cloud_done_outlined : Icons.cloud_off,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result!.ok ? 'الاتصال يعمل' : 'الاتصال غير متاح',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isTesting)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InfoChip(
                label: 'اسم السيرفر',
                value: result!.serverName ?? result!.serverHost,
              ),
              _InfoChip(label: 'العنوان/IP', value: result!.serverHost),
              _InfoChip(
                label: 'IP الداخلي',
                value: result!.serverIps.isEmpty
                    ? '-'
                    : result!.serverIps.join('، '),
              ),
              _InfoChip(
                label: 'قاعدة البيانات',
                value: result!.databaseStatus == 'ok' ? 'متصلة' : 'غير متاحة',
              ),
              _InfoChip(
                label: 'زمن الاستجابة',
                value: '${result!.responseTimeMs} ms',
              ),
              _InfoChip(
                label: 'آخر فحص',
                value: dateFormat.format(result!.checkedAt),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            result!.apiBaseUrl,
            textDirection: ui.TextDirection.ltr,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
