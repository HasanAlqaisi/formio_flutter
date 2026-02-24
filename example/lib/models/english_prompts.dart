/// EnglishPrompts — full English translation of [PromptDictionary].
///
/// Set globally via:
/// ```dart
/// PromptDictionary.current = EnglishPrompts();
/// ```
library;

import 'turkish_prompts.dart';

class EnglishPrompts extends PromptDictionary {
  @override
  String get sttLocaleId => 'en_US';

  @override
  String get ttsLanguage => 'en-US';
  // ═══════════════════════════════════════════════════════════
  //  AI SYSTEM PROMPT
  // ═══════════════════════════════════════════════════════════

  @override
  String systemPrompt(String typeInstructions) =>
      '''You are a form-filling assistant. You convert the user's spoken answer into a value appropriate for the form field type.

GENERAL RULES:
1. ONLY respond in JSON format.
2. Clean up speech artifacts (um, uh, like, you know).
3. Evaluate in an English-language context.
4. If the user's answer is completely meaningless or empty: {"value": ""}

TYPE-SPECIFIC INSTRUCTIONS:
$typeInstructions''';

  // ═══════════════════════════════════════════════════════════
  //  PER-TYPE AI PROMPT TEMPLATES
  // ═══════════════════════════════════════════════════════════

  @override
  String textFieldPrompt({int? maxLength, int? minLength}) =>
      '''Convert the user's spoken answer into a clean text value.
Rules:
- Capitalize the first letter, keep the rest natural.
- Remove speech artifacts (um, uh, like, you know).
- Remove unnecessary repetitions.
${maxLength != null ? '- Maximum $maxLength characters. Truncate if longer.' : ''}
${minLength != null ? '- Minimum $minLength characters.' : ''}
- Output: {"value": "cleaned text"}''';

  @override
  String textAreaPrompt({int? maxLength}) =>
      '''Convert the user's spoken answer into a multi-line text value.
Rules:
- Preserve the natural speaking tone but clean up speech artifacts.
- Fix sentence structure, add punctuation.
${maxLength != null ? '- Maximum $maxLength characters. Summarize if exceeding.' : ''}
- Output: {"value": "formatted text"}''';

  @override
  String get passwordPrompt =>
      '''Record the user's spoken password exactly as stated.
Rules:
- Preserve letters exactly (pay attention to uppercase/lowercase).
- "capital a", "lowercase b" → convert to appropriate letter.
- Special characters ("dot", "at sign", "underscore") → convert to symbols.
- Output: {"value": "password_text"}''';

  @override
  String get emailPrompt =>
      '''Format the user's spoken email address.
Rules:
- "at" or "at sign" → @
- "dot" or "period" → .
- Recognize domain names like "gmail", "hotmail", "outlook".
- Remove spaces, convert to lowercase.
- Example: "john at gmail dot com" → "john@gmail.com"
- Output: {"value": "email@domain.com"}''';

  @override
  String get phonePrompt =>
      '''Format the user's spoken phone number.
Rules:
- Convert spoken numbers to digits ("five hundred" → 500).
- Keep only digits, drop extra words.
- Standard format: preserve as spoken (with country code if given).
- Output: {"value": "1234567890"}''';

  @override
  String get urlPrompt =>
      '''Format the user's spoken URL.
Rules:
- "dot" or "period" → .
- "slash" or "forward slash" → /
- "w w w" or "triple w" → www
- Add "https://" if no protocol specified.
- Remove spaces, convert to lowercase.
- Output: {"value": "https://..."}''';

  @override
  String numberPrompt({dynamic min, dynamic max, dynamic decimalLimit}) =>
      '''Extract the number from the user's spoken answer.
Rules:
- Convert spoken numbers to numeric values ("one hundred fifty" → 150, "three and a half" → 3.5).
- Return only the numeric value, no units or extra words.
${min != null ? '- Minimum value: $min' : ''}
${max != null ? '- Maximum value: $max' : ''}
${decimalLimit != null ? '- Decimal places limit: $decimalLimit' : ''}
- Output: {"value": 123} (number type, not string)''';

  @override
  String currencyPrompt({String currency = 'USD', int decimalLimit = 2}) =>
      '''Extract the monetary amount from the user's spoken answer.
Rules:
- Convert spoken numbers to numeric values.
- Currency: $currency
- Ignore currency words ("dollars", "euros", "pounds") — just extract the number.
- Decimal places: $decimalLimit
- Output: {"value": 150.00} (number type)''';

