import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:design_coverage/src/annotation_reader.dart';
import 'package:design_coverage/src/design_coverage_entry.dart';
import 'package:path/path.dart' as path;

/// Scans Dart source files and extracts [DesignCoverageEntry] objects
/// from classes annotated with `@DesignComponent`.
class EntryParser {
  static const Set<String> _supportedWidgetBaseTypes = {
    'StatelessWidget',
    'StatefulWidget',
    'HookWidget',
  };

  final AnnotationReader _reader;

  EntryParser({AnnotationReader? reader})
    : _reader = reader ?? const AnnotationReader();

  FileScanResult collectFileEntries({
    required File file,
    required Directory projectRoot,
  }) {
    final entries = <DesignCoverageEntry>[];
    final errors = <String>[];

    final sourcePath = path.relative(file.path, from: projectRoot.path);
    final content = file.readAsStringSync();
    final parseResult = parseString(
      path: file.path,
      content: content,
      throwIfDiagnostics: false,
    );

    for (final declaration
        in parseResult.unit.declarations.whereType<ClassDeclaration>()) {
      final annotation = _findDesignComponentAnnotation(declaration.metadata);

      if (annotation == null) {
        continue;
      }

      final result = _parseEntry(
        annotation: annotation,
        declaration: declaration,
        sourcePath: sourcePath,
        lineInfo: parseResult.lineInfo,
      );

      errors.addAll(result.errors);

      final entry = result.entry;

      if (entry != null) {
        entries.add(entry);
      }
    }

    return FileScanResult(entries: entries, errors: errors);
  }

  Annotation? _findDesignComponentAnnotation(NodeList<Annotation> metadata) {
    for (final annotation in metadata) {
      final annotationName = _resolveLastIdentifierSegment(
        annotation.name.toSource(),
      );

      if (annotationName == 'DesignComponent') {
        return annotation;
      }
    }

    return null;
  }

  ParsedEntry _parseEntry({
    required Annotation annotation,
    required ClassDeclaration declaration,
    required String sourcePath,
    required LineInfo lineInfo,
  }) {
    final location = _buildLocation(
      sourcePath: sourcePath,
      lineInfo: lineInfo,
      offset: declaration.name.offset,
    );
    final className = declaration.name.lexeme;

    if (_isPrivateClass(className)) {
      return ParsedEntry(
        entry: null,
        errors: [
          '$location: `@DesignComponent` can only be used on public classes.',
        ],
      );
    }

    if (_isAbstractClass(declaration)) {
      return ParsedEntry(
        entry: null,
        errors: [
          '$location: `@DesignComponent` can only be used on concrete classes.',
        ],
      );
    }

    final widgetBaseType = _resolveWidgetBaseType(declaration);

    if (widgetBaseType == null) {
      return ParsedEntry(
        entry: null,
        errors: [
          '$location: `$className` must extend '
              'StatelessWidget, StatefulWidget, or HookWidget.',
        ],
      );
    }

    final namedResult = _reader.readNamedArguments(
      annotation: annotation,
      location: location,
    );
    final namedArguments = namedResult.value;

    if (namedArguments == null) {
      final error = namedResult.error;
      return ParsedEntry(entry: null, errors: [if (error != null) error]);
    }

    final categoryResult = _reader.readRequiredStringArgument(
      argumentName: 'category',
      arguments: namedArguments,
      location: location,
    );
    final designUrlResult = _reader.readRequiredDesignUrl(
      arguments: namedArguments,
      location: location,
    );
    final nameResult = _reader.readRequiredStringArgument(
      argumentName: 'name',
      arguments: namedArguments,
      location: location,
    );

    final category = categoryResult.value;
    final designUrl = designUrlResult.value;
    final name = nameResult.value;

    final fieldErrors = [
      for (final error in [
        categoryResult.error,
        designUrlResult.error,
        nameResult.error,
      ])
        if (error != null) error,
    ];

    if (category == null || designUrl == null || name == null) {
      return ParsedEntry(entry: null, errors: fieldErrors);
    }

    final descriptionResult = _reader.readOptionalStringArgument(
      argumentName: 'description',
      arguments: namedArguments,
      location: location,
    );
    final descriptionError = descriptionResult.error;

    if (descriptionError != null) {
      return ParsedEntry(entry: null, errors: [descriptionError]);
    }

    return ParsedEntry(
      entry: DesignCoverageEntry(
        category: category,
        className: className,
        designUrl: designUrl,
        sourcePath: sourcePath,
        name: name,
        description: descriptionResult.value,
      ),
      errors: [],
    );
  }

  String _buildLocation({
    required String sourcePath,
    required LineInfo lineInfo,
    required int offset,
  }) {
    final location = lineInfo.getLocation(offset);

    return '$sourcePath:${location.lineNumber}';
  }

  bool _isPrivateClass(String className) {
    return className.startsWith('_');
  }

  bool _isAbstractClass(ClassDeclaration declaration) {
    return declaration.abstractKeyword != null;
  }

  String? _resolveWidgetBaseType(ClassDeclaration declaration) {
    final extendsClause = declaration.extendsClause;

    if (extendsClause == null) {
      return null;
    }

    final typeName = _resolveLastIdentifierSegment(
      extendsClause.superclass.toSource(),
    );

    if (_supportedWidgetBaseTypes.contains(typeName)) {
      return typeName;
    }

    return null;
  }

  String _resolveLastIdentifierSegment(String value) {
    final dotIndex = value.lastIndexOf('.');

    return dotIndex == -1 ? value : value.substring(dotIndex + 1);
  }
}

/// Holds the entries and parse errors collected from a single source file.
class FileScanResult {
  final List<DesignCoverageEntry> entries;
  final List<String> errors;

  FileScanResult({required this.entries, required this.errors});
}

/// Holds the result of parsing a single class declaration:
/// either a successfully built [entry] or a list of validation [errors].
class ParsedEntry {
  final DesignCoverageEntry? entry;
  final List<String> errors;

  ParsedEntry({required this.entry, required this.errors});
}
