/// ChatScreen — main conversation UI for voice-based form filling.
///
/// Displays a chat-style interface where the bot asks Form.io questions
/// via TTS and the user responds via speech-to-text or keyboard.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:formio_api/formio_api.dart';

import '../models/conversation_message.dart';
import '../models/prompt_dictionary.dart';
import '../services/ai_service.dart';
import '../services/conversation_engine.dart';
import '../services/geocoding_service.dart';
import '../services/session_service.dart';
import '../services/voice_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/form_summary_dialog.dart';
import '../widgets/voice_indicator.dart';

class ChatScreen extends StatefulWidget {
  final FormModel form;
  final AIService aiService;
  final void Function(Map<String, dynamic> formData)? onSubmit;

  /// Enable answer confirmation — AI-processed answers ask
  /// "Is X correct?" before saving.
  final bool confirmationEnabled;

  /// Form ID for session persistence. If null, persistence is disabled.
  final String? formId;

  /// Auto-skip optional (not required) fields.
  final bool skipOptional;

  /// Use on-device STT (no internet).
  final bool offlineMode;

  /// Locale for TTS/STT (e.g. 'tr', 'en').
  final String locale;

  const ChatScreen({
    super.key,
    required this.form,
    required this.aiService,
    this.onSubmit,
    this.confirmationEnabled = false,
    this.formId,
    this.skipOptional = false,
    this.offlineMode = false,
    this.locale = 'tr',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late ConversationEngine _engine;
  late VoiceService _voiceService;
  final List<ConversationMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  bool _isInitialized = false;
  bool _isProcessingAnswer = false;
  bool _showTextInput = false;

  // Confirmation state
  ComponentModel? _pendingQuestion;
  dynamic _pendingValue;
  bool _awaitingConfirmation = false;

  @override
  void initState() {
    super.initState();
    _engine = ConversationEngine(
      form: widget.form,
      onComplete: _onFormComplete,
    );
    _voiceService = VoiceService();
    _voiceService.addListener(_onVoiceStateChanged);
    widget.aiService.addListener(_onAiStateChanged);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Apply locale and offline mode
    _voiceService.offlineMode = widget.offlineMode;
    await _voiceService.initialize();
    await _voiceService.setLocale(
      PromptDictionary.current.sttLocaleId,
    );
    setState(() => _isInitialized = true);

    // Send welcome message
    _addMessage(ConversationMessage.system(
      text: PromptDictionary.current.welcomeMessage(widget.form.title),
    ));

    // If STT is not available, automatically show text input
    if (!_voiceService.isSttAvailable) {
      _addMessage(ConversationMessage.system(
        text: PromptDictionary.current.sttUnavailable,
      ));
      setState(() => _showTextInput = true);
    }

    // Try to restore previous session
    await _tryRestoreSession();

    // Small delay then ask the first question
    await Future.delayed(const Duration(milliseconds: 800));
    _askNextQuestion();
  }

  /// Attempt to restore a previous session.
  Future<void> _tryRestoreSession() async {
    if (widget.formId == null) return;

    final savedData = await SessionService.load(widget.formId!);
    if (savedData != null && savedData.isNotEmpty) {
      _engine.restoreAnswers(savedData);
      _addMessage(ConversationMessage.system(
        text: PromptDictionary.current.sessionResumed,
      ));
    }
  }

  /// Save current progress.
  Future<void> _saveSession() async {
    if (widget.formId == null) return;
    await SessionService.save(
      formId: widget.formId!,
      formData: _engine.formDataSnapshot,
    );
  }

  void _onVoiceStateChanged() {
    if (mounted) setState(() {});
  }

  /// Listen for AI fallback mode activation.
  void _onAiStateChanged() {
    if (widget.aiService.isFallbackMode) {
      _addMessage(ConversationMessage.system(
        text: PromptDictionary.current.aiFallbackActivated,
      ));
    }
  }

  @override
  void dispose() {
    _voiceService.removeListener(_onVoiceStateChanged);
    widget.aiService.removeListener(_onAiStateChanged);
    _voiceService.dispose();
    _scrollController.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  // ─── Conversation Flow ───────────────────────────────────

  Future<void> _askNextQuestion() async {
    final question = _engine.getNextQuestion();
    if (question == null) return;

    // Auto-skip optional fields if configured
    if (widget.skipOptional && !question.required) {
      _engine.updateAnswer(question.key, '');
      _addMessage(ConversationMessage.system(
        text: PromptDictionary.current.optionalFieldSkipped(question.label),
      ));
      if (!_engine.isComplete) {
        await Future.delayed(const Duration(milliseconds: 200));
        _askNextQuestion();
      }
      return;
    }

    final questionText = _engine.buildQuestionText(question);

    _addMessage(ConversationMessage.botQuestion(
      text: questionText,
      componentKey: question.key,
      componentType: question.type,
    ));

    // Speak the question
    await _voiceService.speak(questionText);
  }

  Future<void> _startListening() async {
    if (_voiceService.isBusy) {
      await _voiceService.cancel();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    await _voiceService.startListening(
      onResult: (recognizedText) => _processAnswer(recognizedText),
      onSilence: _handleSilence,
    );
  }

  /// Submit text from the keyboard input.
  void _submitTextAnswer() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    _processAnswer(text);
  }

  Future<void> _processAnswer(String rawText) async {
    // Handle empty/silence answers
    if (rawText.trim().isEmpty) {
      _voiceService.setIdle();
      _handleEmptyAnswer();
      return;
    }

    // --- Confirmation mode: handle yes/no responses ---
    if (_awaitingConfirmation) {
      _handleConfirmationResponse(rawText);
      return;
    }

    // Add user message to chat
    _addMessage(ConversationMessage.userAnswer(text: rawText));

    setState(() => _isProcessingAnswer = true);

    // Get the current question
    final currentQuestion = _engine.getNextQuestion();
    if (currentQuestion == null) {
      setState(() => _isProcessingAnswer = false);
      return;
    }

    // Process answer through AI (with error handling)
    dynamic processedValue;
    try {
      processedValue = await widget.aiService.processAnswer(
        component: currentQuestion,
        rawAnswer: rawText,
      );
    } catch (e) {
      // AI failed — fall back to engine's own parser
      processedValue = _engine.parseAnswer(currentQuestion, rawText);
      _addMessage(ConversationMessage.system(
        text: PromptDictionary.current.aiFailedFallback,
      ));
    }

    // Geocode address answers
    if (currentQuestion.type == 'address' && processedValue is String) {
      final geocoded = await GeocodingService.resolveAddress(processedValue);
      processedValue = geocoded;
    }

    // --- Confirmation mode: ask before saving ---
    if (widget.confirmationEnabled) {
      _pendingQuestion = currentQuestion;
      _pendingValue = processedValue;
      _awaitingConfirmation = true;
      setState(() => _isProcessingAnswer = false);

      final displayValue =
          _formatValueForDisplay(currentQuestion, processedValue);
      _addMessage(ConversationMessage.system(
        text: PromptDictionary.current.confirmationAsk(displayValue),
      ));
      await _voiceService.speak(
        PromptDictionary.current.confirmationAsk(displayValue),
      );
      return;
    }

    // Direct save (no confirmation)
    _commitAnswer(currentQuestion, processedValue, rawText);
  }

  /// Handle yes/no response during confirmation flow.
  void _handleConfirmationResponse(String rawText) {
    final lower = rawText.trim().toLowerCase();
    _addMessage(ConversationMessage.userAnswer(text: rawText));

    final positives = {'evet', 'doğru', 'tamam', 'yes', 'onay', 'kaydet'};
    final negatives = {'hayır', 'yanlış', 'no', 'tekrar', 'değil', 'iptal'};

    if (positives.any((p) => lower.contains(p))) {
      // Accepted — commit
      HapticFeedback.mediumImpact();
      _addMessage(ConversationMessage.system(
        text: PromptDictionary.current.confirmationAccepted,
      ));
      _commitAnswer(_pendingQuestion!, _pendingValue!, '');
      _clearConfirmation();
    } else if (negatives.any((n) => lower.contains(n))) {
      // Rejected — re-ask
      _addMessage(ConversationMessage.system(
        text: PromptDictionary.current.confirmationRejected,
      ));
      _clearConfirmation();
      _askNextQuestion();
    } else {
      // Unclear — ask again
      _addMessage(ConversationMessage.system(
        text: PromptDictionary.current.confirmationAsk(
          _formatValueForDisplay(_pendingQuestion!, _pendingValue!),
        ),
      ));
    }
  }

  void _clearConfirmation() {
    _pendingQuestion = null;
    _pendingValue = null;
    _awaitingConfirmation = false;
  }

  /// Commit a processed answer to the engine.
  Future<void> _commitAnswer(
    ComponentModel question,
    dynamic processedValue,
    String rawText,
  ) async {
    // Haptic feedback on successful answer
    HapticFeedback.lightImpact();

    // If AI returned a different value than raw, show the parsed value
    if (rawText.isNotEmpty &&
        processedValue.toString() != rawText &&
        processedValue.toString().isNotEmpty) {
      _addMessage(ConversationMessage.system(
        text: PromptDictionary.current
            .answerRecorded(_formatValueForDisplay(question, processedValue)),
      ));
    }

    // Update form data
    _engine.updateAnswer(question.key, processedValue);

    // Handle datagrid add-row sentinel
    if (question.key.endsWith('__addrow')) {
      final isYes = processedValue == true ||
          processedValue.toString().toLowerCase().contains('evet') ||
          processedValue.toString().toLowerCase().contains('yes');
      if (isYes) {
        _engine.expandDatagridRow(question.key);
      }
    }

    // Auto-save session
    _saveSession();

    setState(() => _isProcessingAnswer = false);

    // Ask next question after a brief pause
    if (!_engine.isComplete) {
      await Future.delayed(const Duration(milliseconds: 600));
      _askNextQuestion();
    }
  }

  String _formatValueForDisplay(ComponentModel component, dynamic value) {
    final d = PromptDictionary.current;

    if (value == null) return '-';

    // Native bool
    if (value is bool) return value ? d.labelYes : d.labelNo;

    // Bool-like values for checkbox/toggle/radio-as-bool
    if (component.type == 'checkbox' || component.type == 'toggle') {
      return _parseBoolLikeValue(value, d);
    }

    // Radio / Select — resolve raw value to human label
    if (component.type == 'radio' || component.type == 'select') {
      final label = _resolveOptionLabel(value.toString(), component);
      // If the resolved label is "1"/"0" for a yes/no radio, show Evet/Hayır
      if (label == value.toString()) {
        // Couldn't resolve — try bool-like
        return _parseBoolLikeValue(value, d);
      }
      return label;
    }

    // Selectboxes: Map<String, bool> → show selected option LABELS
    if (value is Map) {
      if (component.type == 'selectboxes') {
        final selected = value.entries
            .where((e) =>
                e.value == true ||
                e.value == 1 ||
                e.value.toString().toLowerCase() == 'true')
            .map((e) => _resolveOptionLabel(e.key.toString(), component))
            .toList();
        return selected.isEmpty ? '-' : selected.join(', ');
      }
      return const JsonEncoder.withIndent('  ').convert(value);
    }

    // Selectboxes: String "opt1, opt3" → resolve each key to label
    if (component.type == 'selectboxes' && value is String) {
      final keys = value.split(RegExp(r'[,\s]+')).where((k) => k.isNotEmpty);
      final options = AIService.extractOptions(component.raw);
      if (options.isNotEmpty) {
        final resolved = keys.map((k) => _resolveOptionLabel(k, component));
        return resolved.join(', ');
      }
    }

    if (value is num && value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  /// Parse a bool-like value (1/0/true/false/evet/hayır) for display.
  String _parseBoolLikeValue(dynamic value, PromptDictionary d) {
    if (value is bool) return value ? d.labelYes : d.labelNo;
    if (value is int) return value != 0 ? d.labelYes : d.labelNo;
    if (value is double) return value != 0 ? d.labelYes : d.labelNo;
    final str = value.toString().toLowerCase().trim();
    if (str == 'true' || str == '1' || str == 'evet' || str == 'yes') {
      return d.labelYes;
    }
    if (str == 'false' || str == '0' || str == 'hayır' || str == 'no') {
      return d.labelNo;
    }
    return value.toString();
  }

  /// Resolve a raw option value to its human-readable label
  /// by looking up the component's values/data.values array.
  ///
  /// Uses [AIService.extractOptions] which handles all Form.io
  /// component structures (select, radio, selectboxes).
  String _resolveOptionLabel(String rawValue, ComponentModel component) {
    final options = AIService.extractOptions(component.raw);
    for (final opt in options) {
      if (opt['value'] == rawValue) {
        return opt['label'] ?? rawValue;
      }
    }
    return rawValue;
  }

  void _onFormComplete(Map<String, dynamic> formData) {
    // Use merged form data that reconstructs survey/datagrid structures
    final mergedData = _engine.mergedFormData;
    _addMessage(ConversationMessage.system(
      text: PromptDictionary.current.formComplete,
    ));

    // Show summary dialog
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => FormSummaryDialog(
          formData: mergedData,
          questions: _engine.allQuestions,
          onSubmit: () {
            // Clear session on successful submit
            if (widget.formId != null) {
              SessionService.clear(widget.formId!);
            }
            widget.onSubmit?.call(mergedData);
          },
          onEditField: (key) {
            // Clear that answer and re-ask
            _engine.clearAnswer(key);
            final question = _engine.allQuestions
                .where((q) => q.key == key)
                .firstOrNull;
            if (question != null) {
              _addMessage(ConversationMessage.system(
                text: PromptDictionary.current
                    .summaryEditField(question.label),
              ));
            }
            _askNextQuestion();
          },
        ),
      );
    });
  }

  /// Reset the entire form after confirmation.
  void _resetForm() {
    final d = PromptDictionary.current;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(d.resetConfirmTitle),
        content: Text(d.resetConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(d.resetConfirmNo),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _engine.resetAll();
              _clearConfirmation();
              setState(() {
                _messages.clear();
                _isProcessingAnswer = false;
              });
              // Clear saved session
              if (widget.formId != null) {
                SessionService.clear(widget.formId!);
              }
              // Re-add welcome + start fresh
              _addMessage(ConversationMessage.system(
                text: d.formResetDone,
              ));
              _askNextQuestion();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(d.resetConfirmYes),
          ),
        ],
      ),
    );
  }

  /// Called when the microphone listener times out with no speech.
  void _handleSilence() {
    final question = _engine.getNextQuestion();
    if (question == null) return;

    if (question.required) {
      _addMessage(ConversationMessage.system(
        text: PromptDictionary.current.silenceRequiredWarning,
      ));
      // Re-ask the same question
      _askNextQuestion();
    } else {
      // Auto-skip optional field
      _engine.updateAnswer(question.key, '');
      _addMessage(ConversationMessage.system(
        text: PromptDictionary.current.silenceSkipped,
      ));
      if (!_engine.isComplete) {
        _askNextQuestion();
      }
    }
  }

  /// Called when _processAnswer receives empty text (keyboard or STT).
  void _handleEmptyAnswer() {
    final question = _engine.getNextQuestion();
    if (question == null) return;

    if (question.required) {
      _addMessage(ConversationMessage.system(
        text: PromptDictionary.current.emptyAnswerRequiredWarning,
      ));
    } else {
      // Auto-skip optional field
      _engine.updateAnswer(question.key, '');
      _addMessage(ConversationMessage.system(
        text: PromptDictionary.current.emptyAnswerSkipped,
      ));
      if (!_engine.isComplete) {
        _askNextQuestion();
      }
    }
  }

  void _addMessage(ConversationMessage message) {
    setState(() => _messages.add(message));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Build UI ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.form.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface.withAlpha(220),
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_engine.answeredCount}/${_engine.totalVisibleQuestions}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface,
              theme.colorScheme.primaryContainer.withAlpha(30),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress bar
              _buildProgressBar(theme),
              // Chat messages
              Expanded(child: _buildMessageList(theme)),
              // Voice indicator
              if (_voiceService.state != VoiceState.idle)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: VoiceIndicator(
                    voiceState: _voiceService.state,
                    soundLevel: _voiceService.soundLevel,
                  ),
                ),
              // Partial recognition text
              if (_voiceService.state == VoiceState.listening &&
                  _voiceService.lastRecognizedText.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Text(
                    _voiceService.lastRecognizedText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              // Text input (when toggled)
              if (_showTextInput) _buildTextInput(theme),
              // Bottom controls
              _buildBottomControls(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: _engine.progress,
          minHeight: 4,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildMessageList(ThemeData theme) {
    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              PromptDictionary.current.labelInitializing,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return ChatBubble(message: _messages[index]);
      },
    );
  }

  Widget _buildTextInput(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _textFocusNode,
              decoration: InputDecoration(
                hintText: PromptDictionary.current.hintTextInput,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withAlpha(100),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                suffixIcon: IconButton(
                  icon: Icon(Icons.send_rounded,
                      color: theme.colorScheme.primary),
                  onPressed:
                      _isProcessingAnswer ? null : _submitTextAnswer,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: _isProcessingAnswer ? null : (_) => _submitTextAnswer(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Reset form button
          IconButton(
            onPressed:
                _isProcessingAnswer ? null : _resetForm,
            icon: Icon(
              Icons.restart_alt_rounded,
              color: _engine.canUndo
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline,
            ),
            tooltip: PromptDictionary.current.tooltipReset,
          ),
          // Repeat question button
          IconButton(
            onPressed: _isProcessingAnswer ? null : _repeatLastQuestion,
            icon: Icon(
              Icons.replay_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: PromptDictionary.current.tooltipRepeat,
          ),
          const Spacer(),
          // Main mic button
          _buildMicButton(theme),
          const Spacer(),
          // Toggle text input
          IconButton(
            onPressed: () {
              setState(() => _showTextInput = !_showTextInput);
              if (_showTextInput) {
                _textFocusNode.requestFocus();
              }
            },
            icon: Icon(
              _showTextInput
                  ? Icons.keyboard_hide_rounded
                  : Icons.keyboard_rounded,
              color: _showTextInput
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: _showTextInput ? PromptDictionary.current.tooltipHideKeyboard : PromptDictionary.current.tooltipShowKeyboard,
          ),
          // Skip button
          IconButton(
            onPressed: _isProcessingAnswer ? null : _skipQuestion,
            icon: Icon(
              Icons.skip_next_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: PromptDictionary.current.tooltipSkip,
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton(ThemeData theme) {
    final isListening = _voiceService.state == VoiceState.listening;
    final canListen =
        _isInitialized && !_isProcessingAnswer && _voiceService.isSttAvailable;

    return GestureDetector(
      onTap: canListen
          ? (isListening ? _voiceService.stopListening : _startListening)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isListening ? 80 : 64,
        height: isListening ? 80 : 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isListening
                ? [
                    theme.colorScheme.error,
                    theme.colorScheme.error.withAlpha(180)
                  ]
                : canListen
                    ? [theme.colorScheme.primary, theme.colorScheme.tertiary]
                    : [Colors.grey, Colors.grey.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isListening
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary)
                  .withAlpha(isListening ? 100 : 50),
              blurRadius: isListening ? 24 : 12,
              spreadRadius: isListening ? 4 : 0,
            ),
          ],
        ),
        child: Icon(
          isListening ? Icons.stop_rounded : Icons.mic_rounded,
          color: Colors.white,
          size: isListening ? 36 : 28,
        ),
      ),
    );
  }

  void _repeatLastQuestion() {
    final question = _engine.getNextQuestion();
    if (question != null) {
      final text = _engine.buildQuestionText(question);
      _voiceService.speak(text);
    }
  }

  void _skipQuestion() {
    final question = _engine.getNextQuestion();
    if (question == null) return;

    // Skip optional questions, but warn for required
    if (question.required) {
      _addMessage(ConversationMessage.system(
        text: PromptDictionary.current.questionRequired,
      ));
      return;
    }

    _engine.updateAnswer(question.key, '');
    _addMessage(ConversationMessage.system(
      text: PromptDictionary.current.questionSkipped(question.label),
    ));

    if (!_engine.isComplete) {
      _askNextQuestion();
    }
  }
}
