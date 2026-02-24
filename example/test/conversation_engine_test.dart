import 'package:flutter_test/flutter_test.dart';
import 'package:formio_api/formio_api.dart';
import 'package:speech2form/services/conversation_engine.dart';

/// Helper to build a minimal FormModel with the given components JSON.
FormModel _buildForm(List<Map<String, dynamic>> componentsJson) {
  return FormModel.fromJson({
    '_id': 'test-form-id',
    'title': 'Test Form',
    'path': 'test',
    'components': componentsJson,
  });
}

void main() {
  group('ConversationEngine - Question Extraction', () {
    test('extracts flat text fields correctly', () {
      final form = _buildForm([
        {'type': 'textfield', 'key': 'name', 'label': 'Ad'},
        {'type': 'email', 'key': 'email', 'label': 'E-posta'},
        {'type': 'button', 'key': 'submit', 'label': 'Gönder'},
      ]);

      final engine = ConversationEngine(form: form);

      expect(engine.allQuestions.length, 2);
      expect(engine.allQuestions[0].key, 'name');
      expect(engine.allQuestions[1].key, 'email');
    });

    test('extracts nested questions from panels', () {
      final form = _buildForm([
        {
          'type': 'panel',
          'key': 'panel1',
          'label': 'Genel Bilgi',
          'components': [
            {'type': 'textfield', 'key': 'firstName', 'label': 'Ad'},
            {'type': 'textfield', 'key': 'lastName', 'label': 'Soyad'},
          ],
        },
      ]);

      final engine = ConversationEngine(form: form);

      expect(engine.allQuestions.length, 2);
      expect(engine.allQuestions[0].key, 'firstName');
      expect(engine.allQuestions[1].key, 'lastName');
    });

    test('extracts nested questions from columns', () {
      final form = _buildForm([
        {
          'type': 'columns',
          'key': 'cols',
          'label': '',
          'columns': [
            {
              'components': [
                {'type': 'textfield', 'key': 'left', 'label': 'Sol'},
              ],
            },
            {
              'components': [
                {'type': 'textfield', 'key': 'right', 'label': 'Sağ'},
              ],
            },
          ],
        },
      ]);

      final engine = ConversationEngine(form: form);

      expect(engine.allQuestions.length, 2);
      expect(engine.allQuestions[0].key, 'left');
      expect(engine.allQuestions[1].key, 'right');
    });

    test('skips hidden and button components', () {
      final form = _buildForm([
        {'type': 'textfield', 'key': 'visible', 'label': 'Görünen'},
        {'type': 'hidden', 'key': 'secret', 'label': 'Gizli'},
        {'type': 'button', 'key': 'submit', 'label': 'Gönder'},
      ]);

      final engine = ConversationEngine(form: form);

      expect(engine.allQuestions.length, 1);
      expect(engine.allQuestions[0].key, 'visible');
    });
  });

  group('ConversationEngine - Answer Flow', () {
    test('progress increases as questions are answered', () {
      final form = _buildForm([
        {'type': 'textfield', 'key': 'q1', 'label': 'Soru 1'},
        {'type': 'textfield', 'key': 'q2', 'label': 'Soru 2'},
        {'type': 'textfield', 'key': 'q3', 'label': 'Soru 3'},
      ]);

      final engine = ConversationEngine(form: form);

      expect(engine.progress, closeTo(0.0, 0.01));
      expect(engine.answeredCount, 0);

      engine.updateAnswer('q1', 'Cevap 1');
      expect(engine.progress, closeTo(0.33, 0.01));
      expect(engine.answeredCount, 1);

      engine.updateAnswer('q2', 'Cevap 2');
      expect(engine.progress, closeTo(0.67, 0.01));
      expect(engine.answeredCount, 2);

      engine.updateAnswer('q3', 'Cevap 3');
      expect(engine.progress, closeTo(1.0, 0.01));
      expect(engine.answeredCount, 3);
    });

    test('getNextQuestion skips answered questions', () {
      final form = _buildForm([
        {'type': 'textfield', 'key': 'q1', 'label': 'Soru 1'},
        {'type': 'textfield', 'key': 'q2', 'label': 'Soru 2'},
      ]);

      final engine = ConversationEngine(form: form);

      expect(engine.getNextQuestion()?.key, 'q1');

      engine.updateAnswer('q1', 'Cevap');
      expect(engine.getNextQuestion()?.key, 'q2');

      engine.updateAnswer('q2', 'Cevap 2');
      expect(engine.getNextQuestion(), isNull);
    });

    test('isComplete returns true when all questions answered', () {
      final form = _buildForm([
        {'type': 'textfield', 'key': 'q1', 'label': 'Soru 1'},
      ]);

      final engine = ConversationEngine(form: form);

      expect(engine.isComplete, isFalse);
      engine.updateAnswer('q1', 'Cevap');
      expect(engine.isComplete, isTrue);
    });

    test('onComplete callback fires when form is done', () {
      Map<String, dynamic>? completedData;
      final form = _buildForm([
        {'type': 'textfield', 'key': 'name', 'label': 'Ad'},
      ]);

      final engine = ConversationEngine(
        form: form,
        onComplete: (data) => completedData = data,
      );

      engine.updateAnswer('name', 'Mehmet');

      expect(completedData, isNotNull);
      expect(completedData!['name'], 'Mehmet');
    });
  });

  group('ConversationEngine - Undo', () {
    test('undoLastAnswer removes last answer', () {
      final form = _buildForm([
        {'type': 'textfield', 'key': 'q1', 'label': 'Soru 1'},
        {'type': 'textfield', 'key': 'q2', 'label': 'Soru 2'},
      ]);

      final engine = ConversationEngine(form: form);

      engine.updateAnswer('q1', 'Cevap 1');
      engine.updateAnswer('q2', 'Cevap 2');

      expect(engine.answeredCount, 2);
      expect(engine.canUndo, isTrue);

      final undoneKey = engine.undoLastAnswer();

      expect(undoneKey, 'q2');
      expect(engine.answeredCount, 1);
      expect(engine.getNextQuestion()?.key, 'q2');
      expect(engine.formData.containsKey('q2'), isFalse);
    });

    test('undoLastAnswer returns null when nothing to undo', () {
      final form = _buildForm([
        {'type': 'textfield', 'key': 'q1', 'label': 'Soru 1'},
      ]);

      final engine = ConversationEngine(form: form);

      expect(engine.canUndo, isFalse);
      expect(engine.undoLastAnswer(), isNull);
    });

    test('multiple undos work correctly', () {
      final form = _buildForm([
        {'type': 'textfield', 'key': 'q1', 'label': 'Soru 1'},
        {'type': 'textfield', 'key': 'q2', 'label': 'Soru 2'},
        {'type': 'textfield', 'key': 'q3', 'label': 'Soru 3'},
      ]);

      final engine = ConversationEngine(form: form);

      engine.updateAnswer('q1', 'A');
      engine.updateAnswer('q2', 'B');
      engine.updateAnswer('q3', 'C');

      engine.undoLastAnswer(); // removes q3
      engine.undoLastAnswer(); // removes q2

      expect(engine.answeredCount, 1);
      expect(engine.getNextQuestion()?.key, 'q2');
    });
  });

  group('ConversationEngine - Conditional Logic', () {
    test('conditional fields are hidden until trigger is answered', () {
      final form = _buildForm([
        {
          'type': 'radio',
          'key': 'hasPet',
          'label': 'Evcil hayvanınız var mı?',
          'values': [
            {'label': 'Evet', 'value': 'yes'},
            {'label': 'Hayır', 'value': 'no'},
          ],
        },
        {
          'type': 'textfield',
          'key': 'petName',
          'label': 'Evcil hayvanınızın adı',
          'conditional': {
            'show': true,
            'when': 'hasPet',
            'eq': 'yes',
          },
        },
      ]);

      final engine = ConversationEngine(form: form);

      // petName should be hidden initially
      expect(engine.totalVisibleQuestions, 1);
      expect(engine.getNextQuestion()?.key, 'hasPet');

      // Answer "yes" — petName should become visible
      engine.updateAnswer('hasPet', 'yes');
      expect(engine.totalVisibleQuestions, 2);
      expect(engine.getNextQuestion()?.key, 'petName');
    });

    test('conditional fields stay hidden when condition not met', () {
      final form = _buildForm([
        {
          'type': 'radio',
          'key': 'hasPet',
          'label': 'Evcil hayvanınız var mı?',
          'values': [
            {'label': 'Evet', 'value': 'yes'},
            {'label': 'Hayır', 'value': 'no'},
          ],
        },
        {
          'type': 'textfield',
          'key': 'petName',
          'label': 'Evcil hayvanınızın adı',
          'conditional': {
            'show': true,
            'when': 'hasPet',
            'eq': 'yes',
          },
        },
      ]);

      final engine = ConversationEngine(form: form);

      engine.updateAnswer('hasPet', 'no');
      expect(engine.totalVisibleQuestions, 1);
      expect(engine.isComplete, isTrue); // Only hasPet is visible and answered
    });

    test('undo removes dependent conditional answers', () {
      final form = _buildForm([
        {
          'type': 'radio',
          'key': 'hasPet',
          'label': 'Evcil hayvanınız var mı?',
          'values': [
            {'label': 'Evet', 'value': 'yes'},
            {'label': 'Hayır', 'value': 'no'},
          ],
        },
        {
          'type': 'textfield',
          'key': 'petName',
          'label': 'Evcil hayvanınızın adı',
          'conditional': {
            'show': true,
            'when': 'hasPet',
            'eq': 'yes',
          },
        },
      ]);

      final engine = ConversationEngine(form: form);

      engine.updateAnswer('hasPet', 'yes');
      engine.updateAnswer('petName', 'Karabaş');

      // Undo hasPet — petName should also be removed
      engine.undoLastAnswer(); // undoes petName
      engine.undoLastAnswer(); // undoes hasPet → petName was already gone

      expect(engine.answeredCount, 0);
      expect(engine.formData.containsKey('petName'), isFalse);
    });
  });

  group('ConversationEngine - Answer Parsing', () {
    test('parses checkbox answers correctly', () {
      final form = _buildForm([
        {'type': 'checkbox', 'key': 'agree', 'label': 'Kabul'},
      ]);

      final engine = ConversationEngine(form: form);
      final question = engine.allQuestions.first;

      expect(engine.parseAnswer(question, 'evet'), isTrue);
      expect(engine.parseAnswer(question, 'hayır'), isFalse);
      expect(engine.parseAnswer(question, 'doğru'), isTrue);
      expect(engine.parseAnswer(question, 'yanlış'), isFalse);
    });

    test('parses number answers correctly', () {
      final form = _buildForm([
        {'type': 'number', 'key': 'age', 'label': 'Yaş'},
      ]);

      final engine = ConversationEngine(form: form);
      final question = engine.allQuestions.first;

      expect(engine.parseAnswer(question, '25'), 25);
      expect(engine.parseAnswer(question, '3.14'), closeTo(3.14, 0.01));
    });

    test('parses select options by label match', () {
      final form = _buildForm([
        {
          'type': 'select',
          'key': 'city',
          'label': 'Şehir',
          'data': {
            'values': [
              {'label': 'İstanbul', 'value': 'ist'},
              {'label': 'Ankara', 'value': 'ank'},
              {'label': 'İzmir', 'value': 'izm'},
            ],
          },
        },
      ]);

      final engine = ConversationEngine(form: form);
      final question = engine.allQuestions.first;

      expect(engine.parseAnswer(question, 'istanbul'), 'ist');
      expect(engine.parseAnswer(question, 'ankara'), 'ank');
    });
  });

  group('ConversationEngine - Question Text Builder', () {
    test('builds appropriate text for different component types', () {
      final form = _buildForm([
        {'type': 'textfield', 'key': 'name', 'label': 'Adınız'},
        {'type': 'number', 'key': 'age', 'label': 'Yaşınız'},
        {'type': 'checkbox', 'key': 'agree', 'label': 'Onaylıyor musunuz'},
        {'type': 'datetime', 'key': 'dob', 'label': 'Doğum tarihi'},
      ]);

      final engine = ConversationEngine(form: form);
      final questions = engine.allQuestions;

      expect(engine.buildQuestionText(questions[0]), 'Adınız');
      expect(engine.buildQuestionText(questions[1]),
          contains('Lütfen bir sayı belirtin'));
      expect(engine.buildQuestionText(questions[2]),
          contains('Evet veya hayır'));
      expect(engine.buildQuestionText(questions[3]),
          contains('Lütfen bir tarih belirtin'));
    });

    test('builds options text for select components', () {
      final form = _buildForm([
        {
          'type': 'select',
          'key': 'color',
          'label': 'Renk seçin',
          'data': {
            'values': [
              {'label': 'Kırmızı', 'value': 'red'},
              {'label': 'Mavi', 'value': 'blue'},
            ],
          },
        },
      ]);

      final engine = ConversationEngine(form: form);
      final text = engine.buildQuestionText(engine.allQuestions.first);

      expect(text, contains('Kırmızı'));
      expect(text, contains('Mavi'));
    });
  });

  group('ConversationEngine - TTS Text Truncation', () {
    test('buildTtsText returns full text when options <= threshold', () {
      final form = _buildForm([
        {
          'type': 'select',
          'key': 'color',
          'label': 'Renk seçin',
          'data': {
            'values': [
              {'label': 'Kırmızı', 'value': 'red'},
              {'label': 'Mavi', 'value': 'blue'},
            ],
          },
        },
      ]);

      final engine = ConversationEngine(form: form);
      final question = engine.allQuestions.first;

      final displayText = engine.buildQuestionText(question);
      final ttsText = engine.buildTtsText(question);

      // 2 options <= threshold (3), so TTS text == display text
      expect(ttsText, equals(displayText));
      expect(ttsText, contains('Kırmızı'));
      expect(ttsText, contains('Mavi'));
    });

    test('buildTtsText truncates when options > threshold', () {
      final form = _buildForm([
        {
          'type': 'select',
          'key': 'city',
          'label': 'Şehir seçin',
          'data': {
            'values': [
              {'label': 'İstanbul', 'value': 'ist'},
              {'label': 'Ankara', 'value': 'ank'},
              {'label': 'İzmir', 'value': 'izm'},
              {'label': 'Bursa', 'value': 'brs'},
              {'label': 'Antalya', 'value': 'ant'},
            ],
          },
        },
      ]);

      final engine = ConversationEngine(form: form);
      final question = engine.allQuestions.first;

      final displayText = engine.buildQuestionText(question);
      final ttsText = engine.buildTtsText(question);

      // Display text should contain all options
      expect(displayText, contains('İstanbul'));
      expect(displayText, contains('Antalya'));

      // TTS text should NOT contain option names
      expect(ttsText, isNot(contains('İstanbul')));
      expect(ttsText, isNot(contains('Antalya')));
      expect(ttsText, contains('Şehir seçin'));
      expect(ttsText, contains('seçeneklerden'));
    });

    test('buildTtsText truncates selectboxes with many options', () {
      final form = _buildForm([
        {
          'type': 'selectboxes',
          'key': 'hobbies',
          'label': 'Hobileriniz',
          'values': [
            {'label': 'Yüzme', 'value': 'swim'},
            {'label': 'Koşu', 'value': 'run'},
            {'label': 'Bisiklet', 'value': 'bike'},
            {'label': 'Yoga', 'value': 'yoga'},
          ],
        },
      ]);

      final engine = ConversationEngine(form: form);
      final question = engine.allQuestions.first;

      final displayText = engine.buildQuestionText(question);
      final ttsText = engine.buildTtsText(question);

      // Display text has full list
      expect(displayText, contains('Yüzme'));
      expect(displayText, contains('Yoga'));

      // TTS text is short
      expect(ttsText, isNot(contains('Yüzme')));
      expect(ttsText, contains('Hobileriniz'));
    });

    test('buildTtsText falls back to buildQuestionText for non-list types',
        () {
      final form = _buildForm([
        {'type': 'textfield', 'key': 'name', 'label': 'Adınız'},
        {'type': 'number', 'key': 'age', 'label': 'Yaşınız'},
      ]);

      final engine = ConversationEngine(form: form);

      for (final q in engine.allQuestions) {
        expect(engine.buildTtsText(q), equals(engine.buildQuestionText(q)));
      }
    });

    test('buildTtsText truncates radio with many options', () {
      final form = _buildForm([
        {
          'type': 'radio',
          'key': 'rating',
          'label': 'Değerlendirme',
          'values': [
            {'label': 'Çok Kötü', 'value': '1'},
            {'label': 'Kötü', 'value': '2'},
            {'label': 'Orta', 'value': '3'},
            {'label': 'İyi', 'value': '4'},
            {'label': 'Çok İyi', 'value': '5'},
          ],
        },
      ]);

      final engine = ConversationEngine(form: form);
      final question = engine.allQuestions.first;

      final displayText = engine.buildQuestionText(question);
      final ttsText = engine.buildTtsText(question);

      // Display text has all 5 options
      expect(displayText, contains('Çok Kötü'));
      expect(displayText, contains('Çok İyi'));

      // TTS text is short
      expect(ttsText, isNot(contains('Çok Kötü')));
      expect(ttsText, contains('Değerlendirme'));
    });
  });
}
