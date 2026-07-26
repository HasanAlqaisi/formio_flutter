/// Entry point for the flutter_formio package.
///
/// Flutter widgets for rendering Form.io forms. Logic (conditionals,
/// calculations, Logic-tab, validation incl. custom JS) is delegated to the
/// real `@formio/core` running headless via [FormLogicEngine]; the UI is
/// rendered by [EngineFormRenderer].
///
/// Example usage:
/// ```dart
/// import 'package:formio/formio.dart';
///
/// final engine = FormLogicEngine();
/// await engine.init();
///
/// EngineFormRenderer(
///   form: myFormJson,
///   engine: engine,
///   onSubmit: (data) => print('Submitted: $data'),
/// );
/// ```

library flutter_formio;

// Form.io API — models, REST client, and core utilities (formerly the
// separate `formio_api` package, now merged in).
export 'src/core/constants.dart';
export 'src/core/exceptions.dart';
export 'src/core/interpolation_utils.dart';
export 'src/core/js_evaluator.dart';
export 'src/core/js_evaluator_interface.dart';
export 'src/core/utils.dart';
export 'src/models/action.dart';
export 'src/models/component.dart';
export 'src/models/file_data.dart';
export 'src/models/form.dart';
export 'src/models/formio_locale_interface.dart';
export 'src/models/role.dart';
export 'src/models/submission.dart';
export 'src/models/user.dart';
export 'src/models/wizard_config.dart';
export 'src/network/api_client.dart';
export 'src/network/endpoints.dart';
export 'src/services/action_service.dart';
export 'src/services/auth_service.dart';
export 'src/services/datasource_service.dart';
export 'src/services/form_service.dart';
export 'src/services/submission_service.dart';
export 'src/services/user_service.dart';

// Core Flutter-specific
export 'src/core/flutter_js_evaluator.dart';
export 'src/core/form_logic_engine.dart';
export 'src/core/validators.dart';
// Models - Flutter-specific
export 'src/models/file_typedefs.dart';
export 'src/models/formio_localizations.dart';
export 'src/models/formio_localizations_ar.dart';
// Widgets
export 'src/widgets/base_component.dart';
export 'src/widgets/component_factory.dart';
export 'src/widgets/engine_form_renderer.dart';

// Stock components used by the ComponentFactory fallback for premium /
// less-common types. Basic inputs and layout are rendered natively by
// EngineFormRenderer and have no stock widget.
export 'src/widgets/components/address_component.dart';
export 'src/widgets/components/alert_component.dart';
export 'src/widgets/components/button_component.dart';
export 'src/widgets/components/captcha_component.dart';
export 'src/widgets/components/content_component.dart';
export 'src/widgets/components/custom_component.dart';
export 'src/widgets/components/data_map_component.dart';
export 'src/widgets/components/datasource_component.dart';
export 'src/widgets/components/datatable_component.dart';
export 'src/widgets/components/day_component.dart';
export 'src/widgets/components/dynamic_wizard_component.dart';
export 'src/widgets/components/file_component.dart';
export 'src/widgets/components/hidden_component.dart';
export 'src/widgets/components/html_element_component.dart';
export 'src/widgets/components/multi_select_field.dart';
export 'src/widgets/components/review_page_component.dart';
export 'src/widgets/components/signature_component.dart';
export 'src/widgets/components/sketchpad_component.dart';
export 'src/widgets/components/survey_component.dart';
export 'src/widgets/components/tagpad_component.dart';
export 'src/widgets/components/tags_component.dart';
export 'src/widgets/components/unknown_component.dart';
