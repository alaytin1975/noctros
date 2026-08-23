/// Canonical product and wake-word identifiers for Noctros.
abstract final class NoctrosConstants {
  static const appName = 'Noctros';
  static const appVersion = '0.9.0';
  static const appBuild = '16';
  static const defaultWakeWords = ['Noctros', 'Hey Noctros'];
  static const emergencyPhrases = [
    'help',
    'emergency',
    'i fell',
    'call 112',
    'save me',
  ];
  static const databaseName = 'noctros.db';
  static const secureStorageNamespace = 'noctros_secure';
}
