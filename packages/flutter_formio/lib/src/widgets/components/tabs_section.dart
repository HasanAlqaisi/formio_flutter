/// A real, swipeable tab bar for Form.io's `tabs` layout component.
///
/// The renderer used to flatten tabs — every tab's label became a bold heading
/// and all their contents were concatenated, so a ten-tab form rendered as one
/// very long page.
///
/// The catch with [TabBarView] is that it is a [PageView], so it needs a bounded
/// height, and the renderer's body is a scroll view — there is no height to
/// inherit. So each page is given an unbounded-height wrapper, its natural
/// content height is measured, and the viewport is sized to it. The height then
/// interpolates between the two neighbouring pages as you swipe, so nothing is
/// clipped mid-gesture.
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../component_builders.dart' show sectionCard;
import '../form_theme.dart';

class FormioTabsSection extends StatefulWidget {
  const FormioTabsSection({
    super.key,
    required this.labels,
    required this.contentBuilder,
    required this.theme,
    this.hasError = const [],
  });

  /// One label per tab, in order.
  final List<String> labels;

  /// Builds the content of the tab at [index].
  final Widget Function(int index) contentBuilder;

  /// Whether the tab at each index contains a currently-shown validation error,
  /// so it can be flagged — otherwise an invalid field on another tab is
  /// unfindable.
  final List<bool> hasError;

  final FormioTheme theme;

  @override
  State<FormioTabsSection> createState() => _FormioTabsSectionState();
}

class _FormioTabsSectionState extends State<FormioTabsSection>
    with TickerProviderStateMixin {
  late TabController _controller;

  /// Natural content height per tab, filled in as each page first lays out.
  final Map<int, double> _heights = {};

  /// Used for pages not yet measured, so the first frame is close instead of
  /// collapsing to nothing.
  static const _initialHeight = 220.0;

  @override
  void initState() {
    super.initState();
    _controller = _newController(0);
  }

  @override
  void didUpdateWidget(FormioTabsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Conditional logic can add or remove tabs, and a TabController's length is
    // fixed at construction.
    if (oldWidget.labels.length != widget.labels.length) {
      final previous = _controller.index;
      _controller.dispose();
      _heights.clear();
      _controller = _newController(previous.clamp(0, widget.labels.length - 1));
    }
  }

  TabController _newController(int initialIndex) => TabController(
        length: widget.labels.length,
        initialIndex: initialIndex,
        vsync: this,
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _report(int index, double height) {
    if (!mounted || _heights[index] == height) return;
    setState(() => _heights[index] = height);
  }

  double _heightAt(int index) =>
      _heights[index] ??
      // Fall back to the tallest page seen so far — a better guess than a
      // constant once anything has been measured.
      (_heights.isEmpty ? _initialHeight : _heights.values.reduce(max));

  static double max(double a, double b) => a > b ? a : b;

  /// Height for the current scroll position, interpolated across a swipe.
  double get _viewportHeight {
    final position =
        _controller.animation?.value ?? _controller.index.toDouble();
    final last = widget.labels.length - 1;
    final lower = position.floor().clamp(0, last);
    final upper = position.ceil().clamp(0, last);
    if (lower == upper) return _heightAt(lower);
    return lerpDouble(
      _heightAt(lower),
      _heightAt(upper),
      position - lower,
    )!;
  }

  bool _errorAt(int index) =>
      index < widget.hasError.length && widget.hasError[index];

  @override
  Widget build(BuildContext context) {
    final errorColor = widget.theme.resolvedErrorStyle(context).color ??
        Theme.of(context).colorScheme.error;

    // Built once, outside the AnimatedBuilder, so tracking the swipe animation
    // resizes the viewport without rebuilding every page.
    final pages = TabBarView(
      controller: _controller,
      children: [
        for (var i = 0; i < widget.labels.length; i++)
          // The scroll view hands its child unbounded height, which is what lets
          // the content report its natural size. It never scrolls itself — the
          // viewport is sized to fit, and the form's own scroll view owns
          // vertical gestures.
          SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: _MeasureHeight(
              onHeight: (h) => _report(i, h),
              child: sectionCard(widget.theme, widget.contentBuilder(i)),
            ),
          ),
      ],
    );

    final formioTheme = FormioThemeScope.of(context);
    final accent = formioTheme.resolvedAccentColor(context);
    final labelBase = formioTheme.resolvedLabelStyle(context);
    final mutedLabel = labelBase.color ?? Theme.of(context).hintColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _controller,
          // Forms routinely have more tabs than fit; never squeeze them.
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerHeight: 0,
          // The active tab gets the accent; the inactive ones get the muted
          // label colour. It used to be handed the field-label style for
          // `labelStyle`, which in TabBar governs the *selected* tab — so the
          // active tab wore the secondary grey and read as disabled while the
          // inactive ones kept the brighter default.
          //
          // Colour is set on the styles *and* the label colours, so it does not
          // matter which of the two TabBar gives precedence to.
          labelColor: accent,
          unselectedLabelColor: mutedLabel,
          indicatorColor: accent,
          labelStyle:
              labelBase.copyWith(color: accent, fontWeight: FontWeight.w600),
          unselectedLabelStyle: labelBase.copyWith(color: mutedLabel),

          tabs: [
            for (var i = 0; i < widget.labels.length; i++)
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.labels[i],
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_errorAt(i)) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.error_outline, size: 14, color: errorColor),
                    ],
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _controller.animation ?? _controller,
          builder: (context, child) =>
              SizedBox(height: _viewportHeight, child: child),
          child: pages,
        ),
      ],
    );
  }
}

/// Reports its child's laid-out height, so a [PageView] can be sized to it.
class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  _RenderMeasureHeight createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) =>
      renderObject.onHeight = onHeight;
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = child?.size.height ?? 0;
    if (_reported == height) return;
    _reported = height;
    // Cannot notify during layout; the listener calls setState.
    SchedulerBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
