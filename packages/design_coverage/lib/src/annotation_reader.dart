import 'package:analyzer/dart/constant/value.dart';

/// Extracts typed field values from a resolved `@DesignComponent` constant.
class AnnotationReader {
  const AnnotationReader();

  ReadResult<String> readRequiredString({
    required DartObject constant,
    required String fieldName,
    required String location,
  }) {
    final optResult = readOptionalString(
      constant: constant,
      fieldName: fieldName,
      location: location,
    );

    final value = optResult.value;

    if (value != null) {
      return ReadResult(value: value);
    }

    return ReadResult(
      error: '$location: `$fieldName` must be a non-empty string.',
    );
  }

  ReadResult<String> readRequiredDesignUrl({
    required DartObject constant,
    required String location,
  }) {
    final strResult = readRequiredString(
      constant: constant,
      fieldName: 'designUrl',
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

  ReadResult<String> readOptionalString({
    required DartObject constant,
    required String fieldName,
    required String location,
  }) {
    final field = constant.getField(fieldName);

    if (field == null || field.isNull) {
      return const ReadResult();
    }

    final value = field.toStringValue()?.trim();

    if (value == null || value.isEmpty) {
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
