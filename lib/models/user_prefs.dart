import 'package:shared_preferences/shared_preferences.dart';

class UserPrefs {
  static const _keyName = 'user_name';
  static const _keyEmail = 'user_email';
  static const _keyPhone = 'user_phone';
  static const _keyAge = 'user_age';
  static const _keyGender = 'user_gender';

  static Future<void> saveUser({
    required String name,
    required String email,
    String phone = '',
    String age = '',
    String gender = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    await prefs.setString(_keyEmail, email);
    if (phone.isNotEmpty) await prefs.setString(_keyPhone, phone);
    if (age.isNotEmpty) await prefs.setString(_keyAge, age);
    if (gender.isNotEmpty) await prefs.setString(_keyGender, gender);
  }

  static Future<Map<String, String>> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_keyName) ?? '',
      'email': prefs.getString(_keyEmail) ?? '',
      'phone': prefs.getString(_keyPhone) ?? '',
      'age': prefs.getString(_keyAge) ?? '',
      'gender': prefs.getString(_keyGender) ?? '',
    };
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
