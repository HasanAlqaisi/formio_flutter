/// PromptDictionary — centralized i18n-ready dictionary for all
/// voice chat prompts, UI strings, and AI instruction templates.
///
/// All user-facing text is collected here to enable future
/// multi-language support. To add a new language:
/// 1. Create a class extending [PromptDictionary] (e.g., `EnglishPrompts`)
/// 2. Override each getter/method with the translated version
/// 3. Pass the instance to services via `PromptDictionary.current`
///
/// Usage:
/// ```dart
/// // Set globally (call once at startup)
/// PromptDictionary.current = EnglishPrompts();
///
/// // Access anywhere
/// final d = PromptDictionary.current;
/// print(d.welcomeMessage('Contact Form'));
/// ```
library;

import 'english_prompts.dart';

class PromptDictionary {
  /// Singleton — switch to a different subclass for another language.
  static PromptDictionary current = PromptDictionary();

  /// Current locale identifier ('tr' or 'en').
  static String currentLocale = 'tr';

  /// Factory to get a dictionary for a given locale.
  static PromptDictionary forLocale(String locale) {
    switch (locale) {
      case 'en':
        return EnglishPrompts();
      default:
        return PromptDictionary();
    }
  }

  /// STT/TTS locale ID for the current language.
  String get sttLocaleId => 'tr_TR';

  /// TTS language code.
  String get ttsLanguage => 'tr-TR';

  // ═══════════════════════════════════════════════════════════
  //  AI SYSTEM PROMPT
  // ═══════════════════════════════════════════════════════════

  /// The top-level system instruction sent to the AI for every field.
  /// The [typeInstructions] placeholder is replaced per-type.
  String systemPrompt(String typeInstructions) => '''Sen bir form doldurma asistanısın. Kullanıcının Türkçe sesli cevabını, form alanı tipine uygun bir değere dönüştürüyorsun.

GENEL KURALLAR:
1. SADECE JSON formatında cevap ver.
2. Konuşma hatalarını (ıı, eee, şey, yani) temizle.
3. Türkçe bağlamda değerlendir.
4. Kullanıcının cevabı tamamen anlamsız veya boşsa: {"value": ""}

TİP-ÖZEL TALİMATLAR:
$typeInstructions''';

  // ═══════════════════════════════════════════════════════════
  //  PER-TYPE AI PROMPT TEMPLATES
  // ═══════════════════════════════════════════════════════════

  String textFieldPrompt({int? maxLength, int? minLength}) => '''Kullanıcının sesli cevabını düzgün bir metin değerine dönüştür.
Kurallar:
- İlk harfi büyük yap, geri kalan doğal bırak.
- Konuşma hatalarını (ıı, eee, şey gibi) temizle.
- Gereksiz tekrarları kaldır.
${maxLength != null ? '- Maksimum $maxLength karakter. Uzunsa kısalt.' : ''}
${minLength != null ? '- Minimum $minLength karakter.' : ''}
- Çıktı: {"value": "temizlenmiş metin"}''';

  String textAreaPrompt({int? maxLength}) => '''Kullanıcının sesli cevabını çok satırlı metin alanına uygun bir değere dönüştür.
Kurallar:
- Doğal konuşma tonunu koru, ama konuşma hatalarını temizle.
- Cümle yapısını düzelt, noktalama ekle.
${maxLength != null ? '- Maksimum $maxLength karakter. Aşarsa özet çıkar.' : ''}
- Çıktı: {"value": "düzenlenmiş metin"}''';

  String get passwordPrompt => '''Kullanıcının sesli söylediği şifreyi aynen kaydet.
Kurallar:
- Harfleri aynen koru (büyük/küçük harf farkına dikkat et).
- "büyük a", "küçük b" gibi ifadeleri uygun harfe çevir.
- Özel karakterleri ("nokta", "at işareti", "alt çizgi") sembollere çevir.
- Çıktı: {"value": "şifre_metni"}''';

  String get emailPrompt => '''Kullanıcının sesli söylediği e-posta adresini formatla.
Kurallar:
- "at" veya "et" → @
- "nokta" veya "dot" → .
- "gmail", "hotmail", "outlook" gibi domain isimleri tanı.
- Boşlukları kaldır, tamamını küçük harf yap.
- Örnek: "ali at gmail nokta com" → "ali@gmail.com"
- Çıktı: {"value": "email@domain.com"}''';

