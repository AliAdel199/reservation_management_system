# حماية النسخ والترخيص

هذا النظام لا يعتمد على حماية واجهة Flutter فقط، لأن ملف `exe` الخاص بالعميل يمكن نسخه بسهولة. الحماية الأساسية تكون على خدمة الـ API الموجودة على جهاز السيرفر.

## الفكرة

- كل سيرفر له بصمة خاصة `fingerprint`.
- أنت تنشئ ملف ترخيص `license.json` مربوط بهذه البصمة.
- خدمة الـ API تتحقق من الترخيص قبل السماح بتسجيل الدخول وباقي العمليات.
- إذا نُسخ النظام إلى سيرفر آخر، تختلف البصمة ويرفض الـ API العمل عند تفعيل الترخيص.

## ما الذي يبقى متاحاً بدون ترخيص؟

- `/health` لفحص أن الخدمة تعمل.
- `/license/status` لمعرفة حالة الترخيص وبصمة السيرفر.

باقي النظام يتوقف إذا كانت `LICENSE_ENFORCEMENT=true` والترخيص غير صحيح.

## 1. استخراج بصمة سيرفر الزبون

على جهاز السيرفر شغّل:

```powershell
D:\reservation_management_system\deploy\scripts\get-server-fingerprint.ps1
```

الناتج يكون مثل:

```text
source=windows_machine_guid
fingerprint=PUT_THIS_VALUE_IN_LICENSE
```

احتفظ بقيمة `fingerprint`.

## 2. تجهيز مفاتيح التوقيع

المفتاح الخاص يبقى عندك فقط ولا يُسلّم للزبون. المفتاح العام فقط يوضع مع الـ API.

يمكن توليد مفاتيح RSA بأي أداة مناسبة، مثلاً OpenSSL على جهاز التطوير:

```powershell
openssl genrsa -out D:\license_keys\license_private.pem 2048
openssl rsa -in D:\license_keys\license_private.pem -pubout -out D:\license_keys\license_public.pem
```

انسخ `license_public.pem` فقط إلى:

```text
D:\reservation_management_system\deploy\api\license_public.pem
```

## 3. إنشاء ملف الترخيص

من داخل مجلد backend على جهاز التطوير:

```powershell
cd D:\reservation_management_system\backend
dart run bin\generate_license.dart --private-key "D:\license_keys\license_private.pem" --customer "اسم الزبون" --fingerprint "SERVER_FINGERPRINT_HERE" --expires 2027-12-31 --output "D:\reservation_management_system\deploy\api\license.json"
```

الملف الناتج `license.json` يُسلّم مع السيرفر فقط.

## 4. تفعيل الحماية عند الزبون

نسخة الزبون المبنية عبر:

```powershell
D:\reservation_management_system\deploy\scripts\build-customer-package.ps1 -ProjectRoot "D:\reservation_management_system"
```

تُبنى افتراضياً مع:

```text
LICENSE_REQUIRED=true
```

لذلك لا يستطيع الزبون تعطيل الترخيص بمجرد تغيير `.env` إلى `LICENSE_ENFORCEMENT=false`.

افتح ملف:

```text
D:\reservation_management_system\deploy\api\.env
```

واجعل القيم:

```text
LICENSE_ENFORCEMENT=true
LICENSE_FILE=license.json
LICENSE_PUBLIC_KEY=license_public.pem
```

ثم أعد تشغيل خدمة الـ API.

ملاحظة:

- `LICENSE_ENFORCEMENT=false` مفيد فقط لنسخ التطوير التي لا تُبنى مع `LICENSE_REQUIRED=true`.
- نسخة التسليم الرسمية تتجاهل محاولة التعطيل لأن الترخيص صار مطلوباً داخل ملف الـ API التنفيذي نفسه.

## 5. فحص الترخيص

افتح من السيرفر:

```text
http://127.0.0.1:7070/license/status
```

إذا كان الترخيص صحيحاً يظهر:

```json
{
  "success": true,
  "code": "LICENSE_VALID"
}
```

## ملاحظات مهمة

- لا تضع `license_private.pem` داخل مجلد المشروع أو مجلد الزبون.
- إذا بدّل الزبون جهاز السيرفر أو فرمت النظام، قد تتغير البصمة ويحتاج ترخيص جديد.
- هذه الحماية تمنع التنصيب غير المرخّص عملياً، لكنها ليست حماية مطلقة من الهندسة العكسية. أفضل حماية دائماً هي إبقاء قاعدة البيانات والـ API على سيرفر تحت سيطرة المؤسسة.
