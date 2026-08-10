/// A Flutter widget that renders static HTML content based on a
/// Form.io "htmlelement" component.
///
/// This component is read-only and used for displaying custom HTML
/// such as paragraphs, headers, separators, and basic formatting.
library;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:formio/formio.dart';
import 'safe_link.dart';

class HtmlElementComponent extends StatelessWidget {
  /// The Form.io component definition.
  final ComponentModel component;

  /// Complete form data for interpolation
  final Map<String, dynamic>? formData;

  /// Whether to enable clicking on links.
  final bool enableLinks;

  const HtmlElementComponent(
      {super.key,
      required this.component,
      this.formData,
      this.enableLinks = true});

  /// Tags that cannot wrap content, so they render standalone.
  static const _voidTags = {'hr', 'br', 'img', 'input', 'wbr'};

  /// Only a plain element name is accepted; anything else falls back to the
  /// documented default. The tag is written into markup, so an unchecked value
  /// from the schema would be an injection point.
  static final _tagPattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9]*$');

  String get _tag {
    final tag = component.raw['tag']?.toString().trim().toLowerCase() ?? '';
    return _tagPattern.hasMatch(tag) ? tag : 'p';
  }

  /// The content wrapped in its element, so `{tag: h1}` actually renders as a
  /// heading. Previously only `hr` was honoured and everything else was emitted
  /// bare — which meant the tag-based styling below never matched anything.
  String get _htmlContent {
    final tag = _tag;
    final content = InterpolationUtils.interpolate(
        component.raw['content']?.toString() ?? '', formData);
    if (_voidTags.contains(tag)) return '<$tag/>';
    if (content.trim().isEmpty) return '';
    return '<$tag>$content</$tag>';
  }

  /// Optional CSS class (unused by default).
  // String? get _cssClass => component.raw['className'];

  @override
  Widget build(BuildContext context) {
    if (_htmlContent.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Html(
        data: _htmlContent,
        style: {
          // Optionally apply styling based on tag types
          'h1': Style(fontSize: FontSize.xxLarge),
          'p': Style(fontSize: FontSize.medium),
          'hr': Style(margin: Margins.only(top: 12, bottom: 12)),
        },
        onLinkTap: (url, _, __) {
          if (enableLinks) openFormLink(url);
        },
      ),
    );
  }
}