  String get phonePrompt => '''Kullanıcının sesli söylediği telefon numarasını formatla.
Kurallar:
- Türkçe sayı ifadelerini rakama çevir ("beş yüz" → 500).
- Sadece rakamları al, fazla kelimeleri at.
- Türkiye formatı: 05XX XXX XX XX (11 haneli).
- Başında sıfır yoksa ekle.
- Çıktı: {"value": "05XXXXXXXXX"}''';

  String get urlPrompt => '''Kullanıcının sesli söylediği URL adresini formatla.
Kurallar:
- "nokta" veya "dot" → .
- "slash" veya "bölü" → /
- "w w w" veya "üç w" → www
- Protokol yoksa "https://" ekle.
- Boşlukları kaldır, küçük harf yap.
- Çıktı: {"value": "https://..."}''';

  String numberPrompt({dynamic min, dynamic max, dynamic decimalLimit}) =>
      '''Kullanıcının sesli söylediği sayıyı çıkar.
Kurallar:
- Türkçe sayı ifadelerini sayıya çevir ("yüz elli" → 150, "üç buçuk" → 3.5).
- Sadece sayısal değer döndür, birim veya ek kelime ekleme.
${min != null ? '- Minimum değer: $min' : ''}
${max != null ? '- Maksimum değer: $max' : ''}
${decimalLimit != null ? '- Ondalık basamak limiti: $decimalLimit' : ''}
- Çıktı: {"value": 123} (number tipinde, string değil)''';

  String currencyPrompt({String currency = 'TRY', int decimalLimit = 2}) =>
      '''Kullanıcının sesli söylediği para miktarını çıkar.
Kurallar:
- Türkçe sayı ifadelerini sayıya çevir.
- Para birimi: $currency
- "lira", "TL", "dolar", "euro" gibi birimleri yoksay, sadece sayıyı al.
- Ondalık basamak: $decimalLimit
- Çıktı: {"value": 150.00} (number tipinde)''';

  String get singleSelectPrompt =>
      '''Kullanıcının sesli cevabını verilen seçeneklerden biriyle eşleştir.
Kurallar:
- Kullanıcının söylediği metni seçenek etiketleriyle (label) karşılaştır.
- Tam eşleşme aranmaz, en yakın label eşleşmesinin VALUE değerini döndür.
- Türkçe karakter farklarını yoksay (ı/i, ö/o, ü/u, ş/s, ç/c, ğ/g).
- Büyük/küçük harf farkını yoksay.
- Hiçbir seçenekle eşleşmezse {"value": ""} döndür.
- Çıktı: {"value": "eşleşen_seçenek_value"}''';

  String get radioPrompt =>
      '''Kullanıcının sesli cevabını radyo buton seçeneklerinden biriyle eşleştir.
Kurallar:
- Sadece TEK BİR seçenek eşleşebilir.
- Kullanıcının söylediği metni seçenek etiketleriyle karşılaştır.
- En yakın eşleşmenin VALUE değerini döndür.
- Türkçe karakter ve büyük/küçük harf farklarını yoksay.
- Çıktı: {"value": "eşleşen_value"}''';

  String get multiSelectPrompt =>
      '''Kullanıcının sesli cevabından birden fazla seçenek eşleştir.
Kurallar:
- Kullanıcı birden fazla seçenek söyleyebilir ("birinci ve üçüncü", "a, b ve d").
- Her seçenek anahtarını true/false olarak döndür.
- Bahsedilen seçenekleri true, bahsedilmeyenleri false yap.
- "hepsi" veya "tümü" denirse hepsini true yap.
- "hiçbiri" denirse hepsini false yap.
- Çıktı: {"value": {"opt1": true, "opt2": false, "opt3": true}}''';

  String get checkboxPrompt =>
      '''Kullanıcının sesli cevabını evet/hayır değerine dönüştür.
Kurallar:
- "evet", "doğru", "tamam", "kabul", "onay", "yes", "true" → true
- "hayır", "yanlış", "istemiyorum", "red", "no", "false" → false
- Belirsizse (ne evet ne hayır) → false
- Çıktı: {"value": true} veya {"value": false}''';

