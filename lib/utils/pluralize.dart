String pluralize(int number, String one, String few, String many) {
  final n = number.abs() % 100;
  if (n >= 11 && n <= 19) return '$number $many';
  final i = n % 10;
  if (i == 1) return '$number $one';
  if (i >= 2 && i <= 4) return '$number $few';
  return '$number $many';
}