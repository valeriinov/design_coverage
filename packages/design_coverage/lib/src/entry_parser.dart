import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:design_coverage/src/annotation_reader.dart';
import 'package:design_coverage/src/design_coverage_entry.dart';
import 'package:path/path.dart' as path;

/// Scans Dart source files and extracts [DesignCoverageEntry] objects
/// from classes annotated with `@DesignComponent`.
class EntryParser {
  static const String _annotationName = 'DesignComponent';

  static const Set<String> _supportedWidgetBaseTypes = {
    'StatelessWidget',
    'StatefulWidget',
    'HookWidget',
  };

  final AnnotationReader _reader;

  EntryParser({AnnotationReader? reader})
    : _reader = reader ?? const AnnotationReader();

  Future<FileScanResult> collectFileEntries({
    required File file,
    required Directory projectRoot,
    required AnalysisContextCollection analysisContextCollection,
  }) async {
    if (!_mayContainAnnotation(file)) {
      return FileScanResult(entries: [], errors: []);
    }

    final canonicalFilePath = file.resolveSymbolicLinksSync();
    final sourcePath = path.relative(
      canonicalFilePath,
      from: projectRoot.resolveSymbolicLinksSync(),
    );
    final result = await analysisContextCollection
        .contextFor(canonicalFilePath)
        .currentSession
        .getResolvedUnit(canonicalFilePath);

    if (result is! ResolvedUnitResult || !result.exists) {
      return FileScanResult(
        entries: [],
        errors: ['$sourcePath: Could not resolve Dart source file.'],
      );
    }

    return _collectResolvedUnitEntries(
      sourcePath: sourcePath,
      resolvedUnitResult: result,
    );
  }

  bool _mayContainAnnotation(File file) {
    return file.readAsStringSync().contains(_annotationName);
  }

  FileScanResult _collectResolvedUnitEntries({
    required String sourcePath,
    required ResolvedUnitResult resolvedUnitResult,
  }) {
    final entries = <DesignCoverageEntry>[];
    final errors = <String>[];

    for (final declaration
        in resolvedUnitResult.unit.declarations.whereType<ClassDeclaration>()) {
      final annotation = _findDesignComponentAnnotation(declaration.metadata);

      if (annotation == null) {
        continue;
      }

      final result = _parseEntry(
        annotation: annotation,
        declaration: declaration,
        sourcePath: sourcePath,
        lineInfo: resolvedUnitResult.lineInfo,
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

      if (annotationName == _annotationName) {
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
    // analyzer 10.2 deprecates the `name` token in favour of `namePart`, but
    // `namePart` is absent in earlier 10.x; keep the token for 10.x compatibility.
    // ignore: deprecated_member_use
    final nameToken = declaration.name;
    final location = _buildLocation(
      sourcePath: sourcePath,
      lineInfo: lineInfo,
      offset: nameToken.offset,
    );
    final className = nameToken.lexeme;

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

    final constant = annotation.elementAnnotation?.computeConstantValue();

    if (constant == null) {
      return ParsedEntry(
        entry: null,
        errors: ['$location: `@DesignComponent` must be a valid constant.'],
      );
    }

    final categoryResult = _reader.readRequiredString(
      constant: constant,
      fieldName: 'category',
      location: location,
    );
    final designUrlResult = _reader.readRequiredDesignUrl(
      constant: constant,
      location: location,
    );
    final nameResult = _reader.readRequiredString(
      constant: constant,
      fieldName: 'name',
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

    final descriptionResult = _reader.readOptionalString(
      constant: constant,
      fieldName: 'description',
      location: location,
    );

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