  @override
  String get singleSelectPrompt =>
      '''Match the user's spoken answer to one of the given options.
Rules:
- Compare the user's text against option labels.
- Exact match not required; return the VALUE of the closest matching label.
- Ignore case differences.
- If no option matches: {"value": ""}
- Output: {"value": "matched_option_value"}''';

  @override
  String get radioPrompt =>
      '''Match the user's spoken answer to one of the radio button options.
Rules:
- Only ONE option can match.
- Compare the user's text against option labels.
- Return the VALUE of the closest match.
- Ignore case differences.
- Output: {"value": "matched_value"}''';

  @override
  String get multiSelectPrompt =>
      '''Match the user's spoken answer to multiple options.
Rules:
- The user may mention multiple options ("first and third", "a, b, and d").
- Set each option key to true/false.
- Mentioned options → true, others → false.
- "all" or "everything" → set all to true.
- "none" or "nothing" → set all to false.
- MANDATORY: Use the exact "value" keys from the provided options list as keys.
- Output format: {"value": {"<actual_value>": true, "<actual_value>": false}}
- Example: if options have values a1, a2, a3 → {"value": {"a1": true, "a2": false, "a3": true}}''';

  @override
  String get checkboxPrompt =>
      '''Convert the user's spoken answer to a yes/no value.
Rules:
- "yes", "correct", "okay", "sure", "accept", "true" → true
- "no", "wrong", "nope", "decline", "false" → false
- If unclear (neither yes nor no) → false
- Output: {"value": true} or {"value": false}''';

  @override
  String datePrompt({bool includeTime = false}) =>
      '''Convert the user's spoken ${includeTime ? 'date and time' : 'date'} to ISO 8601 format.
Rules:
- Recognize English month names: January, February, March, April, May, June, July, August, September, October, November, December.
- Convert relative expressions: "today", "tomorrow", "yesterday", "next week", "next Monday".
- Use today's date as the reference.
- If no year specified, use the current year.
${includeTime ? '- If no time specified, use 00:00.' : ''}
- Format: ${includeTime ? 'YYYY-MM-DDTHH:mm:ss.000Z' : 'YYYY-MM-DD'}
- Output: {"value": "${includeTime ? '2026-02-25T14:30:00.000Z' : '2026-02-25'}"}''';

  @override
  String get timePrompt =>
      '''Format the user's spoken time.
Rules:
- Recognize time expressions: "three thirty" → 15:30, "eight in the morning" → 08:00
- "half past" → :30, "quarter past" → :15, "quarter to" → :45
- Use 24-hour format.
- Understand AM/PM context: "morning", "afternoon", "evening", "night"
- Format: HH:mm
- Output: {"value": "15:30"}''';

  @override
  String get tagsPrompt =>
      '''Separate the user's spoken tags/keywords.
Rules:
- Recognize separators: commas, "and", "also".
- List each tag as a separate item.
- Convert tags to lowercase and trim whitespace.
- Output: {"value": "tag1,tag2,tag3"}''';

  @override
  String get addressPrompt =>
      '''Convert the user's spoken address into a structured format.
Rules:
- Organize address details as clearly as possible.
- Extract street, city, state, zip code, country if mentioned.
- Output: {"value": "formatted address text"}''';

  // ═══════════════════════════════════════════════════════════
  //  SURVEY PROMPT (Feature 3)
  // ═══════════════════════════════════════════════════════════

  @override
  String get surveyPrompt =>
      '''Match the user's spoken answer to one of the given survey rating options.
Rules:
- Compare the user's text against the available rating labels.
- Return the VALUE of the closest matching label.
- Ignore case differences.
- If no option matches: {"value": ""}
- Output: {"value": "matched_rating_value"}''';

  @override
  String surveyQuestionPrompt(String questionLabel, List<String> options) =>
      '$questionLabel. Please choose one: ${options.join(", ")}';

  // ═══════════════════════════════════════════════════════════
  //  DATAGRID PROMPTS (Feature 5)
  // ═══════════════════════════════════════════════════════════

  @override
  String datagridStartPrompt(String label, List<String> columns) =>
      'We\'ll fill the "$label" table row by row. '
      'Columns: ${columns.join(", ")}. Let\'s start with row 1.';

  @override
  String datagridRowPrompt(int rowNum) => 'Row $rowNum';

  @override
  String get datagridAddMorePrompt =>
      'Would you like to add another row? (Yes / No)';

  @override
  String get datagridPrompt =>
      '''Convert the user's spoken answer for this table cell.
Rules:
- Extract the relevant value for the current column.
- Clean up speech artifacts.
- Output: {"value": "cell value"}''';

