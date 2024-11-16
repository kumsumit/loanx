int damerauLevenshteinDistance(String firstString, String secondString) {
  int len1 = firstString.length;
  int len2 = secondString.length;
  List<int> prev = List.filled(len2 + 1, 0);
  List<int> curr = List.filled(len2 + 1, 0);

  for (int j = 0; j <= len2; j++) {
    prev[j] = j;
  }

  for (int i = 1; i <= len1; i++) {
    curr[0] = i;
    for (int j = 1; j <= len2; j++) {
      int cost = firstString[i - 1] != secondString[j - 1] ? 1 : 0;

      curr[j] = [
        prev[j] + 1, // Deletion
        curr[j - 1] + 1, // Insertion
        prev[j - 1] + cost // Substitution
      ].reduce((a, b) => a < b ? a : b);

      if (i > 1 &&
          j > 1 &&
          firstString[i - 1] == secondString[j - 2] &&
          firstString[i - 2] == secondString[j - 1]) {
        // Transposition
        curr[j] = [curr[j], prev[j - 2] + cost].reduce((a, b) => a < b ? a : b);
      }
    }
    List<int> temp = prev;
    prev = curr;
    curr = temp;
  }

  return prev[len2];
}
