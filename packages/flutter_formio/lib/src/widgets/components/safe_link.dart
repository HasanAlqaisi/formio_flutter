/// Opening links found in form-authored HTML (`content`, `htmlelement`).
///
/// Those components render HTML that comes from the form definition, not from
/// the app. Handing an arbitrary href straight to `launchUrl` has two problems:
///
///  * `Uri.parse` throws [FormatException] on a malformed href, so a bad link
///    crashes on tap rather than doing nothing.
///  * any scheme would launch — `tel:`, `sms:`, `file:`, a custom app deep link.
///    Whoever authors a form could therefore trigger actions outside the form.
///    Form definitions are usually trusted, but in a multi-tenant setup the
///    author may be less privileged than the person using the app.
///
/// Note `flutter_html` does not execute JavaScript, so `<script>` in content is
/// inert — the tag/attribute allow-listing that Form.io's Sanitize Configuration
/// covers is a browser XSS concern that does not carry over. Link handling is the
/// part that does.
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Schemes a form's content is allowed to open.
const _allowedSchemes = {'http', 'https', 'mailto', 'tel'};

/// Opens [url] if it parses and uses an allowed scheme; otherwise does nothing.
Future<void> openFormLink(String? url) async {
  if (url == null || url.trim().isEmpty) return;
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !_allowedSchemes.contains(uri.scheme.toLowerCase())) {
    if (kDebugMode) {
      debugPrint('⚠️ Ignored a form content link with an unsupported target: '
          '$url');
    }
    return;
  }
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    if (kDebugMode) debugPrint('⚠️ Could not open $uri: $e');
  }
}
