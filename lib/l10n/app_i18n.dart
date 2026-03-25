import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AppLanguageController extends ChangeNotifier {
  AppLanguageController._();

  static final AppLanguageController instance = AppLanguageController._();

  String _languageCode = 'id';

  String get languageCode => _languageCode;

  Locale get locale => Locale(_languageCode);

  void setLanguage(String code) {
    final normalized = AppI18n.supportedLanguageCodes.contains(code)
        ? code
        : 'id';
    if (normalized == _languageCode) {
      return;
    }
    _languageCode = normalized;
    notifyListeners();
  }
}

class AppI18n {
  AppI18n._({
    required this.locale,
    required Map<String, String> values,
  }) : _values = values;

  final Locale locale;
  final Map<String, String> _values;
  static const LocalizationsDelegate<AppI18n> delegate = _AppI18nDelegate();

  static const List<String> supportedLanguageCodes = [
    'en',
    'it',
    'ru',
    'zh',
    'pt',
    'ja',
    'th',
    'ar',
    'fr',
    'pl',
    'vi',
    'es',
    'de',
    'hi',
    'id',
  ];

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('it'),
    Locale('ru'),
    Locale('zh'),
    Locale('pt'),
    Locale('ja'),
    Locale('th'),
    Locale('ar'),
    Locale('fr'),
    Locale('pl'),
    Locale('vi'),
    Locale('es'),
    Locale('de'),
    Locale('hi'),
    Locale('id'),
  ];

  static AppI18n of(BuildContext context) {
    final value = Localizations.of<AppI18n>(context, AppI18n);
    return value ??
        AppI18n._(
          locale: const Locale('id'),
          values: const <String, String>{},
        );
  }

  String tr(String key, {Map<String, String> params = const {}}) {
    var value = _values[key] ?? key;
    for (final entry in params.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value);
    }
    return value;
  }

  static final Map<String, Map<String, String>> _cache = {};

  static Future<Map<String, String>> _loadLanguage(String code) async {
    if (_cache.containsKey(code)) {
      return _cache[code]!;
    }
    try {
      final raw = await rootBundle.loadString('assets/l10n/$code.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final values = decoded.map((k, v) => MapEntry(k, v.toString()));
        _cache[code] = values;
        return values;
      }
    } catch (_) {}
    _cache[code] = const <String, String>{};
    return _cache[code]!;
  }

  static Future<AppI18n> load(Locale locale) async {
    final languageCode = supportedLanguageCodes.contains(locale.languageCode)
        ? locale.languageCode
        : 'id';
    final fallbackValues = await _loadLanguage('en');
    final localizedValues = languageCode == 'en'
        ? fallbackValues
        : await _loadLanguage(languageCode);
    final merged = <String, String>{
      ...fallbackValues,
      ...localizedValues,
    };
    return AppI18n._(
      locale: Locale(languageCode),
      values: merged,
    );
  }
}

class _AppI18nDelegate extends LocalizationsDelegate<AppI18n> {
  const _AppI18nDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppI18n.supportedLanguageCodes.contains(locale.languageCode);
  }

  @override
  Future<AppI18n> load(Locale locale) async {
    return AppI18n.load(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppI18n> old) {
    return false;
  }
}
