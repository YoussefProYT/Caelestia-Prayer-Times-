# Caelestia Prayer Times

A standalone QML add-on for [Caelestia Shell](https://github.com/caelestia-dots/caelestia) that displays local prayer times, the next-prayer countdown, and configurable iqama delays directly in the Dashboard.

[![Caelestia Shell](https://img.shields.io/badge/Caelestia-Shell-7c3aed?style=flat-square)](https://github.com/caelestia-dots/caelestia)
[![QML](https://img.shields.io/badge/QML-Quickshell-41cd52?style=flat-square)](https://quickshell.org/)
[![License](https://img.shields.io/badge/license-see%20LICENSE-2ea44f?style=flat-square)](LICENSE)

## Features

- Local prayer-time calculation using the bundled [Adhan JS](https://github.com/batoulapps/adhan-js) engine.
- Automatic location through Caelestia, city lookup, or direct `latitude,longitude` input.
- Offline calculation when coordinates are available locally.
- Next-prayer countdown with separate adhan and iqama states.
- Configurable iqama delays for Fajr, Dhuhr, Asr, Maghrib, and Isha.
- Iqama controls stay collapsed until opened with the timer button.
- Madhab selection:
  - **Standard:** Shafi'i, Maliki, and Hanbali in one option because they share the same Asr shadow length in the bundled engine.
  - **Hanafi:** Hanafi Asr shadow length.
- Arabic and English UI support across settings, prayer cards, status messages, and dynamic countdown labels.
- Follow-shell, 12-hour, and 24-hour time formats.
- User-local installation without changing system-owned files or requiring a C++ rebuild.

## Requirements

- Caelestia Shell with a compatible Dashboard registry.
- `bash` and `python3` for the installer.
- No compiler, build system, or online prayer-time API is required.

The add-on is designed for Caelestia on CachyOS and other Linux environments where Caelestia/Quickshell is available.

## Installation

Extract the release archive, open a terminal in the add-on directory, and run:

```sh
./install.sh
```

The installer detects Caelestia, registers the Dashboard tab, and installs the payload. It does not require `git clone`, `sudo`, or a C++ rebuild. If the detected shell is system-owned, a user-owned copy is created instead of modifying `/usr`.

Check the detected layout without changing anything:

```sh
./install.sh --check
```

Use a non-standard shell path when necessary:

```sh
./install.sh --target "/path/to/caelestia"
```

Restart Caelestia/Quickshell if the tab does not appear immediately.

## Update and removal

Update an existing installation:

```sh
./install.sh --update
```

Remove the add-on:

```sh
./install.sh --uninstall
```

The installer updates or removes only add-on files it can verify safely. It preserves user preferences and does not overwrite user-edited files.

## Configuration

Preferences are stored at:

```text
${XDG_CONFIG_HOME:-~/.config}/caelestia/prayer-times.json
```

Open the **Prayer times** Dashboard tab and press the settings button.

### Location

- Leave the field empty to follow Caelestia's automatic location.
- Enter a city and country, such as `Cairo, Egypt`.
- Enter direct coordinates, such as `30.0444,31.2357`, for offline calculation.

City lookup needs an internet connection on the first request. Resolved coordinates are cached locally.

### Madhab and language

Choose **Shafi'i, Maliki and Hanbali (standard)** or **Hanafi**. The legacy `asrSchool` value remains readable for compatibility; new settings use `madhab: "standard"` or `madhab: "hanafi"`.

Choose **Arabic** or **English**. Arabic is the default for backwards compatibility, stored as `language: "ar"`; English is stored as `language: "en"`.

### Iqama delays

Press the timer button beside **Iqama delay after adhan** to expand the controls. Each prayer can be configured from 0 to 60 minutes in 5-minute steps. Defaults are 15 minutes, except Maghrib at 5 minutes.

### Time format

- **Follow shell** follows Caelestia's clock format.
- **12-hour** uses a 12-hour clock.
- **24-hour** uses a 24-hour clock.

## Calculation and privacy

Prayer times are calculated locally from coordinates with the bundled Adhan JS engine. The add-on does not download prayer times from an online API.

Network access may be used for automatic location or the first city-name lookup. Direct coordinates work without network access.

## Troubleshooting

### The tab does not appear

Restart Caelestia/Quickshell and run `./install.sh --check`. Confirm that the detected shell directory is the one you actually use.

### City lookup fails

Check the city and country spelling, or enter direct `latitude,longitude` coordinates.

### A dynamic label keeps the old language

Install the latest release and restart the shell once. Dynamic prayer labels are rebuilt when the language changes.

## Project layout

```text
caelestia-prayer-times-addon/
├── prayer-times/
│   ├── modules/dashboard/PrayerTimes.qml
│   └── services/
│       ├── PrayerService.qml
│       ├── Adhan.js
│       └── ADHAN-JS-LICENSE.txt
├── install.sh
├── LICENSE
└── README.md
```

## Credits

- Calculation engine: [Adhan JS](https://github.com/batoulapps/adhan-js)
- Integration target: [Caelestia](https://github.com/caelestia-dots/caelestia)
- The bundled Adhan JS license is included at `prayer-times/services/ADHAN-JS-LICENSE.txt`.

---

# مواقيت الصلاة لـCaelestia

إضافة QML مستقلة لـ[Caelestia Shell](https://github.com/caelestia-dots/caelestia)، تعرض مواقيت الصلاة محليًا، والعد التنازلي للصلاة القادمة، وإعدادات تأخير الإقامة داخل Dashboard.

## المميزات

- حساب المواقيت محليًا باستخدام محرك [Adhan JS](https://github.com/batoulapps/adhan-js) المضمّن.
- استخدام الموقع التلقائي من Caelestia أو البحث عن مدينة أو إدخال الإحداثيات مباشرة.
- الحساب دون اتصال عند توفر الإحداثيات محليًا.
- عداد للصلاة القادمة مع فصل حالة الأذان عن حالة الإقامة.
- ضبط تأخير الإقامة للفجر والظهر والعصر والمغرب والعشاء.
- قائمة تأخير الإقامة مغلقة افتراضيًا وتُفتح من زر المؤقت.
- اختيار المذهب:
  - **قياسي:** الشافعي والمالكي والحنبلي في خيار واحد لأنها تستخدم نفس طول الظل للعصر في المحرك المضمّن.
  - **حنفي:** يستخدم طول الظل الخاص بالحساب الحنفي.
- دعم العربية والإنجليزية في الإعدادات وبطاقات الصلوات ورسائل الحالة والعدادات الديناميكية.
- دعم اتباع تنسيق Caelestia أو نظام 12 ساعة أو 24 ساعة.
- تثبيت محلي للمستخدم دون تعديل ملفات النظام أو الحاجة إلى إعادة بناء C++.

## المتطلبات

- Caelestia Shell مع Dashboard متوافق مع المثبّت.
- `bash` و`python3` لتشغيل المثبّت.
- لا تحتاج الإضافة إلى مترجم أو نظام بناء أو API خارجي لمواقيت الصلاة.

صُممت الإضافة للعمل مع Caelestia على CachyOS وبيئات Linux الأخرى التي يتوفر فيها Caelestia/Quickshell.

## التثبيت

فك ضغط الحزمة، وافتح الطرفية داخل مجلد الإضافة، ثم شغّل:

```sh
./install.sh
```

يكتشف المثبّت Caelestia، ويسجل تبويب Dashboard، ثم يثبت ملفات الإضافة. لا تحتاج إلى `git clone` أو `sudo` أو إعادة بناء C++. وإذا كانت النسخة المكتشفة مملوكة للنظام، ينشئ المثبّت نسخة مستخدم بدل تعديل `/usr`.

للفحص دون تعديل:

```sh
./install.sh --check
```

لمسار shell غير قياسي:

```sh
./install.sh --target "/path/to/caelestia"
```

أعد تشغيل Caelestia/Quickshell إذا لم يظهر التبويب مباشرة.

## التحديث والإزالة

لتحديث نسخة مثبتة:

```sh
./install.sh --update
```

لإزالة الإضافة:

```sh
./install.sh --uninstall
```

يحدّث المثبّت أو يزيل فقط ملفات الإضافة التي يستطيع التحقق منها بأمان، ويحافظ على تفضيلات المستخدم ولا يستبدل الملفات المعدلة يدويًا.

## الإعدادات

تُحفظ الإعدادات في:

```text
${XDG_CONFIG_HOME:-~/.config}/caelestia/prayer-times.json
```

افتح تبويب **Prayer times** واضغط زر الإعدادات.

### الموقع

- اترك الحقل فارغًا لاتباع الموقع التلقائي من Caelestia.
- أدخل المدينة والدولة، مثل `Cairo, Egypt`.
- أدخل الإحداثيات، مثل `30.0444,31.2357`، للحساب دون اتصال.

يحتاج البحث باسم المدينة إلى الإنترنت في أول مرة، ثم تُحفظ الإحداثيات محليًا.

### المذهب واللغة

اختر **الشافعي والمالكي والحنبلي — قياسي** أو **الحنفي**. تظل قيمة `asrSchool` القديمة مقروءة للتوافق، بينما تستخدم الإعدادات الجديدة `madhab: "standard"` أو `madhab: "hanafi"`.

اختر **العربية** أو **English**. العربية هي اللغة الافتراضية، وتُحفظ كـ`language: "ar"`، بينما تُحفظ الإنجليزية كـ`language: "en"`.

### تأخير الإقامة

اضغط زر المؤقت بجوار **Iqama delay after adhan** لفتح الإعدادات. يمكن ضبط كل صلاة من 0 إلى 60 دقيقة بخطوات 5 دقائق. القيمة الافتراضية 15 دقيقة، ما عدا المغرب فالقيمة الافتراضية له 5 دقائق.

### تنسيق الوقت

- **Follow shell** لاتباع تنسيق ساعة Caelestia.
- **12-hour** لنظام 12 ساعة.
- **24-hour** لنظام 24 ساعة.

## الحساب والخصوصية

تُحسب المواقيت محليًا من الإحداثيات باستخدام محرك Adhan JS المضمّن. لا تحمّل الإضافة مواقيت الصلاة من API خارجي.

قد تحتاج الإضافة إلى الشبكة للموقع التلقائي أو البحث عن المدينة أول مرة. أما إدخال الإحداثيات مباشرة فيعمل دون اتصال.

## حل المشاكل

### لم يظهر تبويب الإضافة

أعد تشغيل Caelestia/Quickshell ثم شغّل `./install.sh --check`. تأكد من أن مسار shell المكتشف هو النسخة التي تستخدمها فعليًا.

### فشل البحث عن المدينة

تحقق من اسم المدينة والدولة، أو أدخل الإحداثيات مباشرة بصيغة `خط العرض,خط الطول`.

### بقي نص ديناميكي باللغة القديمة

استخدم أحدث إصدار وأعد تشغيل shell مرة واحدة. يعيد الإصدار الحديث بناء أسماء الصلوات الديناميكية عند تغيير اللغة.

## بنية المشروع

```text
caelestia-prayer-times-addon/
├── prayer-times/
│   ├── modules/dashboard/PrayerTimes.qml
│   └── services/
│       ├── PrayerService.qml
│       ├── Adhan.js
│       └── ADHAN-JS-LICENSE.txt
├── install.sh
├── LICENSE
└── README.md
```

## الاعتمادات والفضل

- محرك الحساب: [Adhan JS](https://github.com/batoulapps/adhan-js)
- بيئة التكامل: [Caelestia](https://github.com/caelestia-dots/caelestia)
- ترخيص Adhan JS المضمّن موجود في `prayer-times/services/ADHAN-JS-LICENSE.txt`.

## الترخيص

راجع ملف [`LICENSE`](LICENSE).
