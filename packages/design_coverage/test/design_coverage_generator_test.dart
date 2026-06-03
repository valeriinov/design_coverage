import 'dart:io';

import 'package:design_coverage/design_coverage.dart';
import 'package:test/test.dart';

late Directory _projectRoot;

void main() {
  _setup();

  group('DesignCoverageGenerator Tests', () {
    _designCoverageGenerator_should_resolve_string_constants_in_arguments();
    _designCoverageGenerator_should_render_string_literal_arguments();
    _designCoverageGenerator_should_render_description_in_notes();
    _designCoverageGenerator_should_sort_entries_across_categories();
    _designCoverageGenerator_should_fail_when_design_url_is_invalid();
    _designCoverageGenerator_should_fail_when_required_argument_is_empty();
    _designCoverageGenerator_should_fail_when_class_is_private();
    _designCoverageGenerator_should_fail_when_class_is_abstract();
    _designCoverageGenerator_should_fail_when_class_is_not_a_widget();
  });

  group('DesignCoverageGenerator isUpToDate Tests', () {
    _isUpToDate_should_return_true_when_output_matches();
    _isUpToDate_should_return_false_when_output_differs();
    _isUpToDate_should_return_false_when_output_is_missing();
  });
}

void _setup() {
  setUp(() {
    _projectRoot = Directory.systemTemp.createTempSync('design_coverage_test_');
  });

  tearDown(() {
    _projectRoot.deleteSync(recursive: true);
  });
}

void _designCoverageGenerator_should_resolve_string_constants_in_arguments() {
  test(
    'DesignCoverageGenerator should resolve string constants in arguments',
    () async {
      _writeAnnotationLib();
      _writeProjectFile('lib/categories.dart', '''
class DesignComponentCategories {
  static const String buttons = 'Buttons';
}
''');
      _writeComponent('button.dart', '''
import 'categories.dart';

@DesignComponent(
  name: 'Primary Button',
  category: DesignComponentCategories.buttons,
  designUrl: 'https://example.com/buttons/primary',
)
class PrimaryButton extends StatelessWidget {
  const PrimaryButton();
}
''');

      final content = await DesignCoverageGenerator().generate(_projectRoot);

      expect(content, contains('## Buttons'));
      expect(content, contains('| Primary Button |'));
      expect(content, isNot(contains('DesignComponentCategories.buttons')));
    },
  );
}

void _designCoverageGenerator_should_render_string_literal_arguments() {
  test(
    'DesignCoverageGenerator should render string literal arguments',
    () async {
      _writeAnnotationLib();
      _writeComponent('button.dart', _validButtonSource);

      final content = await DesignCoverageGenerator().generate(_projectRoot);

      expect(content, contains('## Buttons'));
      expect(content, contains('| Primary Button |'));
    },
  );
}

void _designCoverageGenerator_should_render_description_in_notes() {
  test('DesignCoverageGenerator should render description in notes', () async {
    _writeAnnotationLib();
    _writeComponent('button.dart', '''
@DesignComponent(
  name: 'Primary Button',
  category: 'Buttons',
  designUrl: 'https://example.com/buttons/primary',
  description: 'Main call to action.',
)
class PrimaryButton extends StatelessWidget {
  const PrimaryButton();
}
''');

    final content = await DesignCoverageGenerator().generate(_projectRoot);

    expect(content, contains('Main call to action.'));
  });
}

void _designCoverageGenerator_should_sort_entries_across_categories() {
  test(
    'DesignCoverageGenerator should sort entries across categories',
    () async {
      _writeAnnotationLib();
      _writeComponent('zebra.dart', '''
@DesignComponent(
  name: 'Zebra Widget',
  category: 'Zebra',
  designUrl: 'https://example.com/zebra',
)
class ZebraWidget extends StatelessWidget {
  const ZebraWidget();
}
''');
      _writeComponent('alpha.dart', '''
@DesignComponent(
  name: 'Alpha Widget',
  category: 'Alpha',
  designUrl: 'https://example.com/alpha',
)
class AlphaWidget extends StatelessWidget {
  const AlphaWidget();
}
''');

      final content = await DesignCoverageGenerator().generate(_projectRoot);

      expect(content, contains('## Alpha'));
      expect(content, contains('## Zebra'));
      expect(
        content.indexOf('## Alpha'),
        lessThan(content.indexOf('## Zebra')),
      );
    },
  );
}

void _designCoverageGenerator_should_fail_when_design_url_is_invalid() {
  test(
    'DesignCoverageGenerator should fail when design url is invalid',
    () async {
      _writeAnnotationLib();
      _writeComponent('button.dart', '''
@DesignComponent(
  name: 'Primary Button',
  category: 'Buttons',
  designUrl: 'not-a-valid-url',
)
class PrimaryButton extends StatelessWidget {
  const PrimaryButton();
}
''');

      final generation = DesignCoverageGenerator().generate(_projectRoot);

      await expectLater(
        generation,
        throwsA(_stateErrorWithMessage(contains('designUrl'))),
      );
    },
  );
}

