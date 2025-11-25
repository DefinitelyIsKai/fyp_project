typedef TagSelectionMap = Map<String, List<String>>;

TagSelectionMap parseTagSelection(dynamic data) {
  if (data is! Map) return <String, List<String>>{};

  final result = <String, List<String>>{};
  data.forEach((key, value) {
    if (key is! String) return;
    if (value is! Iterable) return;
    final cleaned = value
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (cleaned.isNotEmpty) {
      cleaned.sort();
      result[key] = cleaned;
    }
  });
  return result;
}

TagSelectionMap sanitizeTagSelection(TagSelectionMap selections) {
  final result = <String, List<String>>{};
  selections.forEach((key, value) {
    final cleaned = value
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (cleaned.isNotEmpty) {
      result[key] = cleaned;
    }
  });
  return result;
}