  // ═══════════════════════════════════════════════════════════
  //  SKIP REASONS
  // ═══════════════════════════════════════════════════════════

  @override
  String get skipSignature => 'Signature component cannot be filled by voice';
  @override
  String get skipFile => 'File upload cannot be done by voice';
  @override
  String get skipCaptcha => 'CAPTCHA verification cannot be done by voice';
  @override
  String get skipSketchpad => 'Sketch pad cannot be filled by voice';
  @override
  String get skipTagpad => 'Tag pad cannot be filled by voice';
  @override
  String get skipHidden => 'Hidden field, no user input required';
  @override
  String get skipButton => 'Button component, no input required';
  @override
  String get skipDatasource => 'Data source component, no input required';
  @override
  String get skipContainer => 'Container component cannot be filled by voice';
  @override
  String get skipDatagrid => 'Data grid cannot be filled by voice';
  @override
  String get skipEditgrid => 'Editable grid cannot be filled by voice';
  @override
  String get skipNestedform => 'Nested form cannot be filled by voice';
  @override
  String get skipForm => 'Sub-form cannot be filled by voice';
  @override
  String get skipDynamicwizard =>
      'Dynamic wizard cannot be filled by voice';
  @override
  String get skipDatatable => 'Data table cannot be filled by voice';
  @override
  String get skipDatamap => 'Data map cannot be filled by voice';
  @override
  String get skipReviewpage => 'Review page, no input required';
  @override
  String get skipCustom => 'Custom component cannot be filled by voice';
  @override
  String get skipSurvey => 'Survey component not yet supported by voice';
  @override
  String get skipDefault => 'This component cannot be filled by voice';

  // ═══════════════════════════════════════════════════════════
  //  QUESTION TEXT TEMPLATES (spoken by TTS)
  // ═══════════════════════════════════════════════════════════

  @override
  String questionNumber(String label) =>
      '$label. Please specify a number.';
  @override
  String questionCheckbox(String label) =>
      '$label. Answer yes or no.';
  @override
  String questionDate(String label) =>
      '$label. Please specify a date.';
  @override
  String questionTime(String label) =>
      '$label. Please specify a time.';
  @override
  String questionSelectOne(String label, List<String> options) =>
      '$label. Choose one of these options: ${options.join(", ")}';
  @override
  String questionSelectMulti(String label, List<String> options) =>
      '$label. Choose one or more of these options: ${options.join(", ")}';

  // ── TTS-short variants ──

  @override
  String questionSelectOneTts(String label, List<String> options) =>
      options.length > PromptDictionary.ttsListThreshold
          ? '$label. Please choose one of the options.'
          : questionSelectOne(label, options);

  @override
  String questionSelectMultiTts(String label, List<String> options) =>
      options.length > PromptDictionary.ttsListThreshold
          ? '$label. Please choose one or more of the options.'
          : questionSelectMulti(label, options);

  @override
  String surveyQuestionPromptTts(
          String questionLabel, List<String> options) =>
      options.length > PromptDictionary.ttsListThreshold
          ? '$questionLabel. Please say a rating.'
          : surveyQuestionPrompt(questionLabel, options);

  // ═══════════════════════════════════════════════════════════
  //  CHAT SCREEN UI STRINGS
  // ═══════════════════════════════════════════════════════════

  @override
  String welcomeMessage(String formTitle) =>
      'Hello! Let\'s fill out the "$formTitle" form together. '
      'I\'ll ask the questions aloud — press the microphone button to answer '
      'or tap the keyboard icon to type your response.';

  @override
  String get sttUnavailable =>
      'Speech recognition is unavailable. Text input has been enabled.';
  @override
  String get aiFailedFallback =>
      'AI evaluation failed, the answer was saved directly.';
  @override
  String get formComplete =>
      'All questions have been answered! Form summary is below.';
  @override
  String answerUndone(String label) => '"$label" answer has been undone.';
  @override
  String answerRecorded(String value) => 'Recorded: $value';
  @override
  String get questionRequired =>
      'This question is required and cannot be skipped.';
  @override
  String questionSkipped(String label) => '"$label" skipped.';
  @override
  String get silenceSkipped =>
      'No answer detected, question skipped.';
  @override
  String get silenceRequiredWarning =>
      'This field is required and cannot be left blank. Please answer.';
  @override
  String get emptyAnswerSkipped =>
      'Empty answer, question skipped.';
  @override
  String get emptyAnswerRequiredWarning =>
      'This field is required and cannot be empty. Please enter an answer.';