void _designCoverageGenerator_should_fail_when_required_argument_is_empty() {
  test(
    'DesignCoverageGenerator should fail when required argument is empty',
    () async {
      _writeAnnotationLib();
      _writeComponent('button.dart', '''
@DesignComponent(
  name: '',
  category: 'Buttons',
  designUrl: 'https://example.com/buttons/primary',
)
class PrimaryButton extends StatelessWidget {
  const PrimaryButton();
}
''');

      final generation = DesignCoverageGenerator().generate(_projectRoot);

      await expectLater(
        generation,
        throwsA(_stateErrorWithMessage(contains('must be a non-empty string'))),
      );
    },
  );
}

void _designCoverageGenerator_should_fail_when_class_is_private() {
  test('DesignCoverageGenerator should fail when class is private', () async {
    _writeAnnotationLib();
    _writeComponent('button.dart', '''
@DesignComponent(
  name: 'Primary Button',
  category: 'Buttons',
  designUrl: 'https://example.com/buttons/primary',
)
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton();
}
''');

    final generation = DesignCoverageGenerator().generate(_projectRoot);

    await expectLater(
      generation,
      throwsA(_stateErrorWithMessage(contains('public classes'))),
    );
  });
}

void _designCoverageGenerator_should_fail_when_class_is_abstract() {
  test('DesignCoverageGenerator should fail when class is abstract', () async {
    _writeAnnotationLib();
    _writeComponent('button.dart', '''
@DesignComponent(
  name: 'Primary Button',
  category: 'Buttons',
  designUrl: 'https://example.com/buttons/primary',
)
abstract class PrimaryButton extends StatelessWidget {}
''');

    final generation = DesignCoverageGenerator().generate(_projectRoot);

    await expectLater(
      generation,
      throwsA(_stateErrorWithMessage(contains('concrete classes'))),
    );
  });
}

void _designCoverageGenerator_should_fail_when_class_is_not_a_widget() {
  test(
    'DesignCoverageGenerator should fail when class is not a widget',
    () async {
      _writeAnnotationLib();
      _writeComponent('button.dart', '''
@DesignComponent(
  name: 'Primary Button',
  category: 'Buttons',
  designUrl: 'https://example.com/buttons/primary',
)
class PrimaryButton {
  const PrimaryButton();
}
''');

      final generation = DesignCoverageGenerator().generate(_projectRoot);

      await expectLater(
        generation,
        throwsA(_stateErrorWithMessage(contains('must extend'))),
      );
    },
  );
}

void _isUpToDate_should_return_true_when_output_matches() {
  test('isUpToDate should return true when output matches', () async {
    _writeAnnotationLib();
    _writeComponent('button.dart', _validButtonSource);
    final generator = DesignCoverageGenerator();
    await generator.write(_projectRoot);

    final result = await generator.isUpToDate(_projectRoot);

    expect(result, isTrue);
  });
}

void _isUpToDate_should_return_false_when_output_differs() {
  test('isUpToDate should return false when output differs', () async {
    _writeAnnotationLib();
    _writeComponent('button.dart', _validButtonSource);
    final generator = DesignCoverageGenerator();
    await generator.write(_projectRoot);
    _appendToOutput('\nManual edit.');

    final result = await generator.isUpToDate(_projectRoot);

    expect(result, isFalse);
  });
}

void _isUpToDate_should_return_false_when_output_is_missing() {
  test('isUpToDate should return false when output is missing', () async {
    _writeAnnotationLib();
    _writeComponent('button.dart', _validButtonSource);

    final result = await DesignCoverageGenerator().isUpToDate(_projectRoot);

    expect(result, isFalse);
  });
}

Matcher _stateErrorWithMessage(Matcher messageMatcher) {
  return isA<StateError>().having(
    (error) => error.message,
    'message',
    messageMatcher,
  );
}

void _writeAnnotationLib() {
  _writeProjectFile('lib/design_component.dart', '''
class DesignComponent {
  final String name;
  final String category;
  final String designUrl;
  final String? description;

  const DesignComponent({
    required this.name,
    required this.category,
    required this.designUrl,
    this.description,
  });
}

class StatelessWidget {
  const StatelessWidget();
}

class StatefulWidget {
  const StatefulWidget();
}

class HookWidget {
  const HookWidget();
}
''');
}

void _writeComponent(String fileName, String source) {
  _writeProjectFile(
    'lib/$fileName',
    "import 'design_component.dart';\n$source",
  );
}

void _writeProjectFile(String relativePath, String text) {
  final file = File('${_projectRoot.path}/$relativePath');

  file.parent.createSync(recursive: true);
  file.writeAsStringSync(text);
}

void _appendToOutput(String text) {
  final file = File(
    '${_projectRoot.path}/${DesignCoverageGenerator.defaultOutputFilePath}',
  );

  file.writeAsStringSync('${file.readAsStringSync()}$text');
}

const String _validButtonSource = '''
@DesignComponent(
  name: 'Primary Button',
  category: 'Buttons',
  designUrl: 'https://example.com/buttons/primary',
)
class PrimaryButton extends StatelessWidget {
  const PrimaryButton();
}
''';