  String datePrompt({bool includeTime = false}) =>
      '''Kullanıcının sesli söylediği ${includeTime ? 'tarih ve saati' : 'tarihi'} ISO 8601 formatına çevir.
Kurallar:
- Türkçe ay isimlerini tanı: ocak, şubat, mart, nisan, mayıs, haziran, temmuz, ağustos, eylül, ekim, kasım, aralık.
- "bugün", "yarın", "dün", "gelecek hafta", "önümüzdeki pazartesi" gibi göreceli ifadeleri tarihe çevir.
- Bugünün tarihi baz alınır.
- Yıl belirtilmezse mevcut yılı kullan.
${includeTime ? '- Saat belirtilmezse 00:00 kullan.' : ''}
- Format: ${includeTime ? 'YYYY-MM-DDTHH:mm:ss.000Z' : 'YYYY-MM-DD'}
- Çıktı: {"value": "${includeTime ? '2026-02-25T14:30:00.000Z' : '2026-02-25'}"}''';

  String get timePrompt => '''Kullanıcının sesli söylediği saati formatla.
Kurallar:
- Türkçe saat ifadelerini tanı: "üç buçuk" → 15:30, "sabah sekiz" → 08:00
- "buçuk" → :30, "çeyrek geçe" → :15, "çeyrek kala" → :45
- 24 saat formatı kullan.
- AM/PM bağlamını anla: "sabah", "öğleden sonra", "akşam", "gece"
- Format: HH:mm
- Çıktı: {"value": "15:30"}''';

  String get tagsPrompt => '''Kullanıcının sesli söylediği etiketleri/anahtar kelimeleri ayır.
Kurallar:
- Virgül, "ve", "ile" gibi ayırıcıları tanı.
- Her etiketi ayrı bir öğe olarak listele.
- Etiketleri küçük harf yap ve boşlukları kırp.
- Çıktı: {"value": "etiket1,etiket2,etiket3"}''';

  String get addressPrompt =>
      '''Kullanıcının sesli söylediği adresi yapılandırılmış formata dönüştür.
Kurallar:
- Adres bilgilerini mümkün olduğunca düzenli yaz.
- Mahalle, cadde, sokak, numara, daire bilgilerini ayıkla.
- İl ve ilçe bilgisini tanımaya çalış.
- Çıktı: {"value": "düzenlenmiş adres metni"}''';

  // ═══════════════════════════════════════════════════════════
  //  SURVEY PROMPTS
  // ═══════════════════════════════════════════════════════════

  String get surveyPrompt =>
      '''Kullanıcının sesli cevabını verilen anket derecelendirme seçeneklerinden biriyle eşleştir.
Kurallar:
- Kullanıcının söylediği metni mevcut derecelendirme etiketleriyle karşılaştır.
- En yakın eşleşmenin VALUE değerini döndür.
- Büyük/küçük harf ve Türkçe karakter farklarını yoksay.
- Hiçbir seçenekle eşleşmezse {"value": ""} döndür.
- Çıktı: {"value": "eşleşen_derecelendirme_value"}''';

  String surveyQuestionPrompt(String questionLabel, List<String> options) =>
      '$questionLabel. Şu seçeneklerden birini söyleyin: ${options.join(", ")}';  

  // ═══════════════════════════════════════════════════════════
  //  DATAGRID PROMPTS
  // ═══════════════════════════════════════════════════════════

  String datagridStartPrompt(String label, List<String> columns) =>
      '"$label" tablosunu satır satır dolduracağız. '
      'Sütunlar: ${columns.join(", ")}. 1. satırla başlayalım.';

  String datagridRowPrompt(int rowNum) => '$rowNum. satır';

  String get datagridAddMorePrompt =>
      'Başka bir satır eklemek ister misiniz? (Evet / Hayır)';

  String get datagridPrompt =>
      '''Kullanıcının bu tablo hücresi için sesli cevabını dönüştür.
Kurallar:
- Mevcut sütun için uygun değeri çıkar.
- Konuşma hatalarını temizle.
- Çıktı: {"value": "hücre değeri"}''';

  // ═══════════════════════════════════════════════════════════
  //  SKIP REASONS (non-voice-compatible components)
  // ═══════════════════════════════════════════════════════════

