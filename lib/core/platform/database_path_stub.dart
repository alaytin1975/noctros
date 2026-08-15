Future<String> resolveNoctrosDatabasePath({
  required String? overridePath,
  required String databaseName,
}) async {
  return overridePath ?? databaseName;
}
