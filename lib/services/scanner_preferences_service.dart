import 'package:shared_preferences/shared_preferences.dart';
import '../scanner/models/scanner_mode.dart';

/// Persiste la preferencia de modo de escaneo del usuario.
class ScannerPreferencesService {
  static const _keyLastMode = 'scanner_last_mode';

  static Future<ScannerMode?> getLastMode() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyLastMode);
    if (name == null) return null;
    return ScannerMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ScannerMode.manual,
    );
  }

  static Future<void> setLastMode(ScannerMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastMode, mode.name);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastMode);
  }
}
