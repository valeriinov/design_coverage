import 'package:analyzer/dart/constant/value.dart';

/// Extracts typed argument values from `@DesignComponent` annotation values.
class AnnotationReader {
  const AnnotationReader();

  ReadResult<String> readRequiredDesignUrl({
    required DartObject annotationValue,
    required String location,
  }) {
    final strResult = readRequiredStringArgument(
      argumentName: 'designUrl',
      annotationValue: annotationValue,
      location: location,
    );

    final designUrl = strResult.value;

    if (designUrl == null) {
      return ReadResult(error: strResult.error);
    }

    final uri = Uri.tryParse(designUrl);
    final isValid = uri != null && uri.hasScheme && uri.hasAuthority;

    if (isValid) {
      return ReadResult(value: designUrl);
    }

    return ReadResult(
      error: '$location: `designUrl` must be a valid absolute URL.',
    );
  }

  ReadResult<String> readRequiredStringArgument({
    required String argumentName,
    required DartObject annotationValue,
    required String location,
  }) {
    final optResult = readOptionalStringArgument(
      argumentName: argumentName,
      annotationValue: annotationValue,
      location: location,
    );

    final value = optResult.value;

    if (value != null) {
      return ReadResult(value: value);
    }

    final error = optResult.error;

    if (error != null) {
      return ReadResult(error: error);
    }

    return ReadResult(
      error: '$location: `$argumentName` must be a non-empty string.',
    );
  }

  ReadResult<String> readOptionalStringArgument({
    required String argumentName,
    required DartObject annotationValue,
    required String location,
  }) {
    final fieldValue = annotationValue.getField(argumentName);

    if (fieldValue == null || fieldValue.isNull) {
      return const ReadResult();
    }

    final value = fieldValue.toStringValue()?.trim();

    if (value == null) {
      return ReadResult(
        error: '$location: `$argumentName` must resolve to a string.',
      );
    }

    if (value.isEmpty) {
      return const ReadResult();
    }

    return ReadResult(value: value);
  }
}

/// Holds the outcome of a single read operation: either a [value] or an [error] message.
class ReadResult<T> {
  final T? value;
  final String? error;

  const ReadResult({this.value, this.error});
}
