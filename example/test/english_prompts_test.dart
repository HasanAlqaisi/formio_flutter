import 'package:flutter_test/flutter_test.dart';
import 'package:speech2form/models/english_prompts.dart';
import 'package:speech2form/models/prompt_dictionary.dart';

void main() {
  group('EnglishPrompts', () {
    late EnglishPrompts en;

    setUp(() {
      en = EnglishPrompts();
    });

    test('factory forLocale returns EnglishPrompts for "en"', () {
      final dict = PromptDictionary.forLocale('en');
      expect(dict, isA<EnglishPrompts>());
    });

    test('factory forLocale returns PromptDictionary for "tr"', () {
      final dict = PromptDictionary.forLocale('tr');
      expect(dict, isA<PromptDictionary>());
      expect(dict, isNot(isA<EnglishPrompts>()));
    });

    test('sttLocaleId is en_US', () {
      expect(en.sttLocaleId, 'en_US');
    });

    test('ttsLanguage is en-US', () {
      expect(en.ttsLanguage, 'en-US');
    });

    test('systemPrompt returns non-empty English text', () {
      final prompt = en.systemPrompt('test instructions');
      expect(prompt, isNotEmpty);
      expect(prompt, contains('form-filling assistant'));
      expect(prompt, contains('test instructions'));
    });

    test('all skip reasons return non-empty strings', () {
      expect(en.skipSignature, isNotEmpty);
      expect(en.skipFile, isNotEmpty);
      expect(en.skipCaptcha, isNotEmpty);
      expect(en.skipSketchpad, isNotEmpty);
      expect(en.skipTagpad, isNotEmpty);
      expect(en.skipHidden, isNotEmpty);
      expect(en.skipButton, isNotEmpty);
      expect(en.skipDatasource, isNotEmpty);
      expect(en.skipContainer, isNotEmpty);
      expect(en.skipDatagrid, isNotEmpty);
      expect(en.skipEditgrid, isNotEmpty);
      expect(en.skipNestedform, isNotEmpty);
      expect(en.skipForm, isNotEmpty);
      expect(en.skipDynamicwizard, isNotEmpty);
      expect(en.skipDatatable, isNotEmpty);
      expect(en.skipDatamap, isNotEmpty);
      expect(en.skipReviewpage, isNotEmpty);
      expect(en.skipCustom, isNotEmpty);
      expect(en.skipSurvey, isNotEmpty);
      expect(en.skipDefault, isNotEmpty);
    });

    test('question text templates return English text', () {
      expect(en.questionNumber('Age'), contains('Age'));
      expect(en.questionCheckbox('Agree'), contains('yes'));
      expect(en.questionDate('Birthday'), contains('Birthday'));
      expect(en.questionTime('Time'), contains('Time'));
      expect(en.questionSelectOne('Color', ['Red', 'Blue']),
          contains('Red'));
      expect(en.questionSelectMulti('Colors', ['Red', 'Blue']),
          contains('one or more'));
    });

    test('UI strings are in English', () {
      expect(en.welcomeAnimTitle, contains('Speech2Form'));
      expect(en.configTitle, contains('Settings'));
      expect(en.summaryTitle, contains('Summary'));
      expect(en.labelYes, 'Yes');
      expect(en.labelNo, 'No');
    });

    test('survey prompts return English text', () {
      expect(en.surveyPrompt, contains('survey'));
      expect(
        en.surveyQuestionPrompt('Quality', ['Good', 'Bad']),
        contains('Good'),
      );
    });

    test('datagrid prompts return English text', () {
      expect(en.datagridPrompt, contains('table cell'));
      expect(
        en.datagridStartPrompt('Medications', ['Name', 'Dose']),
        contains('Medications'),
      );
      expect(en.datagridRowPrompt(1), contains('Row 1'));
      expect(en.datagridAddMorePrompt, contains('another row'));
    });

    test('offline mode strings are in English', () {
      expect(en.configOfflineMode, contains('Offline'));
      expect(en.offlineModeActivated, contains('Offline'));
    });

    test('switching locale works correctly', () {
      PromptDictionary.current = PromptDictionary.forLocale('en');
      PromptDictionary.currentLocale = 'en';
      expect(PromptDictionary.current, isA<EnglishPrompts>());
      expect(PromptDictionary.currentLocale, 'en');

      // Switch back to Turkish
      PromptDictionary.current = PromptDictionary.forLocale('tr');
      PromptDictionary.currentLocale = 'tr';
      expect(PromptDictionary.current, isNot(isA<EnglishPrompts>()));
      expect(PromptDictionary.currentLocale, 'tr');
    });
  });
}
