/// A Flutter widget that renders day, month, and year dropdowns
/// based on a Form.io "day" component.
///
/// Allows users to select a date by separately choosing the day,
/// month, and year. The result is returned as a single ISO-8601 string.
library;

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';

class DayComponent extends StatefulWidget {
  /// The Form.io component definition.
  final ComponentModel component;

  /// The current ISO-8601 date string (yyyy-MM-dd).
  final String? value;

  /// Complete form data for interpolation
  final Map<String, dynamic>? formData;

  /// Callback called when the date changes.
  final ValueChanged<String?> onChanged;

  const DayComponent(
      {super.key,
      required this.component,
      required this.value,
      this.formData,
      required this.onChanged});

  @override
  State<DayComponent> createState() => _DayComponentState();
}

/// Which sub-field of a `day` component a slot represents.
enum _DayPart { day, month, year }

class _DayComponentState extends State<DayComponent> {
  int? _day;
  int? _month;
  int? _year;

  /// Controllers for parts configured as `{"type": "number"}`; created lazily so
  /// an all-select `day` allocates none.
  final Map<_DayPart, TextEditingController> _controllers = {};

  bool get _isRequired => widget.component.required;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Per-part config from the schema's `fields` map, e.g.
  /// `{"month": {"type": "select", "hide": false}}`.
  Map<String, dynamic> _fieldConfig(_DayPart part) {
    final fields = widget.component.raw['fields'];
    final cfg = fields is Map ? fields[part.name] : null;
    return cfg is Map ? cfg.cast<String, dynamic>() : const {};
  }

  int? _valueOf(_DayPart part) => switch (part) {
        _DayPart.day => _day,
        _DayPart.month => _month,
        _DayPart.year => _year,
      };

  String _labelOf(_DayPart part) => switch (part) {
        _DayPart.day => ComponentFactory.locale.day,
        _DayPart.month => ComponentFactory.locale.month,
        _DayPart.year => ComponentFactory.locale.year,
      };

  void _setPart(_DayPart part, int? value) {
    setState(() => _assign(part, value));
    _updateValue();
  }

  int get _startYear {
    final rawMin = widget.component.raw['fields']?['year']?['min'] ??
        widget.component.raw['minYear'];
    if (rawMin is String) {
      final interpolated =
          InterpolationUtils.interpolate(rawMin, widget.formData);
      return int.tryParse(interpolated) ?? 1900;
    }
    return rawMin is num ? rawMin.toInt() : 1900;
  }

  int get _endYear {
    final rawMax = widget.component.raw['fields']?['year']?['max'] ??
        widget.component.raw['maxYear'];
    if (rawMax is String) {
      final interpolated =
          InterpolationUtils.interpolate(rawMax, widget.formData);
      return int.tryParse(interpolated) ?? DateTime.now().year;
    }
    return rawMax is num ? rawMax.toInt() : DateTime.now().year;
  }

  /// Whether the value puts the day before the month.
  ///
  /// Form.io's `dayFirst` defaults to **false**, i.e. `MM/DD/YYYY`. `@formio/core`
  /// reads the value with `dayFirst ? [0,1,2] : [1,0,2]` (see `validateDay` and
  /// `getDayFormat` in the engine bundle), so writing day-first regardless — as
  /// this component used to — hands the engine the month in the day slot.
  bool get _dayFirst => widget.component.raw['dayFirst'] == true;

  /// The parts that appear in the value, in the order the engine expects.
  ///
  /// Hidden parts are omitted entirely rather than zero-filled: the engine's
  /// `getDayFormat` drops them from the format, and `validateDay` shifts its
  /// indices when the value has fewer than three segments.
  List<_DayPart> get _valueOrder => [
        if (_dayFirst) _DayPart.day,
        _DayPart.month,
        if (!_dayFirst) _DayPart.day,
        _DayPart.year,
      ].where((p) => _fieldConfig(p)['hide'] != true).toList();

  void _updateValue() {
    final order = _valueOrder;
    // A part left blank means there is no date yet; Form.io's own partial marker
    // ("00"/"0000") would read as an invalid day to the engine.
    if (order.any((p) => _valueOf(p) == null)) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(order.map(_formatPart).join('/'));
  }