  String get skipSignature => 'İmza bileşeni sesle doldurulamaz';
  String get skipFile => 'Dosya yükleme sesle yapılamaz';
  String get skipCaptcha => 'CAPTCHA doğrulaması sesle yapılamaz';
  String get skipSketchpad => 'Çizim alanı sesle doldurulamaz';
  String get skipTagpad => 'Etiketleme alanı sesle doldurulamaz';
  String get skipHidden => 'Gizli alan, kullanıcı girişi gerektirmiyor';
  String get skipButton => 'Buton bileşeni, giriş gerektirmiyor';
  String get skipDatasource => 'Veri kaynağı bileşeni, giriş gerektirmiyor';
  String get skipContainer => 'Konteyner bileşeni sesle doldurulamaz';
  String get skipDatagrid => 'Veri tablosu sesle doldurulamaz';
  String get skipEditgrid => 'Düzenlenebilir tablo sesle doldurulamaz';
  String get skipNestedform => 'İç içe form sesle doldurulamaz';
  String get skipForm => 'Alt form sesle doldurulamaz';
  String get skipDynamicwizard => 'Dinamik sihirbaz sesle doldurulamaz';
  String get skipDatatable => 'Veri tablosu sesle doldurulamaz';
  String get skipDatamap => 'Veri haritası sesle doldurulamaz';
  String get skipReviewpage => 'İnceleme sayfası giriş gerektirmiyor';
  String get skipCustom => 'Özel bileşen sesle doldurulamaz';
  String get skipSurvey => 'Anket bileşeni henüz sesle desteklenmiyor';
  String get skipDefault => 'Bu bileşen sesle doldurulamaz';

  /// Lookup by component type.
  String skipReason(String type) => switch (type) {
        'signature' => skipSignature,
        'file' => skipFile,
        'captcha' => skipCaptcha,
        'sketchpad' => skipSketchpad,
        'tagpad' => skipTagpad,
        'hidden' => skipHidden,
        'button' => skipButton,
        'datasource' => skipDatasource,
        'container' => skipContainer,
        'datagrid' => skipDatagrid,
        'editgrid' => skipEditgrid,
        'nestedform' => skipNestedform,
        'form' => skipForm,
        'dynamicwizard' => skipDynamicwizard,
        'datatable' => skipDatatable,
        'datamap' => skipDatamap,
        'reviewpage' => skipReviewpage,
        'custom' => skipCustom,
        'survey' => skipSurvey,
        _ => skipDefault,
      };

  // ═══════════════════════════════════════════════════════════
  //  QUESTION TEXT TEMPLATES (spoken by TTS)
  // ═══════════════════════════════════════════════════════════

  String questionNumber(String label) => '$label. Lütfen bir sayı belirtin.';
  String questionCheckbox(String label) =>
      '$label. Evet veya hayır olarak cevaplayın.';
  String questionDate(String label) => '$label. Lütfen bir tarih belirtin.';
  String questionTime(String label) => '$label. Lütfen bir saat belirtin.';
  String questionSelectOne(String label, List<String> options) =>
      '$label. Şu seçeneklerden birini söyleyin: ${options.join(", ")}';
  String questionSelectMulti(String label, List<String> options) =>
      '$label. Şu seçeneklerden bir veya daha fazlasını söyleyin: ${options.join(", ")}';

  // ═══════════════════════════════════════════════════════════
  //  CHAT SCREEN UI STRINGS
  // ═══════════════════════════════════════════════════════════

  String welcomeMessage(String formTitle) =>
      'Merhaba! "$formTitle" formunu birlikte dolduracağız. '
      'Soruları sesli olarak soracağım, mikrofon butonuna basarak cevaplayabilir '
      'veya klavye ikonuna basarak yazılı cevap verebilirsiniz.';

  String get sttUnavailable =>
      '⚠️ Konuşma tanıma kullanılamıyor. Yazılı giriş aktif edildi.';
  String get aiFailedFallback =>
      '⚠️ Yapay zeka değerlendirmesi başarısız, cevap doğrudan kaydedildi.';
  String get formComplete => '🎉 Tüm sorular cevaplandı! Form özeti aşağıda.';
  String answerUndone(String label) => '↩️ "$label" cevabı geri alındı.';
  String answerRecorded(String value) => '✅ Kayıt: $value';
  String get questionRequired => '⚠️ Bu soru zorunludur, atlanamıyor.';
  String questionSkipped(String label) => '⏭️ "$label" atlandı.';
  String get silenceSkipped =>
      '🔇 Cevap algılanamadı, soru atlandı.';
  String get silenceRequiredWarning =>
      '⚠️ Bu alan zorunludur ve boş bırakılamaz. Lütfen cevaplayın.';
  String get emptyAnswerSkipped =>
      '🔇 Boş cevap, soru atlandı.';
  String get emptyAnswerRequiredWarning =>
      '⚠️ Bu alan zorunludur, boş bırakılamaz. Lütfen bir cevap girin.';

