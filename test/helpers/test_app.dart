import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_mind/app/app.dart';
import 'package:receipt_mind/core/db/app_database.dart';
import 'package:receipt_mind/core/db/db_providers.dart';
import 'package:receipt_mind/core/settings/settings_providers.dart';
import 'package:receipt_mind/core/settings/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A fresh in-memory database (runs onCreate, so default categories exist).
AppDatabase inMemoryDatabase() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

/// SharedPreferences backed by memory, optionally pre-filled.
Future<SharedPreferencesWithCache> inMemoryPrefs([
  Map<String, Object> values = const {},
]) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(values);
  return SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: SettingsRepository.allKeys,
    ),
  );
}

/// The real app with test doubles for storage and a fixed device locale.
Widget testApp({
  required SharedPreferencesWithCache prefs,
  required AppDatabase db,
  String locale = 'en_US',
}) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    deviceLocaleProvider.overrideWithValue(locale),
    appDatabaseProvider.overrideWithValue(db),
  ],
  child: const ReceiptMindApp(),
);
