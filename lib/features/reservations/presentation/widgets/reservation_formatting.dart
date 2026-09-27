String displayOrDash(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? '-' : normalized;
}

String dateOnly(String value) {
  return value.length >= 10 ? value.substring(0, 10) : value;
}
