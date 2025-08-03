import 'package:GitSync/constant/strings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum StorageKey<T> {
  // Repo Manager
  repoman_appLocale<String?>(name: "appLocale", defaultValue: null),
  repoman_hasGHSponsorPremium<bool>(name: "hasGHSponsorPremium", defaultValue: false),
  repoman_repoIndex<int>(name: "repoIndex", defaultValue: 0),
  repoman_tileSyncIndex<int>(name: "tileSyncIndex", defaultValue: 0),
  repoman_tileManualSyncIndex<int>(name: "tileManualSyncIndex", defaultValue: 0),
  repoman_onboardingStep<int>(name: "onboardingStep", defaultValue: 0),
  repoman_erroring<String?>(name: "erroring", defaultValue: null),
  repoman_ghSponsorToken<String?>(name: "ghSponsorToken", defaultValue: null),
  repoman_repoNames<List<String>>(name: "repoNames", defaultValue: <String>["main"]),
  repoman_locks<List<String>>(name: "locks", defaultValue: <String>[]),
  repoman_showGithubAppRedirectDisclosure<bool>(name: "showGithubAppRedirectDisclosure", defaultValue: true),
  repoman_reportIssueToken<String?>(name: "reportIssueToken", defaultValue: null),

  // Settings Manager
  setman_authorName<String>(name: "authorName", defaultValue: ""),
  setman_authorEmail<String>(name: "authorEmail", defaultValue: ""),
  setman_syncMessage<String>(name: "syncMessage", defaultValue: syncMessage),
  setman_syncMessageTimeFormat<String>(name: "syncMessageTimeFormat", defaultValue: syncMessageTimeFormat),
  setman_remote<String>(name: "remote", defaultValue: "origin"),
  setman_syncMessageEnabled<bool>(name: "syncMessageEnabled", defaultValue: false),
  setman_gitDirPath<String>(name: "gitDirPath", defaultValue: ""),
  setman_gitProvider<String?>(name: "gitProvider", defaultValue: null),
  setman_gitAuthUsername<String>(name: "gitAuthUsername", defaultValue: ""),
  setman_gitAuthToken<String>(name: "gitAuthToken", defaultValue: ""),
  setman_gitSshKey<String>(name: "gitSshKey", defaultValue: ""),
  setman_gitSshPassphrase<String>(name: "gitSshPassphrase", defaultValue: ""),
  setman_applicationObserverExpanded<bool>(name: "applicationObserverExpanded", defaultValue: true),
  setman_scheduledSyncSettingsExpanded<bool>(name: "scheduledSyncSettingsExpanded", defaultValue: false),
  setman_schedule<String>(name: "schedule", defaultValue: "never|0"),
  setman_otherSyncSettingsExpanded<bool>(name: "otherSyncSettingsExpanded", defaultValue: false),
  setman_packageNames<List<String>>(name: "packageNames", defaultValue: []),
  setman_syncOnAppOpened<bool>(name: "syncOnAppOpened", defaultValue: false),
  setman_syncOnAppClosed<bool>(name: "syncOnAppClosed", defaultValue: false),
  setman_lastSyncMethod<String>(name: "lastSyncMethod", defaultValue: "");

  const StorageKey({required this.name, required this.defaultValue});
  final T defaultValue;
  final String name;
}

Type getType<T>() => T;

class Storage<T extends StorageKey> {
  final FlutterSecureStorage storage;
  final String Function(String) keyTransformer;

  static String defaultKeyTransformer(key) => key;

  Storage({String? name, this.keyTransformer = defaultKeyTransformer})
    : storage = FlutterSecureStorage(
        aOptions: AndroidOptions(sharedPreferencesName: name, resetOnError: true),
        iOptions: IOSOptions(accountName: name),
      );

  String getKeyName(StorageKey key) => keyTransformer(key.name.toString());

  Future<bool> getBool(StorageKey<bool> key) async => _get<bool>(key);
  Future<String> getString(StorageKey<String> key) async => _get<String>(key);
  Future<String?> getStringNullable(StorageKey<String?> key) async => _get<String?>(key);
  Future<int> getInt(StorageKey<int> key) async => _get<int>(key);
  Future<List<String>> getStringList(StorageKey<List<String>> key) async => _get<List<String>>(key);

  Future<void> setBool(StorageKey<bool> key, bool value) async => _set<bool>(key, value);
  Future<void> setString(StorageKey<String> key, String value) async => _set<String>(key, value);
  Future<void> setStringNullable(StorageKey<String?> key, String? value) async => _set<String?>(key, value);
  Future<void> setInt(StorageKey<int> key, int value) async => _set<int>(key, value);
  Future<void> setStringList(StorageKey<List<String>> key, List<String> value) async => _set<List<String>>(key, value);

  Future<N> _get<N>(StorageKey<N> key) async {
    String? value = await storage.read(key: getKeyName(key));

    if (N == getType<String?>() || N == getType<String>()) {
      if (null is N) {
        return (value == "null" ? null : value) as N;
      }

      return (value ?? key.defaultValue) as N;
    }

    if (N == getType<int?>() || N == getType<int>()) {
      final finalValue = (value == null ? null : int.tryParse(value));

      if (null is N) {
        return finalValue as N;
      }

      return (finalValue ?? key.defaultValue) as N;
    }

    if (N == getType<bool?>() || N == getType<bool>()) {
      final finalValue = (value == null ? null : value == "true");

      if (null is N) {
        return finalValue as N;
      }

      return (finalValue ?? key.defaultValue) as N;
    }

    if (N == getType<List<String>?>() || N == getType<List<String>>()) {
      final finalValue = (value?.isEmpty == true ? null : value)?.split(",");

      if (null is N) {
        return finalValue as N;
      }

      return (finalValue ?? key.defaultValue) as N;
    }

    throw Exception("Key <${key.name.toString()}> datatype <$N> unsupported!");
  }

  Future<void> _set<N>(StorageKey<N> key, N value) async {
    if (N == getType<int?>() || N == getType<int>()) {
      await storage.write(key: getKeyName(key), value: value.toString());
      return;
    }

    if (N == getType<String?>() || N == getType<String>()) {
      await storage.write(key: getKeyName(key), value: value as String?);
      return;
    }

    if (N == getType<bool?>() || N == getType<bool>()) {
      await storage.write(key: getKeyName(key), value: value.toString());
      return;
    }

    if (N == getType<List<String>?>() || N == getType<List<String>>()) {
      await storage.write(key: getKeyName(key), value: value == null ? "" : (value as List<String>).join(","));
      return;
    }

    throw Exception("Key <${key.name.toString()}> datatype <$N> unsupported!");
  }

  Future<Map<String, String>> getAll() async {
    return await storage.readAll();
  }

  Future<void> setAll(Map<String, dynamic> value) async {
    for (var pair in value.entries) {
      await storage.write(key: pair.key, value: pair.value);
    }
  }
}
