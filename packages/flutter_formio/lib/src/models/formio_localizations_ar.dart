/// Arabic (العربية) localization for Form.io Flutter.
///
/// Use it via the global locale:
/// ```dart
/// ComponentFactory.setLocale(const ArabicFormioLocalizations());
/// ```
/// or as a Flutter localizations delegate
/// ([ArabicFormioLocalizations.delegate]).
///
/// Extends [DefaultFormioLocalizations] so any strings added to the base in the
/// future fall back to English until translated here.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'formio_localizations.dart';

class ArabicFormioLocalizations extends DefaultFormioLocalizations {
  const ArabicFormioLocalizations();

  // Buttons & Actions
  @override
  String get submit => 'إرسال';
  @override
  String get cancel => 'إلغاء';
  @override
  String get clear => 'مسح';
  @override
  String get undo => 'تراجع';
  @override
  String get next => 'التالي';
  @override
  String get previous => 'السابق';
  @override
  String get complete => 'إنهاء';
  @override
  String get add => 'إضافة';
  @override
  String get addAnother => 'إضافة آخر';
  @override
  String get addEntry => 'إضافة إدخال';
  @override
  String get edit => 'تعديل';
  @override
  String get save => 'حفظ';
  @override
  String get remove => 'إزالة';
  @override
  String get delete => 'حذف';

  // File Component
  @override
  String get uploadFile => 'رفع ملف';
  @override
  String get noFileSelected => 'لم يتم اختيار ملف';
  @override
  String get fileSelected => 'ملف محدد';
  @override
  String get filesSelected => 'ملفات محددة';

  // DataSource
  @override
  String get fetching => 'جارٍ الجلب';
  @override
  String get dataSourceError => 'خطأ في مصدر البيانات';

  // DataGrid & EditGrid
  @override
  String get removeRow => 'إزالة صف';
  @override
  String get editRow => 'تعديل صف';
  @override
  String get saveRow => 'حفظ صف';
  @override
  String get cancelEdit => 'إلغاء التعديل';

  // DataTable
  @override
  String get showing => 'عرض';
  @override
  String get of => 'من';
  @override
  String get rowsPerPage => 'صفوف لكل صفحة';
  @override
  String get rowSelected => 'صف محدد';
  @override
  String get rowsSelected => 'صفوف محددة';
  @override
  String get noDataAvailable => 'لا توجد بيانات متاحة';

  // Wizard & DynamicWizard
  @override
  String get step => 'خطوة';
  @override
  String get stepOf => 'من';

  // Generic
  @override
  String get required => 'مطلوب';
  @override
  String get isRequired => 'مطلوب';
  @override
  String get noData => 'لا توجد بيانات';
  @override
  String get noDataToReview => 'لا توجد بيانات للمراجعة';
  @override
  String get noOptions => 'لا توجد خيارات';
  @override
  String get empty => '(فارغ)';
  @override
  String get none => '(لا شيء)';
  @override
  String get yes => 'نعم';
  @override
  String get no => 'لا';
  @override
  String get actions => 'إجراءات';
  @override
  String get day => 'يوم';
  @override
  String get month => 'شهر';
  @override
  String get year => 'سنة';

  // Input Helpers
  @override
  String get typeAndPressEnter => 'اكتب واضغط Enter';
  @override
  String get typeToAddTag => 'اكتب واضغط Enter لإضافة وسم';
  @override
  String get searchPlaceholder => 'بحث...';

  // Validation Messages
  @override
  String get fieldRequired => 'هذا الحقل مطلوب';
  @override
  String get invalidEmail => 'بريد إلكتروني غير صالح';
  @override
  String get invalidUrl => 'رابط غير صالح';
  @override
  String get invalidNumber => 'رقم غير صالح';
  @override
  String get mustBeNumber => 'يجب أن يكون رقمًا';
  @override
  String get invalidValue => 'قيمة غير صالحة';
  @override
  String get invalidFormat => 'تنسيق غير صالح';

  // Signature & Sketchpad
  @override
  String get clearSignature => 'مسح';
  @override
  String get clearCanvas => 'مسح';
  @override
  String get undoLastStroke => 'تراجع';
  @override
  String get color => 'اللون';
  @override
  String get size => 'الحجم';
  @override
  String get eraser => 'ممحاة';

  // Review Page
  @override
  String get review => 'مراجعة';
  @override
  String get reviewYourSubmission => 'راجع إدخالك';

  // Wizard
  @override
  String get noStepsConfigured => 'لم يتم تكوين أي خطوات';
  @override
  String get noEntriesAdded => 'لم تتم إضافة أي إدخالات بعد';

  // Composed messages (Arabic word order)
  @override
  String getRequiredMessage(String fieldLabel) => '$fieldLabel مطلوب.';

  @override
  String getStepMessage(int current, int total) => 'خطوة $current من $total';

  /// Provides Arabic resource values for Form.io widgets.
  static Future<FormioLocalizations> load(Locale locale) {
    return SynchronousFuture<FormioLocalizations>(
        const ArabicFormioLocalizations());
  }

  /// A [LocalizationsDelegate] for Arabic Form.io localizations.
  static const LocalizationsDelegate<FormioLocalizations> delegate =
      _ArabicFormioLocalizationsDelegate();
}

class _ArabicFormioLocalizationsDelegate
    extends LocalizationsDelegate<FormioLocalizations> {
  const _ArabicFormioLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ar';

  @override
  Future<FormioLocalizations> load(Locale locale) =>
      ArabicFormioLocalizations.load(locale);

  @override
  bool shouldReload(_ArabicFormioLocalizationsDelegate old) => false;

  @override
  String toString() => 'ArabicFormioLocalizations.delegate(ar)';
}
