// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:formio_api/formio_api.dart';

import 'config/app_secrets.dart';
import 'models/form_compatibility_checker.dart';
import 'models/prompt_dictionary.dart';
import 'screens/chat_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/ai_service.dart';

void main() {
  runApp(const FormioVoiceChatApp());
}

class FormioVoiceChatApp extends StatelessWidget {
  const FormioVoiceChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speech2Form',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const FormSelectionPage(),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.light,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.dark,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    );
  }
}

/// Form selection page — login to Form.io, fetch forms, configure AI.
class FormSelectionPage extends StatefulWidget {
  const FormSelectionPage({super.key});

  @override
  State<FormSelectionPage> createState() => _FormSelectionPageState();
}

class _FormSelectionPageState extends State<FormSelectionPage> {
  // ─── Form.io Config ──────────────────────────────────────
  final _baseUrlController =
      TextEditingController(text: AppSecrets.formioBaseUrl);
  final _formIdController =
      TextEditingController(text: AppSecrets.formioFormId);
  final _emailController = TextEditingController(text: AppSecrets.formioEmail);
  final _passwordController =
      TextEditingController(text: AppSecrets.formioPassword);

  // ─── OpenAI Config ──────────────────────────────────────
  final _apiKeyController =
      TextEditingController(text: AppSecrets.openAiApiKey);

  // ─── State ──────────────────────────────────────────────
  final AIService _aiService = AIService();
  List<FormModel> _forms = [];
  bool _isLoading = false;
  bool _isLoggedIn = false;
  String? _error;
  String? _statusMessage;
  ApiClient? _apiClient;
  SubmissionService? _submissionService;

