import 'dart:io';

import 'package:design_coverage/src/design_coverage_entry.dart';
import 'package:design_coverage/src/design_coverage_markdown_renderer.dart';
import 'package:design_coverage/src/entry_parser.dart';
import 'package:path/path.dart' as path;

/// Orchestrates design coverage generation: discovers annotated widgets,
/// renders the markdown report, and writes or validates the output file.
class DesignCoverageGenerator {
  static const String defaultOutputFilePath = 'readme/DESIGN_COVERAGE.md';
  static const String defaultSourceDirectoryPath = 'lib';

  static const Set<String> _generatedFileSuffixes = {
    '.freezed.dart',
    '.g.dart',
    '.gr.dart',
    '.names.dart',
    '.tailor.dart',
  };

  final DesignCoverageMarkdownRenderer _renderer;
  final EntryParser _parser;

  DesignCoverageGenerator({
    DesignCoverageMarkdownRenderer? renderer,
    EntryParser? parser,
  }) : _renderer = renderer ?? const DesignCoverageMarkdownRenderer(),
       _parser = parser ?? EntryParser();

  bool isUpToDate(
    Directory projectRoot, {
    String sourceDirectoryPath = defaultSourceDirectoryPath,
    String outputFilePath = defaultOutputFilePath,
  }) {
    final outputFile = _resolveOutputFile(
      projectRoot,
      outputFilePath: outputFilePath,
    );

    if (!outputFile.existsSync()) {
      return false;
    }

    final currentContent = outputFile.readAsStringSync();
    final expectedContent = generate(
      projectRoot,
      sourceDirectoryPath: sourceDirectoryPath,
    );

    return currentContent == expectedContent;
  }

  String generate(
    Directory projectRoot, {
    String sourceDirectoryPath = defaultSourceDirectoryPath,
  }) {
    final entries = _collectEntries(
      projectRoot,
      sourceDirectoryPath: sourceDirectoryPath,
    );

    return _renderer.render(entries);
  }

  void write(
    Directory projectRoot, {
    String sourceDirectoryPath = defaultSourceDirectoryPath,
    String outputFilePath = defaultOutputFilePath,
  }) {
    final content = generate(
      projectRoot,
      sourceDirectoryPath: sourceDirectoryPath,
    );
    final outputFile = _resolveOutputFile(
      projectRoot,
      outputFilePath: outputFilePath,
    );

    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(content);
  }

  List<DesignCoverageEntry> _collectEntries(
    Directory projectRoot, {
    required String sourceDirectoryPath,
  }) {
    final entries = <DesignCoverageEntry>[];
    final errors = <String>[];

    for (final file in _findSourceFiles(
      projectRoot,
      sourceDirectoryPath: sourceDirectoryPath,
    )) {
      final result = _parser.collectFileEntries(
        file: file,
        projectRoot: projectRoot,
      );

      entries.addAll(result.entries);
      errors.addAll(result.errors);
    }

    if (errors.isNotEmpty) {
      throw StateError(errors.join('\n'));
    }

    entries.sort(_compareEntries);

    return entries;
  }

  List<File> _findSourceFiles(
    Directory projectRoot, {
    required String sourceDirectoryPath,
  }) {
    final sourceDirectory = Directory(
      path.join(projectRoot.path, sourceDirectoryPath),
    );

    if (!sourceDirectory.existsSync()) {
      throw StateError(
        'Source directory `$sourceDirectoryPath` does not exist.',
      );
    }

    final files = sourceDirectory
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where(_isSupportedSourceFile)
        .toList();

    files.sort((first, second) => first.path.compareTo(second.path));

    return files;
  }

  bool _isSupportedSourceFile(File file) {
    final filePath = file.path;

    if (!filePath.endsWith('.dart')) {
      return false;
    }

    return !_generatedFileSuffixes.any(filePath.endsWith);
  }

  int _compareEntries(DesignCoverageEntry first, DesignCoverageEntry second) {
    final categoryComparison = first.category.compareTo(second.category);

    if (categoryComparison != 0) {
      return categoryComparison;
    }

    final nameComparison = first.displayName.compareTo(second.displayName);

    if (nameComparison != 0) {
      return nameComparison;
    }

    return first.className.compareTo(second.className);
  }

  File _resolveOutputFile(
    Directory projectRoot, {
    required String outputFilePath,
  }) {
    return File(path.join(projectRoot.path, outputFilePath));
  }
}
