extension StringExtensions on String {
  String toSentenceCase() {
    if (isEmpty) return this;

    // Add a space before each uppercase letter and convert to lowercase
    String result = replaceAllMapped(RegExp(r'[A-Z]'), (match) {
      return ' ${match.group(0)}'.toLowerCase();
    });

    // Capitalize the first letter
    result = result[0].toUpperCase() + result.substring(1);

    return result;
  }
}
