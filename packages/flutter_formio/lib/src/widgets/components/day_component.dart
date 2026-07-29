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

  const DayComponent({super.key, required this.component, required this.value, this.formData, required this.onChanged});

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
    setState(() {
      switch (part) {
        case _DayPart.day:
          _day = value;
        case _DayPart.month:
          _month = value;
        case _DayPart.year:
          _year = value;
      }
    });
    _updateValue();
  }

  int get _startYear {
    final rawMin = widget.component.raw['fields']?['year']?['min'] ?? widget.component.raw['minYear'];
    if (rawMin is String) {
      final interpolated = InterpolationUtils.interpolate(rawMin, widget.formData);
      return int.tryParse(interpolated) ?? 1900;
    }
    return rawMin is num ? rawMin.toInt() : 1900;
  }

  int get _endYear {
    final rawMax = widget.component.raw['fields']?['year']?['max'] ?? widget.component.raw['maxYear'];
    if (rawMax is String) {
      final interpolated = InterpolationUtils.interpolate(rawMax, widget.formData);
      return int.tryParse(interpolated) ?? DateTime.now().year;
    }
    return rawMax is num ? rawMax.toInt() : DateTime.now().year;
  }

  void _updateValue() {
    if (_day != null && _month != null && _year != null) {
      // Form.io expects DD/MM/YYYY format for day component
      final formatted = '${_day!.toString().padLeft(2, '0')}/${_month!.toString().padLeft(2, '0')}/${_year!.toString().padLeft(4, '0')}';
      widget.onChanged(formatted);
    } else {
      widget.onChanged(null);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.value != null && widget.value!.isNotEmpty) {
      // Try parsing DD/MM/YYYY format first (Form.io format)
      if (widget.value!.contains('/')) {
        final parts = widget.value!.split('/');
        if (parts.length == 3) {
          _day = int.tryParse(parts[0]);
          _month = int.tryParse(parts[1]);
          _year = int.tryParse(parts[2]);
        }
      }
      // Fallback to YYYY-MM-DD format (ISO format)
      else if (widget.value!.contains('-')) {
        final parts = widget.value!.split('-');
        if (parts.length >= 3) {
          _year = int.tryParse(parts[0]);
          _month = int.tryParse(parts[1]);
          _day = int.tryParse(parts[2].split('T').first); // Handle ISO datetime
        }
      }
      // Form.io uses "00/00/0000" (and zero parts) to mean "no date". Treat any
      // non-positive part as unset so it never lands outside the dropdowns.
      _day = (_day != null && _day! > 0) ? _day : null;
      _month = (_month != null && _month! > 0) ? _month : null;
      _year = (_year != null && _year! > 0) ? _year : null;
    }
  }

  /// Options for a part rendered as a select.
  List<int> _optionsFor(_DayPart part) => switch (part) {
        _DayPart.day => List.generate(31, (i) => i + 1),
        _DayPart.month => List.generate(12, (i) => i + 1),
        _DayPart.year =>
          List.generate(_endYear - _startYear + 1, (i) => _endYear - i),
      };

  /// Renders one part per its `fields` config: `{"type": "number"}` gives a text
  /// input, anything else (Form.io's default) a dropdown.
  Widget _buildPart(_DayPart part) {
    final cfg = _fieldConfig(part);
    final label = _labelOf(part);
    final placeholder = cfg['placeholder']?.toString();
    final hint = (placeholder?.isNotEmpty ?? false) ? placeholder : null;

    if (cfg['type'] == 'number') {
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
    final hasError = _isRequired && (_day == null || _month == null || _year == null);

    // `dayFirst` controls display order only; the stored value stays DD/MM/YYYY.
    // Defaults to day-first, the order this component has always rendered.
    final order = widget.component.raw['dayFirst'] == false
        ? [_DayPart.month, _DayPart.day, _DayPart.year]
        : [_DayPart.day, _DayPart.month, _DayPart.year];
    final visible =
        order.where((p) => _fieldConfig(p)['hide'] != true).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.component.label, style: FormioThemeScope.of(context).resolvedLabelStyle(context)),
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
            child: Text(ComponentFactory.locale.getRequiredMessage(widget.component.label), style: FormioThemeScope.of(context).resolvedErrorStyle(context)),
          ),
      ],
    );
  }
}