  // ── Tooltips & Labels ──
  String get tooltipUndo => 'Son cevabı geri al';
  String get tooltipRepeat => 'Soruyu tekrarla';
  String get tooltipHideKeyboard => 'Klavyeyi gizle';
  String get tooltipShowKeyboard => 'Klavyeyle yaz';
  String get tooltipSkip => 'Soruyu atla';
  String get hintTextInput => 'Cevabınızı yazın...';
  String get labelInitializing => 'Sesli servisler başlatılıyor...';
  String get labelYes => 'Evet';
  String get labelNo => 'Hayır';

  // ── Form Summary Dialog ──
  String get summaryTitle => 'Form Özeti';
  String get summaryCompleted => 'Form Tamamlandı!';
  String get summaryReview => 'Yanıtlarınızı kontrol edin';
  String get summaryEdit => 'Düzenle';
  String get summarySubmit => 'Gönder';
  String get summaryNotAnswered => 'Cevaplanmadı';
  String summaryEditField(String label) =>
      '✏️ "$label" alanını düzenliyorsunuz. Yeni cevabınızı söyleyin veya yazın.';

  // ── Confirmation Flow ──
  String confirmationAsk(String value) =>
      '🔍 "$value" olarak kaydedeyim mi? (Evet / Hayır)';
  String get confirmationAccepted => '✅ Cevap kaydedildi.';
  String get confirmationRejected =>
      '↩️ Cevap reddedildi. Lütfen tekrar cevaplayın.';

  // ── Welcome Animation ──
  String get welcomeAnimTitle => 'Speech2Form';
  String get welcomeAnimSubtitle => 'Sesli Form Doldurma Asistanı';
  String get welcomeAnimStart => 'Başla';

  // ── Session Persistence ──
  String get sessionResumed =>
      '💾 Önceki oturum geri yüklendi. Kaldığınız yerden devam edebilirsiniz.';
  String get sessionResumeContinue => 'Devam Et';
  String get sessionResumeRestart => 'Baştan Başla';

  // ── AI Fallback ──
  String get aiFallbackActivated =>
      '⚠️ Yapay zeka çok fazla hata verdi. Yerel işleme moduna geçildi.';
  String get aiFallbackLabel => 'Yapay Zeka (AI)';
  String get aiFallbackDescription =>
      'AI devre dışı, cevaplar yerel olarak işleniyor.';
  String get aiActiveDescription =>
      'Cevaplar OpenAI ile işleniyor.';

  // ── Pre-Start Config Screen ──
  String get configTitle => 'Form Ayarları';
  String get configSubtitle => 'Başlamadan önce tercihleri ayarlayın';
  String get configConfirmation => 'Cevap Doğrulama';
  String get configConfirmationDesc =>
      'Her cevaptan sonra "Doğru mu?" diye sorar';
  String get configAiMode => 'Yapay Zeka Modu';
  String get configAiModeDesc =>
      'OpenAI ile akıllı cevap işleme';
  String get configAiLocalDesc =>
      'Yerel cevap işleme (AI olmadan)';
  String get configStartButton => 'Formu Başlat';

  // ── Skip Optional ──
  String get configSkipOptional => 'Opsiyonelleri Atla';
  String get configSkipOptionalDesc =>
      'Zorunlu olmayan alanları otomatik geç';
  String optionalFieldSkipped(String label) =>
      '⏭ "$label" opsiyonel — atlandı.';

  // ── Offline Mode ──
  String get configOfflineMode => 'Çevrimdışı Mod';
  String get configOfflineModeDesc =>
      'Cihaz üzerinde konuşma tanıma kullan (internet gerekmez)';
  String get offlineModeActivated =>
      '📱 Çevrimdışı mod etkin. Cihaz üzerinde konuşma tanıma kullanılıyor.';

  // ── Language ──
  String get configLanguage => 'Dil';
  String get configLanguageDesc => 'Arayüz ve yapay zeka dilini değiştir';

  // ── Form Compatibility ──
  String get incompatibleFormTitle => 'Form Uyumsuz';
  String get incompatibleFormMessage =>
      'Bu form, sesli doldurulamayan zorunlu alan(lar) içeriyor. '
      'Bu alanlar sesle doldurulamadığı için form tamamlanamaz.';
  String get incompatibleFieldsHeader => 'Desteklenmeyen zorunlu alanlar:';
  String get incompatibleGoBack => 'Geri Dön';
}
