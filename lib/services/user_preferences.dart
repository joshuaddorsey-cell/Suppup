import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PreferenceStore {
  Future<Set<String>> favorites();
  Future<void> setFavorite(String id, {required bool value});
  Future<double?> ratingFor(String id);
  Future<void> setRating(String id, double value);
}

class UserPreferenceStore implements PreferenceStore {
  static const _favoritesKey = 'favorite_spot_ids';
  final Future<SharedPreferences> _preferences =
      SharedPreferences.getInstance();

  @override
  Future<Set<String>> favorites() async {
    final preferences = await _preferences;
    return preferences.getStringList(_favoritesKey)?.toSet() ?? <String>{};
  }

  @override
  Future<void> setFavorite(String id, {required bool value}) async {
    final preferences = await _preferences;
    final values =
        preferences.getStringList(_favoritesKey)?.toSet() ?? <String>{};
    value ? values.add(id) : values.remove(id);
    await preferences.setStringList(_favoritesKey, values.toList()..sort());
  }

  @override
  Future<double?> ratingFor(String id) async {
    final preferences = await _preferences;
    return preferences.getDouble('spot_rating_$id');
  }

  @override
  Future<void> setRating(String id, double value) async {
    final preferences = await _preferences;
    await preferences.setDouble('spot_rating_$id', value);
  }
}
