/// Domain-specific (Creatio) components implemented in the *example app*, not
/// the package — demonstrating (and acceptance-testing) the custom-component
/// extension API. Register these on the renderer via `customComponents:`.
///
/// Each builder receives a [FormioFieldContext]: value in via `ctx.value`,
/// value out via `ctx.setValue`, optional stock chrome via `ctx.chrome`, and
/// delegation to a built-in via `ctx.builtin`.
library;

import 'package:flutter/material.dart';
import 'package:formio/formio.dart';

/// The map you pass to `EngineFormRenderer(customComponents: creatioComponents)`.
final Map<String, FormioFieldBuilder> creatioComponents = {
  // `sites` behaves exactly like a select — alias it to the built-in.
  'sites': (FormioFieldContext ctx) => ctx.builtin('select'),
  // Brand-new domain types provided entirely by the host app.
  'fmsfile': (FormioFieldContext ctx) => FmsFileField(ctx),
  'location': (FormioFieldContext ctx) => LocationField(ctx),
};

/// Custom file-upload field. Value is a list of attachment ids stored in the
/// submission; a real app would pick a file and upload it to the FMS backend.
class FmsFileField extends StatelessWidget {
  const FmsFileField(this.ctx, {super.key});
  final FormioFieldContext ctx;

  @override
  Widget build(BuildContext context) {
    final ids = (ctx.value as List?) ?? const [];
    return ctx.chrome(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final id in ids)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attachment),
              title: Text(id.toString()),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => ctx.setValue([...ids]..remove(id)),
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
              // Real app: pick file → upload to FMS storage → store the id.
              onPressed: () => ctx.setValue([...ids, 'att_${ids.length + 1}']),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom coordinate field. Value is a `{lat, lng}` map. Demonstrates a
/// composite custom that owns local controllers and pushes to the engine.
class LocationField extends StatefulWidget {
  const LocationField(this.ctx, {super.key});
  final FormioFieldContext ctx;

  @override
  State<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<LocationField> {
  late final TextEditingController _lat;
  late final TextEditingController _lng;

  @override
  void initState() {
    super.initState();
    final v = widget.ctx.value;
    final map = v is Map ? v : const {};
    _lat = TextEditingController(text: map['lat']?.toString() ?? '');
    _lng = TextEditingController(text: map['lng']?.toString() ?? '');
  }

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _push() => widget.ctx.setValue({
        'lat': num.tryParse(_lat.text) ?? _lat.text,
        'lng': num.tryParse(_lng.text) ?? _lng.text,
      });

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        );
    return widget.ctx.chrome(
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _lat,
              decoration: deco('Lat'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _push(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _lng,
              decoration: deco('Lng'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _push(),
            ),
          ),
        ],
      ),
    );
  }
}
