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
    required this.ensureLoaded,
    this.loading = false,
    this.error,
  });

  final List<Map<String, dynamic>> options;
  final bool loading;
  final Object? error;

  /// Fetches if it has not happened yet, and resolves with the options.
  ///
  /// It *returns* them rather than only triggering, because a lazy control opens
  /// a picker on its own route: options arriving afterwards never reach that
  /// route, so the caller has to be handed the list it should render.
  ///
  /// Idempotent — concurrent callers share one request — and safe to call during
  /// a build.
  final Future<List<Map<String, dynamic>>> Function() ensureLoaded;
}

class RemoteSelectOptions extends StatefulWidget {
  const RemoteSelectOptions({
    super.key,
    required this.component,
    required this.formData,
    required this.builder,
    this.client,
    this.resourceSource,
  });

  /// The component's raw schema.
  final Map<String, dynamic> component;

  /// Current submission, so `{{data.x}}` in the url or headers can interpolate.
  final Map<String, dynamic> formData;

  final Widget Function(BuildContext context, RemoteOptionsState state) builder;

  /// Injectable for tests; a plain [Dio] otherwise.
  final Dio? client;

  /// Project URL and credentials for `dataSrc: "resource"`. Null means resource
  /// components cannot be fetched, which is reported as an error rather than an
  /// empty list.
  final FormioResourceSource? resourceSource;

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

  /// The in-flight (or finished) request, so repeated calls share one fetch.
  /// Null until something asks — under `lazyLoad`, nothing does until a control
  /// opens.
  Future<List<Map<String, dynamic>>>? _pending;

  /// Form.io's `lazyLoad`: hold the request until the control needs its options,
  /// instead of firing one per select the moment the form is built.
  bool get _lazy => widget.component['lazyLoad'] == true;

  @override
  void initState() {
    super.initState();
    // Eager: start now, not a microtask later, so the very first frame can show
    // that a wait is happening.
    if (!_lazy) _pending = _run();
  }

  @override
  void didUpdateWidget(RemoteSelectOptions oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An interpolated url can change when the data it references changes. Only
    // refetch if something already asked for these options — a lazy select that
    // was never opened stays untouched.
    if (_pending != null && _resolvedUrl(oldWidget) != _resolvedUrl(widget)) {
      _pending = null;
      _ensureLoaded();
    }
  }

  Future<List<Map<String, dynamic>>> _ensureLoaded() =>
      _pending ??= _deferredRun();

  /// Yields past the current build before touching state, so a caller may invoke
  /// this from its own `build` without a setState-during-build.
  Future<List<Map<String, dynamic>>> _deferredRun() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return const [];
    return _run();
  }

  Future<List<Map<String, dynamic>>> _run() async {
    await _load();
    return _options;
  }

  /// The endpoint for this component, whichever source it uses, or null when it
  /// has none.
  String? _resolvedUrl(RemoteSelectOptions w) {
    if (selectDataSourceOf(w.component) == SelectDataSource.resource) {
      final id = resourceIdOf(w.component);
      final source = w.resourceSource;
      if (id == null || source == null) return null;
      return source.submissionsUrl(id, limit: selectLimit(w.component));
    }
    final data = w.component['data'];
    final url = data is Map ? data['url']?.toString() : null;
    if (url == null || url.trim().isEmpty) return null;
    return InterpolationUtils.interpolate(url, w.formData);
  }

  Map<String, dynamic> _headers() {
    final data = widget.component['data'];
    final configured = data is Map ? data['headers'] : null;
    // A resource request carries the project's credentials; the schema has no
    // place to put them.
    final headers = <String, dynamic>{...?widget.resourceSource?.headers};
    if (configured is! List) return headers;
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
    if (url == null) {
      // A resource component with no configured project is misconfigured, not
      // empty. Saying so beats offering a list that will never fill.
      if (selectDataSourceOf(widget.component) == SelectDataSource.resource) {
        if (kDebugMode) {
          debugPrint('⚠️ Select "${widget.component['key']}" uses '
              'dataSrc: "resource" but no FormioResourceSource was supplied, '
              'so its options cannot be fetched.');
        }
        if (mounted) {
          setState(() => _error = StateError('No FormioResourceSource'));
        }
      }
      return;
    }

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
          ensureLoaded: _ensureLoaded,
        ),
      );
}
