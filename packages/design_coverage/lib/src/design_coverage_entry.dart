class DesignCoverageEntry {
  final String category;
  final String className;
  final String designUrl;
  final String sourcePath;
  final String name;
  final String? description;

  const DesignCoverageEntry({
    required this.category,
    required this.className,
    required this.designUrl,
    required this.sourcePath,
    required this.name,
    this.description,
  });

  String get displayName {
    if (name.isEmpty) {
      return className;
    }

    return name;
  }

  String get sourceDocUrl {
    final normalizedSourcePath = sourcePath.replaceAll('\\', '/');

    return '../$normalizedSourcePath';
  }
}
