/// Loads a select's options from `data.url` (`dataSrc: "url"`).
///
/// The engine never fetches for us — `fetchProcessInfo` runs only in the
/// server-side `submission` target — so a url-backed select showed an empty
/// dropdown. This wrapper does the request, then hands the resolved options to
/// [builder] along with the loading/error state so the control can show what is
/// going on instead of silently offering nothing.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../core/interpolation_utils.dart';
import 'select_options.dart';

/// Responses keyed by resolved url, so two components sharing a source fetch
/// once and a rebuild does not re-request.
final Map<String, List<Map<String, dynamic>>> _cache = {};

/// Options plus the state of the request that produced them.
@immutable
class RemoteOptionsState {
  const RemoteOptionsState({
    required this.options,
    this.loading = false,
    this.error,
  });

  final List<Map<String, dynamic>> options;
  final bool loading;
  final Object? error;
}

class RemoteSelectOptions extends StatefulWidget {
  const RemoteSelectOptions({
    super.key,
    required this.component,
    required this.formData,
    required this.builder,
    this.client,
  });

  /// The component's raw schema.
  final Map<String, dynamic> component;

  /// Current submission, so `{{data.x}}` in the url or headers can interpolate.
  final Map<String, dynamic> formData;

  final Widget Function(BuildContext context, RemoteOptionsState state) builder;

  /// Injectable for tests; a plain [Dio] otherwise.
  final Dio? client;

  /// Drops every cached response. Call between tests, or after a sign-in that
  /// changes what the endpoints return.
  static void clearCache() => _cache.clear();

  @override
  State<RemoteSelectOptions> createState() => _RemoteSelectOptionsState();
}

class _RemoteSelectOptionsState extends State<RemoteSelectOptions> {
  List<Map<String, dynamic>> _options = const [];
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RemoteSelectOptions oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An interpolated url can change when the data it references changes.
    if (_resolvedUrl(oldWidget) != _resolvedUrl(widget)) _load();
  }

  String? _resolvedUrl(RemoteSelectOptions w) {
    final data = w.component['data'];
    final url = data is Map ? data['url']?.toString() : null;
    if (url == null || url.trim().isEmpty) return null;
    return InterpolationUtils.interpolate(url, w.formData);
  }

  Map<String, dynamic> _headers() {
    final data = widget.component['data'];
    final configured = data is Map ? data['headers'] : null;
    if (configured is! List) return const {};
    final headers = <String, dynamic>{};
    for (final entry in configured) {
      if (entry is! Map) continue;
      final key = entry['key']?.toString();
      final value = entry['value']?.toString();
      if (key == null || key.isEmpty || value == null) continue;
      headers[key] = InterpolationUtils.interpolate(value, widget.formData);
    }
    return headers;
  }

  Future<void> _load() async {
    final url = _resolvedUrl(widget);
    if (url == null) return;

    final cached = _cache[url];
    if (cached != null) {
      setState(() {
        _options = cached;
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = widget.client ?? Dio();
      final response = await client.get<dynamic>(
        url,
        options: Options(headers: _headers()),
      );
      final options = optionsFromPayload(response.data, widget.component);
      _cache[url] = options;
      if (!mounted) return;
      setState(() {
        _options = options;
        _loading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Could not load select options from $url: $e');
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(
        context,
        RemoteOptionsState(
          options: _options,
          loading: _loading,
          error: _error,
        ),
      );
}
