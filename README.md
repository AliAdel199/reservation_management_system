# Reservation Management System

منصة حكومية Desktop لإدارة البرامج والأبواب والتخصيصات والحجوزات والصرف، مبنية على:

- `Flutter Desktop`
- `Riverpod`
- `GoRouter`
- `Syncfusion DataGrid`
- `Dart Shelf API`
- `PostgreSQL`

## الهيكل العام

- `lib/` واجهة Flutter مع تقسيم `core`, `shared`, `features`, `layouts`, `widgets`
- `backend/` واجهة API مستقلة مبنية على Dart
- `database/` مخطط PostgreSQL والبذور المرجعية
- `docs/` شرح المرحلة الحالية

## تشغيل قاعدة البيانات

1. أنشئ قاعدة PostgreSQL باسم `reservation_management`.
2. نفذ الملف [001_initial_schema.sql](/d:/reservation_management_system/database/migrations/001_initial_schema.sql).
3. نفذ الملف [001_reference_data.sql](/d:/reservation_management_system/database/seeds/001_reference_data.sql).

## تشغيل الـ Backend

1. انسخ `backend/.env.example` إلى `backend/.env`.
2. من مجلد `backend` شغّل:

```bash
dart pub get
dart run bin/seed_admin.dart
dart run bin/server.dart
```

## تشغيل الـ Frontend

من جذر المشروع:

```bash
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080/api
```

## الحساب الافتراضي

- اسم المستخدم: `admin`
- كلمة المرور: `Admin@123`

تفاصيل Phase 1 موجودة في [phase_1_foundation.md](/d:/reservation_management_system/docs/phase_1_foundation.md).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# reservation_management_system