  // ── Tooltips & Labels ──
  @override
  String get tooltipUndo => 'Undo last answer';
  @override
  String get tooltipReset => 'Reset form';
  @override
  String get resetConfirmTitle => 'Reset Form';
  @override
  String get resetConfirmMessage =>
      'All answers will be cleared and the form will start over. Are you sure?';
  @override
  String get resetConfirmYes => 'Yes, Reset';
  @override
  String get resetConfirmNo => 'Cancel';
  @override
  String get formResetDone => 'Form has been reset. Starting from the beginning.';
  @override
  String get tooltipRepeat => 'Repeat question';
  @override
  String get tooltipHideKeyboard => 'Hide keyboard';
  @override
  String get tooltipShowKeyboard => 'Type with keyboard';
  @override
  String get tooltipSkip => 'Skip question';
  @override
  String get hintTextInput => 'Type your answer...';
  @override
  String get labelInitializing => 'Initializing voice services...';
  @override
  String get labelYes => 'Yes';
  @override
  String get labelNo => 'No';

  // ── Form Summary Dialog ──
  @override
  String get summaryTitle => 'Form Summary';
  @override
  String get summaryCompleted => 'Form Completed!';
  @override
  String get summaryReview => 'Review your answers';
  @override
  String get summaryEdit => 'Edit';
  @override
  String get summarySubmit => 'Submit';
  @override
  String get summaryNotAnswered => 'Not answered';
  @override
  String summaryEditField(String label) =>
      'Editing "$label". Say or type your new answer.';

  // ── Confirmation Flow ──
  @override
  String confirmationAsk(String value) =>
      'Should I save it as "$value"? (Yes / No)';
  @override
  String get confirmationAccepted => 'Answer saved.';
  @override
  String get confirmationRejected =>
      'Answer rejected. Please answer again.';

  // ── Welcome Animation ──
  @override
  String get welcomeAnimTitle => 'Speech2Form';
  @override
  String get welcomeAnimSubtitle => 'Voice-Powered Form Assistant';
  @override
  String get welcomeAnimStart => 'Start';

  // ── Session Persistence ──
  @override
  String get sessionResumed =>
      'Previous session restored. You can continue where you left off.';
  @override
  String get sessionResumeContinue => 'Continue';
  @override
  String get sessionResumeRestart => 'Start Over';

  // ── AI Fallback ──
  @override
  String get aiFallbackActivated =>
      'AI encountered too many errors. Switched to local processing mode.';
  @override
  String get aiFallbackLabel => 'Artificial Intelligence (AI)';
  @override
  String get aiFallbackDescription =>
      'AI disabled, answers are processed locally.';
  @override
  String get aiActiveDescription =>
      'Answers are processed with OpenAI.';

  // ── Pre-Start Config Screen ──
  @override
  String get configTitle => 'Form Settings';
  @override
  String get configSubtitle => 'Set your preferences before starting';
  @override
  String get configConfirmation => 'Answer Confirmation';
  @override
  String get configConfirmationDesc =>
      'Asks "Is this correct?" after each answer';
  @override
  String get configAiMode => 'AI Mode';
  @override
  String get configAiModeDesc =>
      'Smart answer processing with OpenAI';
  @override
  String get configAiLocalDesc =>
      'Local answer processing (without AI)';
  @override
  String get configStartButton => 'Start Form';

  // ── Skip Optional ──
  @override
  String get configSkipOptional => 'Skip Optionals';
  @override
  String get configSkipOptionalDesc =>
      'Automatically skip non-required fields';
  @override
  String optionalFieldSkipped(String label) =>
      '"$label" is optional — skipped.';

  // ── Offline Mode (Feature 4) ──
  @override
  String get configOfflineMode => 'Offline Mode';
  @override
  String get configOfflineModeDesc =>
      'Use on-device speech recognition (no internet required)';
  @override
  String get offlineModeActivated =>
      'Offline mode enabled. Using on-device speech recognition.';

  // ── Language ──
  @override
  String get configLanguage => 'Language';
  @override
  String get configLanguageDesc => 'Change the interface and AI language';

  // ── Form Compatibility ──
  @override
  String get incompatibleFormTitle => 'Incompatible Form';
  @override
  String get incompatibleFormMessage =>
      'This form contains required field(s) that cannot be filled by voice. '
      'The form cannot be completed because these fields are unsupported.';
  @override
  String get incompatibleFieldsHeader => 'Unsupported required fields:';
  @override
  String get incompatibleGoBack => 'Go Back';
}
