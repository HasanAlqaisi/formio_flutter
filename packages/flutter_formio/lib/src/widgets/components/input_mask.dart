/// Applies Form.io's `inputMask` to a text field as the user types.
///
/// The mask matters beyond looks: `@formio/core` validates the value against it
/// and raises a `mask` error, so an unmasked phone number is *rejected*, not
/// merely unformatted.
///
/// Mask characters follow Form.io's documented convention:
///
/// | char | accepts        |
/// |------|----------------|
/// | `9`  | a digit        |
/// | `a`  | a letter       |
/// | `*`  | either         |
///
/// Everything else is a literal and is inserted automatically, so `(999)
/// 999-9999` turns `5551234567` into `(555) 123-4567`.
library;

import 'package:flutter/services.dart';

class MaskedInputFormatter extends TextInputFormatter {
  const MaskedInputFormatter(this.mask);

  final String mask;

  static bool _isDigit(String c) {
    final code = c.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  static bool _isLetter(String c) {
    final code = c.codeUnitAt(0) | 0x20; // fold case
    return code >= 0x61 && code <= 0x7a;
  }

  static bool _isPayload(String c) => _isDigit(c) || _isLetter(c);

  /// Whether [c] can fill the mask slot [slot].
  static bool _fits(String slot, String c) => switch (slot) {
        '9' => _isDigit(c),
        'a' => _isLetter(c),
        '*' => _isPayload(c),
        _ => false,
      };

  static bool _isSlot(String c) => c == '9' || c == 'a' || c == '*';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (mask.isEmpty) return newValue;

    final typed = newValue.text;
    // Only the characters that can fill slots survive; the mask re-inserts its
    // own literals, so keeping the old ones would duplicate them.
    final payload = typed.split('').where(_isPayload).toList();
    if (payload.isEmpty) return const TextEditingValue();

    // Payload before the caret, used to restore it afterwards.
    final caret = newValue.selection.baseOffset.clamp(0, typed.length);
    final payloadBeforeCaret =
        typed.substring(0, caret).split('').where(_isPayload).length;

    final out = StringBuffer();
    var consumed = 0;
    var placed = 0;
    var caretOffset = 0;
    var caretFound = payloadBeforeCaret == 0;

    for (final slot in mask.split('')) {
      if (consumed >= payload.length) break;
      if (_isSlot(slot)) {
        final char = payload[consumed];
        consumed++;
        // A character of the wrong kind for this slot is dropped rather than
        // shifting everything out of alignment.
        if (!_fits(slot, char)) continue;
        out.write(char);
        placed++;
        if (!caretFound && placed == payloadBeforeCaret) {
          caretOffset = out.length;
          caretFound = true;
        }
      } else {
        out.write(slot);
      }
    }

    final text = out.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: caretFound ? caretOffset.clamp(0, text.length) : text.length,
      ),
      composing: TextRange.empty,
    );
  }
}
