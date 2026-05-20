import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// تعليق عربي: نبض موحد لتحديث الشاشات المالية تلقائياً بدون WebSocket حالياً.
// يمكن مستقبلاً استبداله بإشعارات لحظية من الخادم عند توفرها.
final liveRefreshProvider = StreamProvider.autoDispose<int>((ref) {
  // تعليق عربي: نبض سريع نسبياً حتى تظهر تغييرات الحجوزات والصرف والتقارير
  // بشكل شبه مباشر بدون الحاجة لإعادة فتح الصفحة.
  return Stream.periodic(const Duration(seconds: 3), (tick) => tick);
});
