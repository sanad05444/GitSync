import 'package:GitSync/api/manager/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:GitSync/api/manager/repo_manager.dart';
import 'package:GitSync/type/git_provider.dart';
import 'package:workmanager/workmanager.dart';
import '../api/helper.dart';
import '../api/logger.dart';
import '../api/manager/git_manager.dart';
import '../api/manager/settings_manager.dart';
import '../constant/strings.dart';

ServiceInstance? serviceInstance;

class GitsyncService {
  static const ACCESSIBILITY_EVENT = "ACCESSIBILITY_EVENT";
  static const FORCE_SYNC = "FORCE_SYNC";
  static const INTENT_SYNC = "INTENT_SYNC";
  static const TILE_SYNC = "TILE_SYNC";
  static const MERGE = "MERGE";
  static const REFRESH = "REFRESH";
  static const MERGE_COMPLETE = "MERGE_COMPLETE";

  static RepoManager repoManager = RepoManager();

  bool isScheduled = false;
  bool isSyncing = false;

  Future<void> initialise(Function(ServiceInstance) onServiceStart, Function() callbackDispatcher) async {
    final service = FlutterBackgroundService();

    Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);

    await service.configure(
      androidConfiguration: AndroidConfiguration(autoStart: true, isForegroundMode: false, onStart: onServiceStart),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onServiceStart,
        onBackground: (service) {
          onServiceStart(service);
          return true;
        },
      ),
    );
  }

  Future<void> debouncedSync(int repomanRepoindex, [bool forced = false, bool immediate = false]) async {
    if (!await hasNetworkConnection()) {
      Workmanager().registerOneOffTask(
        "$networkScheduledSyncKey$repomanRepoindex",
        networkScheduledSyncKey,
        inputData: {"repoIndex": repomanRepoindex},
        constraints: Constraints(networkType: NetworkType.connected),
      );
      return;
    }
    final settingsManager = SettingsManager();
    await settingsManager.reinit(repoIndex: repomanRepoindex);

    if (isScheduled) {
      _displaySyncMessage(settingsManager, "Sync In Progress");
      return;
    } else {
      if (isSyncing) {
        isScheduled = true;
        Logger.gmLog(type: LogType.Sync, "Sync Scheduled");
        _displaySyncMessage(settingsManager, "Sync Scheduled");
        return;
      } else {
        if (immediate) {
          await _sync(repomanRepoindex, forced);
          return;
        }
        debounce(repomanRepoindex.toString(), 500, () => _sync(repomanRepoindex, forced));
      }
    }
  }

  void _displaySyncMessage(SettingsManager settingsManager, String message) async {
    if (await settingsManager.getBool(StorageKey.setman_syncMessageEnabled)) {
      Fluttertoast.showToast(msg: message, toastLength: Toast.LENGTH_LONG, gravity: null);
    }
  }

  Future<void> _sync(int repomanRepoindex, [bool forced = false]) async {
    final settingsManager = SettingsManager();
    await settingsManager.reinit(repoIndex: repomanRepoindex);

    final provider = await settingsManager.getGitProvider();

    if (provider == GitProvider.SSH
        ? (await settingsManager.getGitSshAuthCredentials()).$2.isEmpty
        : (await settingsManager.getGitHttpAuthCredentials()).$2.isEmpty) {
      Logger.gmLog(type: LogType.Sync, "Credentials Not Found");
      Fluttertoast.showToast(msg: repositoryNotFound, toastLength: Toast.LENGTH_LONG, gravity: null);
      return;
    }

    if ((await GitManager.getConflicting(repomanRepoindex)).isNotEmpty) {
      Fluttertoast.showToast(msg: ongoingMergeConflict, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    if (forced) {
      _displaySyncMessage(settingsManager, "Detecting Changes…");
    }
    Logger.gmLog(type: LogType.Sync, "Start Sync");
    isSyncing = true;

    await () async {
      final gitDirPath = await settingsManager.getGitDirPath();

      if (gitDirPath == null) {
        Logger.gmLog(type: LogType.Sync, "Repository Not Found");
        Fluttertoast.showToast(msg: repositoryNotFound, toastLength: Toast.LENGTH_LONG, gravity: null);
        return;
      }

      bool synced = false;

      if (!await hasNetworkConnection()) {
        Workmanager().registerOneOffTask(
          "$networkScheduledSyncKey$repomanRepoindex",
          networkScheduledSyncKey,
          inputData: {"repoIndex": repomanRepoindex},
          constraints: Constraints(networkType: NetworkType.connected),
        );
        return;
      }

      Logger.gmLog(type: LogType.Sync, "Start Pull Repo");
      final pullResult = await GitManager.downloadChanges(repomanRepoindex, settingsManager, () {
        synced = true;
        _displaySyncMessage(settingsManager, syncStartPull);
      });

      switch (pullResult) {
        case null:
          {
            Logger.gmLog(type: LogType.Sync, "Pull Repo Failed");
            if (!await hasNetworkConnection()) {
              Workmanager().registerOneOffTask(
                "$networkScheduledSyncKey$repomanRepoindex",
                networkScheduledSyncKey,
                inputData: {"repoIndex": repomanRepoindex},
                constraints: Constraints(networkType: NetworkType.connected),
              );
              return;
            }
            return;
          }
        case true:
          {
            Logger.gmLog(type: LogType.Sync, "Pull Complete");
          }
        case false:
          {
            Logger.gmLog(type: LogType.Sync, "Pull Not Required");
          }
      }

      if (!await hasNetworkConnection()) {
        Workmanager().registerOneOffTask(
          "$networkScheduledSyncKey$repomanRepoindex",
          networkScheduledSyncKey,
          inputData: {"repoIndex": repomanRepoindex},
          constraints: Constraints(networkType: NetworkType.connected),
        );
        return;
      }

      Logger.gmLog(type: LogType.Sync, "Start Push Repo");
      final pushResult = await GitManager.uploadChanges(repomanRepoindex, settingsManager, () {
        if (!synced) {
          _displaySyncMessage(settingsManager, syncStartPush);
        }
      });

      switch (pushResult) {
        case null:
          {
            Logger.gmLog(type: LogType.Sync, "Push Repo Failed");
            if (!await hasNetworkConnection()) {
              Workmanager().registerOneOffTask(
                "$networkScheduledSyncKey$repomanRepoindex",
                networkScheduledSyncKey,
                inputData: {"repoIndex": repomanRepoindex},
                constraints: Constraints(networkType: NetworkType.connected),
              );
              return;
            }
            return;
          }
        case true:
          {
            Logger.gmLog(type: LogType.Sync, "Push Complete");
          }
        case false:
          {
            Logger.gmLog(type: LogType.Sync, "Push Not Required");
          }
      }

      if (!(pushResult == true || pullResult == true)) {
        if (forced) {
          _displaySyncMessage(settingsManager, syncNotRequired);
        }
        return;
      } else {
        _displaySyncMessage(settingsManager, syncComplete);
      }
    }();

    Logger.gmLog(type: LogType.Sync, "Sync Complete!");
    isSyncing = false;

    Logger.dismissError(null);
    serviceInstance?.invoke(REFRESH);

    if (isScheduled) {
      Logger.gmLog(type: LogType.Sync, "Scheduled Sync Starting");
      isScheduled = false;
      debouncedSync(repomanRepoindex);
    }
  }

  void refreshUi() {
    serviceInstance?.invoke(REFRESH);
  }

  void merge(int repomanRepoindex, String commitMessage) async {
    final settingsManager = SettingsManager();
    await settingsManager.reinit(repoIndex: repomanRepoindex);

    final pushResult = await GitManager.uploadChanges(
      repomanRepoindex,
      settingsManager,
      () {
        Fluttertoast.showToast(msg: resolvingMerge, toastLength: Toast.LENGTH_SHORT, gravity: null);
      },
      null,
      commitMessage,
    );

    switch (pushResult) {
      case null:
        {
          Logger.gmLog(type: LogType.Sync, "Merge Failed");
          return;
        }
      case true:
        Logger.gmLog(type: LogType.Sync, "Merge Complete");
      case false:
        Logger.gmLog(type: LogType.Sync, "Merge Not Required");
    }

    debouncedSync(repomanRepoindex, true);

    serviceInstance?.invoke(MERGE_COMPLETE);
  }

  String lastOpenPackageName = "-----";
  String lastOpenPackageNameExcludingInputs = "-----";

  void accessibilityEvent(String packageName, List<String> enabledInputMethods) async {
    for (var index = 0; index < (await repoManager.getStringList(StorageKey.repoman_repoNames)).length; index++) {
      final settingsManager = SettingsManager();
      await settingsManager.reinit(repoIndex: index);

      final syncClosed = await settingsManager.getBool(StorageKey.setman_syncOnAppClosed);
      final syncOpened = await settingsManager.getBool(StorageKey.setman_syncOnAppOpened);

      final packageNames = await settingsManager.getApplicationPackages();

      if ((!syncOpened && !syncClosed) || packageNames.isEmpty) continue;

      if (packageNames.contains(lastOpenPackageNameExcludingInputs) &&
          !packageNames.contains(packageName) &&
          !enabledInputMethods.contains(packageName)) {
        Logger.gmLog(type: LogType.AccessibilityService, "Application Closed");
        if (syncClosed) {
          debouncedSync(index);
        }
      }

      if (!packageNames.contains(lastOpenPackageNameExcludingInputs) &&
          packageNames.contains(packageName) &&
          !enabledInputMethods.contains(packageName)) {
        Logger.gmLog(type: LogType.AccessibilityService, "Application Opened");
        if (syncOpened) {
          debouncedSync(index);
        }
      }
    }

    lastOpenPackageName = packageName;
    if (!enabledInputMethods.contains(packageName)) {
      lastOpenPackageNameExcludingInputs = packageName;
    }
  }
}
