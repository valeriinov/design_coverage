import 'dart:io';

import 'package:design_coverage/design_coverage.dart';

void main(List<String> arguments) {
  final options = _CommandOptions.parse(arguments);
  final generator = DesignCoverageGenerator();

  if (options.isCheckMode) {
    _runCheck(generator, options);
    return;
  }

  _runGeneration(generator, options);
}

void _runCheck(DesignCoverageGenerator generator, _CommandOptions options) {
  final projectRoot = Directory.current;
  bool isUpToDate = false;

  try {
    isUpToDate = generator.isUpToDate(
      projectRoot,
      sourceDirectoryPath: options.sourceDirectoryPath,
      outputFilePath: options.outputFilePath,
    );
  } on Object catch (error) {
    _fail(error.toString());
  }

  if (isUpToDate) {
    stdout.writeln('Design coverage is up to date.');
    return;
  }

  _fail(
    'Design coverage is outdated.'
    '\nRun `dart run design_coverage:generate_design_coverage`'
    '\nto regenerate `${options.outputFilePath}`.',
  );
}

void _runGeneration(
  DesignCoverageGenerator generator,
  _CommandOptions options,
) {
  final projectRoot = Directory.current;

  try {
    generator.write(
      projectRoot,
      sourceDirectoryPath: options.sourceDirectoryPath,
      outputFilePath: options.outputFilePath,
    );
  } on Object catch (error) {
    _fail(error.toString());
  }

  stdout.writeln('Generated `${options.outputFilePath}`.');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

class _CommandOptions {
  final bool isCheckMode;
  final String sourceDirectoryPath;
  final String outputFilePath;

  const _CommandOptions({
    required this.isCheckMode,
    required this.sourceDirectoryPath,
    required this.outputFilePath,
  });

  factory _CommandOptions.parse(List<String> arguments) {
    bool isCheckMode = false;
    String sourceDirectoryPath =
        DesignCoverageGenerator.defaultSourceDirectoryPath;
    String outputFilePath = DesignCoverageGenerator.defaultOutputFilePath;

    int index = 0;

    while (index < arguments.length) {
      final argument = arguments[index];

      if (argument == '--check') {
        isCheckMode = true;
        index++;
        continue;
      }

      if (argument == '--source-dir') {
        sourceDirectoryPath = _readOptionValue(
          arguments: arguments,
          optionName: argument,
          optionIndex: index,
        );
        index += 2;
        continue;
      }

      if (argument == '--output') {
        outputFilePath = _readOptionValue(
          arguments: arguments,
          optionName: argument,
          optionIndex: index,
        );
        index += 2;
        continue;
      }

      _fail(
        'Unknown argument: $argument.'
        '\nSupported arguments: --check, --source-dir <path>, --output <path>',
      );
    }

    return _CommandOptions(
      isCheckMode: isCheckMode,
      sourceDirectoryPath: sourceDirectoryPath,
      outputFilePath: outputFilePath,
    );
  }

  static String _readOptionValue({
    required List<String> arguments,
    required String optionName,
    required int optionIndex,
  }) {
    final valueIndex = optionIndex + 1;

    if (valueIndex >= arguments.length) {
      _fail('Missing value for `$optionName`.');
    }

    final value = arguments[valueIndex].trim();

    if (value.isEmpty) {
      _fail('Missing value for `$optionName`.');
    }

    return value;
  }
}
