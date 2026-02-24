# 🎤 Speech2Form

**Voice-powered conversational form filling with Form.io + AI**

Speech2Form transforms any [Form.io](https://form.io) form into an interactive voice conversation. Instead of staring at a traditional form, users simply talk — the AI understands their answers, validates them against field rules, and submits the completed form via the Form.io API.

---

## ✨ Features

| Feature | Description |
| ------- | ----------- |
| 🎙️ **Voice Input** | Speak answers naturally in Turkish — silence-based auto-stop (5s) |
| ⌨️ **Text Fallback** | Toggle keyboard input anytime; auto-enabled if STT unavailable |
| 🤖 **AI Processing** | GPT-4o-mini with **13 type-specific prompt templates** per field type |
| ✅ **Answer Confirmation** | Configurable "Is X correct?" verification before saving each answer |
| 📋 **Form.io Integration** | Fetch forms dynamically, submit answers via REST API |
| 🔀 **Conditional Logic** | Show/hide fields based on previous answers (Form.io `conditional`) |
| ↩️ **Undo** | Undo last answer + dependent conditional fields |
| ⏭️ **Skip** | Skip optional fields; required fields enforce completion |
| 🔇 **Silence Handling** | Auto-skip optional fields on silence; re-ask required ones |
| 💾 **Session Persistence** | Auto-save progress; resume interrupted sessions |
| ✏️ **Summary Editing** | Tap any answer in the summary dialog to re-answer before submit |
| 🌍 **i18n Ready** | All strings in `PromptDictionary` — extend for any language |
| 🔊 **TTS** | Questions read aloud via `flutter_tts` |
| 📳 **Haptic Feedback** | Tactile responses on answers, confirmations, and submit |
| 🎬 **Welcome Animation** | Animated onboarding splash before form filling |
| ⚙️ **Pre-Start Config** | Configure confirmation & AI mode before each form |
| 🔄 **AI Fallback** | Auto-switch to local parsing after 3 consecutive AI errors |

---

## 🏗️ Architecture

```text
lib/
├── main.dart                     # App entry, Form.io auth + form fetch
├── models/
│   ├── conversation_message.dart # Chat bubble data model
│   ├── prompt_dictionary.dart    # 🌍 All AI prompts + UI strings (i18n)
│   └── voice_field_config.dart   # Per-type voice strategy + constraints
├── screens/
│   ├── chat_screen.dart          # Main conversational UI
│   └── welcome_screen.dart       # Animated splash + pre-start config
├── services/
│   ├── ai_service.dart           # OpenAI integration + fallback strategy
│   ├── conversation_engine.dart  # Form flattening, progress, conditional logic
│   ├── session_service.dart      # SharedPreferences session persistence
│   └── voice_service.dart        # TTS + STT lifecycle management
└── widgets/
    ├── chat_bubble.dart          # Message rendering
    ├── form_summary_dialog.dart  # Review, edit & submit dialog
    └── voice_indicator.dart      # Sound level animation
```

### Data Flow

```text
User Voice ──► STT ──► Raw Text ──► AIService ──► Formatted Value
                                       │
                              VoiceFieldConfig
                           (type-specific prompt)
                                       │
                                       ▼
                         ┌─── Confirmation? ───┐
                         │  "X doğru mu?"       │
                         │  evet → commit        │
                         │  hayır → re-ask       │
                         └─────────────────────┘
                                       │
                            ConversationEngine
                          (validate, store, next Q)
                                       │
                              SessionService
                          (auto-save to SharedPrefs)
                                       │
                              Form.io Submission
```

---

## 🎯 Supported Component Types

### ✅ Voice-Compatible (13 types)

| Type | Strategy | AI Output Example |
| ---- | -------- | ----------------- |
| `textfield` | Free text | `"Mehmet Şeref"` |
| `textarea` | Free text | `"Uzun açıklama metni..."` |
| `number` | Numeric | `150` |
| `currency` | Numeric | `1250.00` |
| `email` | Email | `"ali@gmail.com"` |
| `phoneNumber` | Phone | `"05321234567"` |
| `url` | URL | `"https://example.com"` |
| `select` | Single select | `"option_value"` |
| `radio` | Single select | `"selected_value"` |
| `selectboxes` | Multi select | `{"opt1": true, "opt2": false}` |
| `checkbox` | Boolean | `true` / `false` |
| `date` / `datetime` | Date | `"2026-02-25"` |
| `time` | Time | `"15:30"` |

### ⛔ Auto-Skipped (15+ types)

`signature`, `file`, `captcha`, `sketchpad`, `hidden`, `button`, `container`, `datagrid`, `editgrid`, `nestedform`, `survey`, etc.

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK ≥ 3.7.0
- A Form.io server with API access
- An OpenAI API key
- iOS/Android device with microphone

### Installation

```bash
# Clone the repository
git clone https://gitlab.com/mskayali/flutter_formio.git
cd flutter_formio/example

# Install dependencies
flutter pub get
```

### Configuration

Edit `lib/main.dart` or use the in-app settings dialog:

```dart
// Form.io
const formioUrl = 'https://your-formio-server.com';
const formId   = 'your-form-id';

// OpenAI
const openaiKey = 'sk-proj-...';
```

### Run

```bash
# Debug (hot reload)
flutter run

# Release (optimized)
flutter run --release
```

---

## ⚙️ Configuration

### Answer Confirmation

Toggle per-form answer confirmation via `confirmationEnabled`:

```dart
ChatScreen(
  form: form,
  aiService: aiService,
  confirmationEnabled: true,  // Ask "Is X correct?" after each answer
  formId: 'my-form',          // Enable session persistence
)
```

When enabled, after AI processes each answer the system asks:
> 🔍 "Mehmet" olarak kaydedeyim mi? (Evet / Hayır)

Users can accept or reject via voice or keyboard.

### Session Persistence

Pass `formId` to enable auto-save. Progress is saved to `SharedPreferences` after each answer:

```dart
ChatScreen(
  formId: 'patient-intake',  // Unique key per form
  // ...
)
```

- **Auto-save**: After every committed answer
- **Auto-restore**: On screen init, if a previous session exists
- **Auto-clear**: After successful form submission

### Pre-Start Configuration Screen

Before each form, users see a configuration screen with toggles:

- **Cevap Doğrulama (Answer Confirmation)** — enable/disable the confirmation prompt
- **Yapay Zeka Modu (AI Mode)** — choose between OpenAI or local-only processing

The screen is shown inside `WelcomeScreen` and passes user choices to `ChatScreen`.

### OpenAI Fallback Strategy

`AIService` tracks consecutive errors. After **3 consecutive failures**, it auto-switches to local-only mode (`ConversationEngine.parseAnswer()`) and notifies the user:

> ⚠️ Yapay zeka çok fazla hata verdi. Yerel işleme moduna geçildi.

Behavior:
- **No API key** → Local mode from the start
- **User disables AI** → Immediate fallback via config screen
- **API errors** → After 3 consecutive errors, auto-fallback + chat notification
- **Recovery** → Any successful AI call resets the error counter

---

## 🌍 Multi-Language Support

All text is centralized in `PromptDictionary`. To add a new language:

```dart
class EnglishPrompts extends PromptDictionary {
  @override
  String get emailPrompt => 'Convert the spoken email address...';

  @override
  String welcomeMessage(String title) =>
      'Hello! Let\'s fill out the "$title" form together.';

  @override
  String get confirmationAccepted => '✅ Answer saved.';

  // ... override all methods
}

// Set at startup
void main() {
  PromptDictionary.current = EnglishPrompts();
  runApp(const MyApp());
}
```

### Dictionary Categories

| Category | Count | Examples |
| -------- | ----- | ------- |
| AI Prompt Templates | 15 | `textFieldPrompt`, `emailPrompt`, `numberPrompt` |
| Skip Reasons | 19 | `skipSignature`, `skipFile`, `skipCaptcha` |
| Question Templates | 6 | `questionNumber`, `questionCheckbox` |
| UI Strings | 40+ | `welcomeMessage`, `tooltipUndo`, `confirmationAsk`, `configTitle` |

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Current: 54 tests passing
# - 19 ConversationEngine tests
# - 35 VoiceFieldConfig tests
```

### Test Coverage

- ✅ Question extraction (flat, nested panels/columns)
- ✅ Answer flow (progress, completion callbacks)
- ✅ Undo mechanism (single, multiple, dependent fields)
- ✅ Conditional logic (show/hide, undo cleanup)
- ✅ Answer parsing (checkbox, number, select by label)
- ✅ Component classification (13 voice types, 19 skip types)
- ✅ Constraint extraction (maxLength, min/max, decimalLimit)

---

## 📦 Dependencies

| Package | Purpose |
| ------- | ------- |
| `formio` | Form.io Flutter widget rendering |
| `formio_api` | Form.io REST API client (auth, forms, submissions) |
| `flutter_tts` | Text-to-Speech for reading questions |
| `speech_to_text` | Speech-to-Text for voice input |
| `openai_dart` | OpenAI API for AI answer processing |
| `shared_preferences` | Session persistence for form progress |

---

## 📱 Platform Setup

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Sesli form doldurma için mikrofon erişimi gereklidir.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Sesli yanıtlarınızı metne dönüştürmek için konuşma tanıma gereklidir.</string>
```

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

---

## 🗺️ Roadmap

- [ ] Full English prompt dictionary
- [ ] Address component with geocoding
- [ ] Survey component voice support
- [ ] Offline mode with local STT
- [ ] DataGrid voice input (row-by-row)

---

## 📄 License

This project is part of the [flutter_formio](https://gitlab.com/mskayali/flutter_formio) monorepo.
