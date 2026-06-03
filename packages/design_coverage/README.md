# design_coverage

CLI generator for the tracked design coverage markdown report.

## Setup

Add to `dev_dependencies` in your `pubspec.yaml`:

```yaml
dev_dependencies:
  design_coverage:
    git:
      url: https://github.com/valeriinov/design_coverage.git
      path: packages/design_coverage
      ref: 0.2.1
```

Add `design_coverage_annotation` to `dependencies`:

```yaml
dependencies:
  design_coverage_annotation:
    git:
      url: https://github.com/valeriinov/design_coverage.git
      path: packages/design_coverage_annotation
      ref: 0.2.1
```

## Usage

### 1. Annotate widgets

```dart
import 'package:design_coverage_annotation/design_coverage_annotation.dart';

@DesignComponent(
  name: 'Primary Button',
  category: 'Buttons',
  designUrl: 'https://www.figma.com/file/abc123/buttons?node-id=1-1',
  description: 'Used for the main call-to-action.',
)
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
```

Argument values are resolved as constants, so you can reference shared `const`
strings (for example `category: DesignCategories.buttons`) instead of inline
string literals.

### 2. Generate the report

Run from your project root:

```sh
dart run design_coverage:generate_design_coverage
```

This scans `lib/` and writes the report to `readme/DESIGN_COVERAGE.md`.

### 3. Check in CI

To fail if the report is outdated:

```sh
dart run design_coverage:generate_design_coverage --check
```

## Options

| Option | Default | Description |
| ------ | ------- | ----------- |
| `--source-dir <path>` | `lib` | Directory to scan for annotated widgets |
| `--output <path>` | `readme/DESIGN_COVERAGE.md` | Output file path |
| `--check` | — | Exit with error if output is not up to date |

### Custom paths example

```sh
dart run design_coverage:generate_design_coverage \
  --source-dir lib/ui \
  --output docs/DESIGN_COVERAGE.md
```