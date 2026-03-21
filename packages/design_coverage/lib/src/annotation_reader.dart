import 'package:analyzer/dart/ast/ast.dart';

/// Extracts typed argument values from `@DesignComponent` annotation AST nodes.
class AnnotationReader {
  const AnnotationReader();

  ReadResult<Map<String, Expression>> readNamedArguments({
    required Annotation annotation,
    required String location,
  }) {
    final arguments = annotation.arguments?.arguments;

    if (arguments == null || arguments.isEmpty) {
      return ReadResult(
        error: '$location: `@DesignComponent` must use named arguments.',
      );
    }

    final namedArguments = <String, Expression>{};

    for (final argument in arguments) {
      if (argument is! NamedExpression) {
        return ReadResult(
          error: '$location: `@DesignComponent` only supports named arguments.',
        );
      }

      namedArguments[argument.name.label.name] = argument.expression;
    }

    return ReadResult(value: namedArguments);
  }

  ReadResult<String> readRequiredDesignUrl({
    required Map<String, Expression> arguments,
    required String location,
  }) {
    final strResult = readRequiredStringArgument(
      argumentName: 'designUrl',
      arguments: arguments,
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
    required Map<String, Expression> arguments,
    required String location,
  }) {
    final optResult = readOptionalStringArgument(
      argumentName: argumentName,
      arguments: arguments,
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
    required Map<String, Expression> arguments,
    required String location,
  }) {
    final expression = arguments[argumentName];

    if (expression == null || expression is NullLiteral) {
      return const ReadResult();
    }

    if (expression is! StringLiteral) {
      return ReadResult(
        error: '$location: `$argumentName` must be a string literal.',
      );
    }

    final value = expression.stringValue?.trim();

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
