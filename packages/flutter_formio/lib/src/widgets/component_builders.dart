/// Stateless widget builders for each Form.io component type, used by
/// [EngineFormRenderer]. Each builder reads/writes through a [FieldScope] and
/// returns a widget; layout/array builders recurse via `scope.renderChild`.
///
/// This file was 924 lines holding everything from keyboard mapping to Cupertino
/// date pickers to the data grid. It is now a barrel over `builders/`, split by
/// what a reader is actually looking for. Kept as the entry point so the
/// renderer's `cb.` references and the existing tests are unaffected.
library;

export 'builders/data_grid.dart';
export 'builders/date_controls.dart';
export 'builders/error_messages.dart';
export 'builders/fallback.dart';
export 'builders/field_chrome.dart';
export 'builders/schema_text.dart';
export 'builders/select_controls.dart';
export 'builders/text_leaf.dart';