  String _formatPart(_DayPart part) => part == _DayPart.year
      ? _valueOf(part)!.toString().padLeft(4, '0')
      : _valueOf(part)!.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    _parseValue(widget.value);
  }

  void _parseValue(String? raw) {
    if (raw == null || raw.isEmpty) return;

    if (raw.contains('/')) {
      // Slash form: segments map to the visible parts, in engine order.
      final segments = raw.split('/');
      final order = _valueOrder;
      for (var i = 0; i < order.length && i < segments.length; i++) {
        _assign(order[i], int.tryParse(segments[i]));
      }
    } else if (raw.contains('-')) {
      // ISO YYYY-MM-DD[THH:…], as stored by other date components.
      final segments = raw.split('-');
      if (segments.length >= 3) {
        _year = int.tryParse(segments[0]);
        _month = int.tryParse(segments[1]);
        _day = int.tryParse(segments[2].split('T').first);
      }
    }

    // Form.io uses "00"/"0000" to mean "not set". Treat any non-positive part as
    // unset so it never lands outside the dropdown's options.
    _day = (_day ?? 0) > 0 ? _day : null;
    _month = (_month ?? 0) > 0 ? _month : null;
    _year = (_year ?? 0) > 0 ? _year : null;
  }

  void _assign(_DayPart part, int? value) {
    switch (part) {
      case _DayPart.day:
        _day = value;
      case _DayPart.month:
        _month = value;
      case _DayPart.year:
        _year = value;
    }
  }

  /// Options for a part rendered as a select.
  List<int> _optionsFor(_DayPart part) => switch (part) {
        _DayPart.day => List.generate(31, (i) => i + 1),
        _DayPart.month => List.generate(12, (i) => i + 1),
        _DayPart.year =>
          List.generate(_endYear - _startYear + 1, (i) => _endYear - i),
      };

  /// Renders one part per its `fields` config.
  ///
  /// `type` defaults to **`text`** per Form.io's Day docs, so only an explicit
  /// `select` gets a dropdown; `text`, `number` and an absent value are all text
  /// inputs.
  Widget _buildPart(_DayPart part) {
    final cfg = _fieldConfig(part);
    // `hideInputLabels` suppresses the per-part labels; the placeholder then
    // carries the meaning.
    final showLabels = widget.component.raw['hideInputLabels'] != true;
    final label = showLabels ? _labelOf(part) : null;
    // Only the configured placeholder — substituting the label here would
    // defeat `hideInputLabels`, which is an explicit request for no labels.
    final placeholder = cfg['placeholder']?.toString();
    final hint = (placeholder?.isNotEmpty ?? false) ? placeholder : null;

    if (cfg['type'] != 'select') {
      final current = _valueOf(part);
      final controller = _controllers.putIfAbsent(
          part, () => TextEditingController(text: current?.toString() ?? ''));
      // Keep the field in step when the value changed elsewhere (e.g. a
      // calculated value) without fighting the user mid-edit.
      final asText = current?.toString() ?? '';
      if (!controller.selection.isValid && controller.text != asText) {
        controller.text = asText;
      }
      return TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: part == _DayPart.year ? 4 : 2,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
        ),
        onChanged: (raw) {
          final parsed = int.tryParse(raw);
          _setPart(part, (parsed ?? 0) > 0 ? parsed : null);
        },
      );
    }

    final options = _optionsFor(part);
    final current = _valueOf(part);
    return DropdownButtonFormField<int>(
      // A DropdownButton asserts if its value isn't among its items, so only
      // pass a selection the item list actually contains.
      initialValue: options.contains(current) ? current : null,
      decoration: InputDecoration(labelText: label, hintText: hint),
      items: options
          .map((v) => DropdownMenuItem(value: v, child: Text(v.toString())))
          .toList(),
      onChanged: (val) => _setPart(part, val),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasError =
        _isRequired && (_day == null || _month == null || _year == null);

    // Rendered in the same order the value is written, so the fields read the
    // way the stored string does.
    final visible = _valueOrder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.component.label,
            style: FormioThemeScope.of(context).resolvedLabelStyle(context)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final part in visible) ...[
              if (part != visible.first) const SizedBox(width: 8),
              Expanded(child: _buildPart(part)),
            ],
          ],
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                ComponentFactory.locale
                    .getRequiredMessage(widget.component.label),
                style:
                    FormioThemeScope.of(context).resolvedErrorStyle(context)),
          ),
      ],
    );
  }
}
