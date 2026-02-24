/// WelcomeScreen — animated splash with pre-start configuration.
///
/// Shows the Speech2Form branding, form settings (confirmation, AI mode),
/// and a start button to begin the session.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/prompt_dictionary.dart';

class WelcomeScreen extends StatefulWidget {
  final String formTitle;

  /// Called when user presses Start with chosen config.
  final void Function({
    required bool confirmationEnabled,
    required bool aiEnabled,
    required bool skipOptional,
    required bool offlineMode,
    required String locale,
  }) onStart;

  const WelcomeScreen({
    super.key,
    required this.formTitle,
    required this.onStart,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _contentController;
  late Animation<double> _logoScale;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  // Config state
  bool _confirmationEnabled = false;
  bool _aiEnabled = true;
  bool _skipOptional = false;
  bool _offlineMode = false;
  String _selectedLocale = PromptDictionary.currentLocale;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );
    _contentFade = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeIn,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    ));

    // Staggered animation
    _logoController.forward().then((_) {
      _contentController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = PromptDictionary.current;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withAlpha(20),
              theme.colorScheme.surface,
              theme.colorScheme.tertiary.withAlpha(15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 48),
                // Animated logo
                ScaleTransition(
                  scale: _logoScale,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.tertiary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withAlpha(80),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                ScaleTransition(
                  scale: _logoScale,
                  child: Text(
                    d.welcomeAnimTitle,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ScaleTransition(
                  scale: _logoScale,
                  child: Text(
                    d.welcomeAnimSubtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Form title card
                SlideTransition(
                  position: _contentSlide,
                  child: FadeTransition(
                    opacity: _contentFade,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withAlpha(120),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              theme.colorScheme.outlineVariant.withAlpha(80),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.formTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // ── Config Section ──
                SlideTransition(
                  position: _contentSlide,
                  child: FadeTransition(
                    opacity: _contentFade,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.configTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d.configSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),

                        const SizedBox(height: 8),
                        // AI mode toggle
                        _buildConfigTile(
                          theme: theme,
                          icon: Icons.smart_toy_rounded,
                          title: d.configAiMode,
                          subtitle: _aiEnabled
                              ? d.configAiModeDesc
                              : d.configAiLocalDesc,
                          value: _aiEnabled,
                          onChanged: (v) =>
                              setState(() => _aiEnabled = v),
                        ),

                        const SizedBox(height: 16),
                        // Confirmation toggle
                        _buildConfigTile(
                          theme: theme,
                          icon: Icons.verified_rounded,
                          title: d.configConfirmation,
                          subtitle: d.configConfirmationDesc,
                          value: _confirmationEnabled,
                          onChanged: (v) =>
                              setState(() => _confirmationEnabled = v),
                        ),
                        const SizedBox(height: 8),
                        // Skip optional toggle
                        _buildConfigTile(
                          theme: theme,
                          icon: Icons.skip_next_rounded,
                          title: d.configSkipOptional,
                          subtitle: d.configSkipOptionalDesc,
                          value: _skipOptional,
                          onChanged: (v) =>
                              setState(() => _skipOptional = v),
                        ),
                        const SizedBox(height: 8),
                        // Offline mode toggle
                        _buildConfigTile(
                          theme: theme,
                          icon: Icons.wifi_off_rounded,
                          title: d.configOfflineMode,
                          subtitle: d.configOfflineModeDesc,
                          value: _offlineMode,
                          onChanged: (v) =>
                              setState(() => _offlineMode = v),
                        ),
                        const SizedBox(height: 8),
                        // Language selector
                        _buildLanguageTile(theme, d),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Start button
                SlideTransition(
                  position: _contentSlide,
                  child: FadeTransition(
                    opacity: _contentFade,
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          widget.onStart(
                            confirmationEnabled: _confirmationEnabled,
                            aiEnabled: _aiEnabled,
                            skipOptional: _skipOptional,
                            offlineMode: _offlineMode,
                            locale: _selectedLocale,
                          );
                        },
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          d.configStartButton,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? theme.colorScheme.primary.withAlpha(60)
              : theme.colorScheme.outlineVariant.withAlpha(60),
        ),
      ),
      child: SwitchListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value
                ? theme.colorScheme.primary.withAlpha(25)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: value
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildLanguageTile(ThemeData theme, PromptDictionary d) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(60),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.language_rounded,
            color: theme.colorScheme.primary,
            size: 22,
          ),
        ),
        title: Text(
          d.configLanguage,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          d.configLanguageDesc,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'tr', label: Text('TR')),
            ButtonSegment(value: 'en', label: Text('EN')),
          ],
          selected: {_selectedLocale},
          onSelectionChanged: (selected) {
            setState(() {
              _selectedLocale = selected.first;
              PromptDictionary.currentLocale = _selectedLocale;
              PromptDictionary.current =
                  PromptDictionary.forLocale(_selectedLocale);
            });
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}
