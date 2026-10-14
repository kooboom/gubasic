import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_playground/src/model/i18n.dart';
import 'package:test/test.dart';

void main() {
  test('every UI text exists in every language', () {
    for (final locale in Locale.values) {
      for (final key in UiText.values) {
        expect(uiTexts[locale]![key], isNotNull,
            reason: '${locale.code} ${key.name}');
        expect(locale[key], isNotEmpty);
      }
      expect(uiTexts[locale]!.length, UiText.values.length);
    }
  });

  test('the language button names the other language', () {
    expect(Locale.en[UiText.switchLanguage], '한국어');
    expect(Locale.ko[UiText.switchLanguage], 'English');
    expect(Locale.en.other, Locale.ko);
    expect(Locale.ko.other, Locale.en);
  });

  test('locale codes round-trip; unknown codes fall back to English', () {
    for (final l in Locale.values) {
      expect(Locale.fromCode(l.code), l);
    }
    expect(Locale.fromCode(null), Locale.en);
    expect(Locale.fromCode('fr'), Locale.en);
  });

  test('each locale uses its own diagnostic messages', () {
    expect(Locale.en.diagnosticMessages, same(englishMessages));
    expect(Locale.ko.diagnosticMessages, same(koreanMessages));
  });

  test('the footer has the development preview text', () {
    expect(Locale.en[UiText.footerPreview],
        'GuBASIC Playground — development preview');
  });
}
