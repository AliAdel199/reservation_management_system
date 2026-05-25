import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                            textDirection: TextDirection.ltr,
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
                          if (_statusMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _statusSuccess
                                    ? const Color(0xFFE8F6EF)
                                    : const Color(0xFFFFF1F1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _statusSuccess
                                      ? const Color(0xFF9FD8BD)
                                      : const Color(0xFFE8A4A4),
                                ),
                              ),
                              child: Text(
                                _statusMessage!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _statusSuccess
                                      ? const Color(0xFF176B4C)
                                      : const Color(0xFF9F2D2D),
                                ),
                              ),
                            ),
                          ],
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
  }

  Future<bool> _testConnection(String apiBaseUrl) async {
    setState(() {
      _isTesting = true;
      _statusMessage = null;
    });

    try {
      final healthUrl = _healthUrlFromApiBaseUrl(apiBaseUrl);
      final response = await Dio().get<dynamic>(
        healthUrl,
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );

      final ok =
          response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;

      if (!mounted) return ok;
      setState(() {
        _statusSuccess = ok;
        _statusMessage = ok
            ? 'الاتصال ناجح: $healthUrl'
            : 'الخادم رد بحالة غير متوقعة: ${response.statusCode}';
      });
      return ok;
    } on DioException catch (error) {
      if (!mounted) return false;
      setState(() {
        _statusSuccess = false;
        _statusMessage =
            'فشل الاتصال. تأكد من IP السيرفر والمنفذ 7070 وتشغيل خدمة الـ API. (${error.message})';
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
}
