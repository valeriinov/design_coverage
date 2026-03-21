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