  @override
  void initState() {
    super.initState();
    // Initialize AI with preconfigured key
    final key = _apiKeyController.text.trim();
    if (key.isNotEmpty) {
      _aiService.initialize(apiKey: key);
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _formIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  // ─── API Actions ────────────────────────────────────────

  Future<void> _loginAndFetchForm() async {
    final baseUrl = _baseUrlController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final formId = _formIdController.text.trim();

    if (baseUrl.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Tüm alanları doldurun.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _statusMessage = 'Form.io\'ya bağlanılıyor...';
    });

    try {
      // Configure API client
      ApiClient.setBaseUrl(Uri.parse(baseUrl));
      _apiClient = ApiClient();
      final authService = AuthService(_apiClient!);

      // Login
      setState(() => _statusMessage = 'Giriş yapılıyor...');
      final user = UserModel(email: email, password: password);
      await authService.login(user);

      // Extract JWT token from login response
      // The ApiClient interceptor will handle the token from the response
      // We need to set it manually from the response headers
      final loginResponse = await _apiClient!.dio
          .post('/user/login', data: user.toLoginJson());
      final token = loginResponse.headers.value('x-jwt-token');
      if (token != null) {
        ApiClient.setAuthToken(token);
        print('🔑 JWT Token obtained');
      }

      setState(() {
        _isLoggedIn = true;
        _statusMessage = 'Form çekiliyor...';
      });

      // Fetch form
      final formService = FormService(_apiClient!);
      _submissionService = SubmissionService(_apiClient!);

      if (formId.isNotEmpty) {
        // Fetch specific form by ID
        final form = await formService.getFormByPath(formId);
        setState(() {
          _forms = [form];
          _isLoading = false;
          _statusMessage = null;
        });
        print('✅ Form yüklendi: ${form.title}');
      } else {
        // Fetch all forms
        final forms = await formService.fetchForms();
        setState(() {
          _forms = forms;
          _isLoading = false;
          _statusMessage = null;
        });
        print('✅ ${forms.length} form yüklendi');
      }
    } catch (e) {
      setState(() {
        _error = 'Bağlantı hatası: $e';
        _isLoading = false;
        _statusMessage = null;
      });
      print('❌ Hata: $e');
    }
  }

  Future<void> _loadFromAssets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await rootBundle.loadString('assets/sample_form.json');
      final data = jsonDecode(response) as List;
      final forms =
          data.map((e) => FormModel.fromJson(e as Map<String, dynamic>)).toList();

      setState(() {
        _forms = forms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Asset yükleme hatası: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitForm(
      FormModel form, Map<String, dynamic> formData) async {
    if (_submissionService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Form.io API bağlantısı yok. Form gönderilemiyor.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final submission =
          await _submissionService!.submit('/${form.path}', formData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Form gönderildi! (ID: ${submission.id})'),
          backgroundColor: Colors.green,
        ),
      );
      print('✅ Submission ID: ${submission.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Form gönderilemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('❌ Submission error: $e');
    }
  }

  void _openForm(FormModel form) {
    // Use form path or id as the persistence key
    final formId = form.path.isNotEmpty ? form.path : form.title;

    // ── Compatibility check ────────────────────────────────
    final result = FormCompatibilityChecker.check(form);
    if (!result.isCompatible) {
      _showIncompatibleFormDialog(result);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WelcomeScreen(
          formTitle: form.title,
          onStart: ({
            required bool confirmationEnabled,
            required bool aiEnabled,
            required bool skipOptional,
            required bool offlineMode,
            required String locale,
          }) {
            // Apply AI mode from config
            _aiService.fallbackMode = !aiEnabled;

            // Apply offline mode — force local AI when offline
            if (offlineMode) {
              _aiService.fallbackMode = true;
            }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  form: form,
                  aiService: _aiService,
                  formId: formId,
                  confirmationEnabled: confirmationEnabled,
                  skipOptional: skipOptional,
                  offlineMode: offlineMode,
                  locale: locale,
                  onSubmit: (formData) => _submitForm(form, formData),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  /// Show a blocking dialog when the form has required fields
  /// that cannot be filled by voice input.
  void _showIncompatibleFormDialog(FormCompatibilityResult result) {
    final d = PromptDictionary.current;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: theme.colorScheme.error,
          size: 48,
        ),
        title: Text(
          d.incompatibleFormTitle,
          style: TextStyle(
            color: theme.colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.incompatibleFormMessage,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                d.incompatibleFieldsHeader,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...result.unsupportedRequiredFields.map(
                (field) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.block_rounded,
                        size: 18,
                        color: theme.colorScheme.error.withAlpha(180),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              field.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${field.type} — ${field.reason}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(d.incompatibleGoBack),
          ),
        ],
      ),
    );
  }

  void _showConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yapılandırma'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _configField(
                _baseUrlController,
                'Form.io URL',
                Icons.link_rounded,
              ),
              const SizedBox(height: 12),
              _configField(
                _formIdController,
                'Form ID',
                Icons.tag_rounded,
              ),
              const SizedBox(height: 12),
              _configField(
                _emailController,
                'E-posta',
                Icons.email_rounded,
              ),
              const SizedBox(height: 12),
              _configField(
                _passwordController,
                'Şifre',
                Icons.lock_rounded,
                obscure: true,
              ),
              const Divider(height: 24),
              _configField(
                _apiKeyController,
                'OpenAI API Key',
                Icons.key_rounded,
                obscure: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              final key = _apiKeyController.text.trim();
              if (key.isNotEmpty) {
                _aiService.initialize(apiKey: key);
              }
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _configField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Speech2Form',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _showConfigDialog,
            icon: Icon(
              Icons.settings_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Yapılandırma',
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection card
          _buildConnectionCard(theme),
          const SizedBox(height: 16),
          // Or load from assets
          if (_forms.isEmpty)
            TextButton.icon(
              onPressed: _isLoading ? null : _loadFromAssets,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Yerel örnekten yükle'),
            ),
          // Form list
          if (_forms.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Formlar',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            ..._forms.map((form) => _buildFormCard(form, theme)),
          ],
          // Error
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _isLoggedIn
              ? theme.colorScheme.primary.withAlpha(100)
              : theme.colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isLoggedIn
                          ? [Colors.green, Colors.green.shade700]
                          : [
                              theme.colorScheme.primary,
                              theme.colorScheme.tertiary
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isLoggedIn ? Icons.cloud_done_rounded : Icons.cloud_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoggedIn
                            ? 'Bağlantı başarılı'
                            : 'Form.io Bağlantısı',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (_statusMessage != null)
                        Text(
                          _statusMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        )
                      else
                        Text(
                          _isLoggedIn
                              ? _baseUrlController.text
                              : 'Giriş yaparak formu çekin',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _loginAndFetchForm,
                icon: _isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Icon(_isLoggedIn
                        ? Icons.refresh_rounded
                        : Icons.login_rounded),
                label: Text(
                    _isLoggedIn ? 'Yeniden Çek' : 'Giriş Yap & Formu Çek'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(FormModel form, ThemeData theme) {
    final questionCount =
        form.components.where((c) => c.type != 'button').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      child: InkWell(
        onTap: () => _openForm(form),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.record_voice_over_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      form.title.isNotEmpty ? form.title : 'İsimsiz Form',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$questionCount bileşen · Sesli doldurma',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (form.path.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '/${form.path}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
