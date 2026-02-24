/// AIService — OpenAI-based answer evaluation with type-aware prompts.
///
/// Uses openai_dart to process spoken answers through per-type prompt
/// templates. Each Form.io field type gets a specialized AI instruction
/// that understands the expected output format, validation constraints,
/// and Turkish language context.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:formio_api/formio_api.dart';
import 'package:openai_dart/openai_dart.dart';

import '../models/prompt_dictionary.dart';
import '../models/voice_field_config.dart';

class AIService extends ChangeNotifier {
  OpenAIClient? _client;
  bool _isProcessing = false;
  String _model = 'gpt-4o-mini';

  // Fallback state
  int _consecutiveErrors = 0;
  bool _fallbackMode = false;

  /// Max consecutive AI errors before switching to local fallback.
  static const int maxConsecutiveErrors = 3;

  /// Whether the service is currently processing an answer.
  bool get isProcessing => _isProcessing;

  /// Whether the service is configured and ready.
  bool get isReady => _client != null;

  /// Whether AI has been disabled due to repeated failures.
  bool get isFallbackMode => _fallbackMode;

  /// Force enable/disable fallback (local-only) mode.
  set fallbackMode(bool value) {
    _fallbackMode = value;
    _consecutiveErrors = 0;
    notifyListeners();
  }

  /// Initialize with an API key.
  void initialize({required String apiKey, String? model}) {
    _client = OpenAIClient(apiKey: apiKey);
    if (model != null) _model = model;
    _fallbackMode = false;
    _consecutiveErrors = 0;
    if (kDebugMode) print('🤖 AIService initialized with model: $_model');
  }

  /// Process a raw spoken answer using the component's [VoiceFieldConfig].
  ///
  /// The AI prompt is fully specialized for the component type — including
  /// output format, validation constraints, and Turkish language rules.
  ///
  /// Falls back to [rawAnswer] if AI is unavailable or errors out.
  Future<dynamic> processAnswer({
    required ComponentModel component,
    required String rawAnswer,
  }) async {
    final config = VoiceFieldConfig.fromComponent(component);

    // If the component is not voice-compatible, return empty
    if (!config.isVoiceCompatible) {
      if (kDebugMode) {
        print('🤖 Skipping non-voice component: ${component.key} '
            '(${config.skipReason})');
      }
      return null;
    }

    if (_client == null || _fallbackMode) {
      if (kDebugMode) {
        print(_fallbackMode
            ? '🤖 Fallback mode active, using raw answer'
            : '🤖 AI not configured, using raw answer');
      }
      return rawAnswer;
    }

    _isProcessing = true;
    notifyListeners();

    try {
      final systemPrompt = _buildSystemPrompt(config);
      final userPrompt = _buildUserPrompt(
        component: component,
        config: config,
        rawAnswer: rawAnswer,
      );

      final response = await _client!.createChatCompletion(
        request: CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(_model),
          messages: [
            ChatCompletionMessage.system(content: systemPrompt),
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string(userPrompt),
            ),
          ],
          temperature: 0.1,
          maxTokens: 300,
          responseFormat: const ResponseFormat.jsonObject(),
        ),
      );

      final content = response.choices.first.message.content;
      if (content == null || content.isEmpty) return rawAnswer;

      final parsed = jsonDecode(content) as Map<String, dynamic>;
      final value = parsed['value'];

      if (kDebugMode) {
        print('🤖 [${component.type}] "$rawAnswer" → $value');
      }

      // Reset error counter on success
      _consecutiveErrors = 0;

      return value ?? rawAnswer;
    } catch (e) {
      if (kDebugMode) print('🤖 AI processing error: $e');
      _consecutiveErrors++;
      if (_consecutiveErrors >= maxConsecutiveErrors) {
        _fallbackMode = true;
        if (kDebugMode) {
          print('🤖 Switched to fallback mode after '
              '$_consecutiveErrors consecutive errors');
        }
        notifyListeners();
      }
      return rawAnswer;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Build a type-specialized system prompt using the field config.
  String _buildSystemPrompt(VoiceFieldConfig config) {
    return PromptDictionary.current.systemPrompt(config.promptTemplate);
  }

  /// Build the user prompt with question context and options.
  String _buildUserPrompt({
    required ComponentModel component,
    required VoiceFieldConfig config,
    required String rawAnswer,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Soru: "${component.label}"');
    buffer.writeln('Alan tipi: ${component.type}');
    buffer.writeln('Alan anahtarı: ${component.key}');

    // Add component description if available
    if (component.description != null && component.description!.isNotEmpty) {
      buffer.writeln('Açıklama: ${component.description}');
    }

    // Add validation info
    if (component.required) {
      buffer.writeln('⚠️ Bu alan zorunludur.');
    }
    if (config.constraints.isNotEmpty) {
      buffer.writeln('Kısıtlamalar: ${jsonEncode(config.constraints)}');
    }

    // Add options for select-type components
    if (config.strategy == VoiceInputStrategy.singleSelect ||
        config.strategy == VoiceInputStrategy.multiSelect) {
      final options = extractOptions(component.raw);
      if (options.isNotEmpty) {
        buffer.writeln('Seçenekler:');
        for (final opt in options) {
          buffer.writeln('  - "${opt['label']}" (value: "${opt['value']}")');
        }
      }
    }

    buffer.writeln('');
    buffer.writeln('Kullanıcının sesli cevabı: "$rawAnswer"');

    return buffer.toString();
  }

  /// Extract options from a component for passing to AI.
  static List<Map<String, String>> extractOptions(
      Map<String, dynamic> componentRaw) {
    // Select component options (data.values)
    final data = componentRaw['data'] as Map<String, dynamic>?;
    final selectValues = data?['values'] as List?;
    if (selectValues != null) {
      return selectValues.map((v) {
        final opt = v as Map<String, dynamic>;
        return {
          'label': opt['label']?.toString() ?? '',
          'value': opt['value']?.toString() ?? '',
        };
      }).toList();
    }

    // Radio / selectboxes options (values)
    final radioValues = componentRaw['values'] as List?;
    if (radioValues != null) {
      return radioValues.map((v) {
        final opt = v as Map<String, dynamic>;
        return {
          'label': opt['label']?.toString() ?? '',
          'value': opt['value']?.toString() ?? '',
        };
      }).toList();
    }

    return [];
  }

  @override
  void dispose() {
    _client = null;
    super.dispose();
  }
}
