import 'dart:io';

import 'package:GitSync/gitsync_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:GitSync/api/helper.dart';
import 'package:GitSync/type/git_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../logger.dart';
import 'package:GitSync/api/manager/storage.dart';
import '../manager/settings_manager.dart';
import '../../constant/strings.dart';
import '../../global.dart';
import '../../src/rust/api/git_manager.dart' as GitManagerRs;
import 'package:intl/intl.dart';
import 'package:sprintf/sprintf.dart';
import 'package:path/path.dart' as path;
import 'package:collection/collection.dart';

class GitManager {
  static final Map<String, String?> _errorContentMap = {
    "failed to parse signature - Signature cannot have an empty name or email": missingAuthorDetailsError,
    "authentication required but no callback set": authMethodMismatchError,
    "invalid data in index - incorrect header signature": invalidIndexHeaderError,
    "cannot push because a reference that you are trying to update on the remote contains commits that are not present locally.": null,
    "error reading file for hashing:": null,
    "failed to parse loose object: invalid header": null,
  };

  static Future<T?> _runWithLock<T>(int index, Future<T?> Function() fn) async {
    final locks = await repoManager.getStringList(StorageKey.repoman_locks);

    T? result;
    await repoManager.setStringList(StorageKey.repoman_locks, [...locks, index.toString()]);
    gitSyncService.refreshUi();
    FlutterBackgroundService().invoke(GitsyncService.REFRESH);

    try {
      result = await fn();
    } catch (e, stackTrace) {
      Logger.logError(LogType.CloneRepo, e, stackTrace);
    } finally {
      await repoManager.setStringList(StorageKey.repoman_locks, locks.where((lock) => lock != index.toString()).toList());
      gitSyncService.refreshUi();
      FlutterBackgroundService().invoke(GitsyncService.REFRESH);
    }

    return result;
  }

  static Future<bool> isLocked([waitForUnlock = true]) async {
    Future<bool> internal() async {
      final locks = await repoManager.getStringList(StorageKey.repoman_locks);
      final locked = locks.contains((await repoManager.getInt(StorageKey.repoman_repoIndex)).toString());
      return locked;
    }

    if (!waitForUnlock) return await internal();

    final end = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(end)) {
      try {
        final locked = await internal();
        if (!locked) return false;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return true;
  }

  static FutureOr<void> _logWrapper(GitManagerRs.LogType type, String message) {
    Logger.gmLog(
      type: LogType.values.firstWhereOrNull((logType) => logType.name.toLowerCase() == type.name.toLowerCase()) ?? LogType.Global,
      message,
    );
  }

  static String? _getErrorContent(String message) {
    final error = message.split(";").first;

    return _errorContentMap.containsKey(error) ? _errorContentMap[error] : message;
  }

  static Future<(String, String)> _getCredentials(SettingsManager settingsManager) async {
    final provider = await settingsManager.getGitProvider();

    return provider == GitProvider.SSH ? await settingsManager.getGitSshAuthCredentials() : await settingsManager.getGitHttpAuthCredentials();
  }

  static bool isGitDir(String dirPath) =>
      Directory("$dirPath/$gitPath").existsSync() || File("$dirPath/$gitIndexPath").existsSync() || File("$dirPath/$gitPath").existsSync();

  // UI Accessible Only
  static Future<String?> clone(String repoUrl, String repoPath, Function(String) cloneTaskCallback, Function(int) cloneProgressCallback) async {
    if (await isLocked()) return operationInProgressError;

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      Future<String?> offlineGuard() async => await returnWhenOffline(() async {
        return networkUnavailable;
      });

      final offline = await offlineGuard();
      if (offline != null) return offline;

      final result = await useDirectory(repoPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (repoPath) async {
        try {
          await GitManagerRs.cloneRepository(
            url: repoUrl,
            pathString: repoPath,
            provider: (await uiSettingsManager.getGitProvider()).name,
            credentials: await _getCredentials(uiSettingsManager),
            author: (await uiSettingsManager.getAuthorName(), await uiSettingsManager.getAuthorEmail()),
            cloneTaskCallback: cloneTaskCallback,
            cloneProgressCallback: cloneProgressCallback,
            log: _logWrapper,
          );
          return "";
        } on AnyhowException catch (e, stackTrace) {
          final offline = await offlineGuard();
          if (offline != null) return offline;

          Logger.logError(LogType.CloneRepo, e.message, stackTrace, causeError: false);
          return _getErrorContent(e.message) ?? e.message.split(";").first;
        } catch (e, stackTrace) {
          Logger.logError(LogType.CloneRepo, e, stackTrace);
        }
        return await offlineGuard() ?? applicationError;
      });

      if (result?.isEmpty == true) return null;
      if (result == null) return inaccessibleDirectoryMessage;

      return result;
    });
  }

  static Future<void> updateSubmodules() async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final dirPath = (await uiSettingsManager.getGitDirPath());
      if (dirPath == null) return;

      if (!await hasNetworkConnection()) return;

      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        if (!isGitDir(dirPath)) return;

        Logger.gmLog(type: LogType.ForcePull, ".git folder found");

        try {
          await GitManagerRs.updateSubmodules(
            pathString: dirPath,
            provider: (await uiSettingsManager.getGitProvider()).name,
            credentials: await _getCredentials(uiSettingsManager),
            log: _logWrapper,
          );
        } catch (e, stackTrace) {
          if (!await hasNetworkConnection()) return;
          Logger.logError(LogType.ForcePull, e, stackTrace);
          return;
        }
      });
    });
  }

  static Future<void> fetchRemote() async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final dirPath = (await uiSettingsManager.getGitDirPath());
      if (dirPath == null) return;

      if (!await hasNetworkConnection()) return;

      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        if (!isGitDir(dirPath)) return;

        Logger.gmLog(type: LogType.ForcePull, ".git folder found");

        try {
          await GitManagerRs.fetchRemote(
            pathString: dirPath,
            remote: await uiSettingsManager.getRemote(),
            provider: (await uiSettingsManager.getGitProvider()).name,
            credentials: await _getCredentials(uiSettingsManager),
            log: _logWrapper,
          );
        } catch (e, stackTrace) {
          if (!await hasNetworkConnection()) return;
          Logger.logError(LogType.ForcePull, e, stackTrace);
          return;
        }
      });
    });
  }

  static Future<void> pullChanges() async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final dirPath = (await uiSettingsManager.getGitDirPath());
      if (dirPath == null) return;

      if (!await hasNetworkConnection()) return;

      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        if (!isGitDir(dirPath)) return;

        Logger.gmLog(type: LogType.ForcePull, ".git folder found");

        try {
          await GitManagerRs.pullChanges(
            pathString: dirPath,
            provider: (await uiSettingsManager.getGitProvider()).name,
            credentials: await _getCredentials(uiSettingsManager),
            log: _logWrapper,
            syncCallback: () {},
          );
        } catch (e, stackTrace) {
          if (!await hasNetworkConnection()) return;
          Logger.logError(LogType.ForcePull, e, stackTrace);
          return;
        }
      });
    });
  }

  static Future<void> stageFilePaths(List<String> paths) async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final dirPath = (await uiSettingsManager.getGitDirPath());
      if (dirPath == null) return;

      if (!await hasNetworkConnection()) return;

      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        if (!isGitDir(dirPath)) return;

        Logger.gmLog(type: LogType.ForcePull, ".git folder found");

        try {
          await GitManagerRs.stageFilePaths(pathString: dirPath, paths: paths, log: _logWrapper);
        } catch (e, stackTrace) {
          if (!await hasNetworkConnection()) return;
          Logger.logError(LogType.ForcePull, e, stackTrace);
          return;
        }
      });
    });
  }

  static Future<void> unstageFilePaths(List<String> paths) async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final dirPath = (await uiSettingsManager.getGitDirPath());
      if (dirPath == null) return;

      if (!await hasNetworkConnection()) return;

      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        if (!isGitDir(dirPath)) return;

        Logger.gmLog(type: LogType.ForcePull, ".git folder found");

        try {
          await GitManagerRs.unstageFilePaths(pathString: dirPath, paths: paths, log: _logWrapper);
        } catch (e, stackTrace) {
          if (!await hasNetworkConnection()) return;
          Logger.logError(LogType.ForcePull, e, stackTrace);
          return;
        }
      });
    });
  }

  static int? _lastRecommendedAction;
  static Future<int?> getRecommendedAction() async {
    if (await isLocked()) {
      return _lastRecommendedAction;
    }

    final dirPath = (await uiSettingsManager.getGitDirPath());
    if (dirPath == null) return null;

    if (!await hasNetworkConnection()) return null;

    return await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
      if (!isGitDir(dirPath)) return null;

      Logger.gmLog(type: LogType.ForcePull, ".git folder found");

      try {
        return await GitManagerRs.getRecommendedAction(
          pathString: dirPath,
          remoteName: await uiSettingsManager.getRemote(),
          provider: (await uiSettingsManager.getGitProvider()).name,
          credentials: await _getCredentials(uiSettingsManager),
          log: _logWrapper,
        );
      } catch (e, stackTrace) {
        if (!await hasNetworkConnection()) return null;
        Logger.logError(LogType.ForcePull, e, stackTrace, causeError: false);
        return null;
      }
    });
  }

  static Future<void> commitChanges(String? syncMessage) async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final dirPath = (await uiSettingsManager.getGitDirPath());
      if (dirPath == null) return;

      if (!await hasNetworkConnection()) return;

      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        if (!isGitDir(dirPath)) return;

        Logger.gmLog(type: LogType.ForcePull, ".git folder found");

        try {
          await GitManagerRs.commitChanges(
            pathString: dirPath,
            author: (await uiSettingsManager.getAuthorName(), await uiSettingsManager.getAuthorEmail()),
            commitSigningCredentials: await uiSettingsManager.getGitCommitSigningCredentials(),
            syncMessage: sprintf(syncMessage ?? await uiSettingsManager.getSyncMessage(), [
              (DateFormat(await uiSettingsManager.getSyncMessageTimeFormat())).format(DateTime.now()),
            ]),
            log: _logWrapper,
          );
        } catch (e, stackTrace) {
          if (!await hasNetworkConnection()) return;
          Logger.logError(LogType.ForcePull, e, stackTrace);
          return;
        }
      });
    });
  }

  static Future<void> pushChanges() async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final dirPath = (await uiSettingsManager.getGitDirPath());
      if (dirPath == null) return;

      if (!await hasNetworkConnection()) return;

      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        if (!isGitDir(dirPath)) return;

        Logger.gmLog(type: LogType.ForcePull, ".git folder found");

        try {
          await GitManagerRs.pushChanges(
            pathString: dirPath,
            remoteName: await uiSettingsManager.getRemote(),
            provider: (await uiSettingsManager.getGitProvider()).name,
            credentials: await _getCredentials(uiSettingsManager),
            log: _logWrapper,
            mergeConflictCallback: () {},
          );
        } catch (e, stackTrace) {
          if (!await hasNetworkConnection()) return;
          Logger.logError(LogType.ForcePull, e, stackTrace);
          return;
        }
      });
    });
  }

  static Future<void> forcePull() async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final dirPath = (await uiSettingsManager.getGitDirPath());
      if (dirPath == null) return;

      if (!await hasNetworkConnection()) return;

      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        if (!isGitDir(dirPath)) return;

        Logger.gmLog(type: LogType.ForcePull, ".git folder found");

        try {
          return await GitManagerRs.forcePull(pathString: dirPath, log: _logWrapper);
        } catch (e, stackTrace) {
          if (!await hasNetworkConnection()) return;
          Logger.logError(LogType.ForcePull, e, stackTrace);
          return;
        }
      });
    });
  }

  static Future<void> forcePush() async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final dirPath = (await uiSettingsManager.getGitDirPath());
      if (dirPath == null) return;

      if (!await hasNetworkConnection()) return;

      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        if (!isGitDir(dirPath)) return;

        Logger.gmLog(type: LogType.ForcePush, ".git folder found");

        try {
          return await GitManagerRs.forcePush(
            pathString: dirPath,
            remoteName: await uiSettingsManager.getRemote(),
            provider: (await uiSettingsManager.getGitProvider()).name,
            credentials: await _getCredentials(uiSettingsManager),
            log: _logWrapper,
          );
        } catch (e, stackTrace) {
          if (!await hasNetworkConnection()) return;
          Logger.logError(LogType.ForcePush, e, stackTrace);
          return;
        }
      });
    });
  }

  static Future<void> downloadAndOverwrite() async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final dirPath = (await uiSettingsManager.getGitDirPath());
      if (dirPath == null) return;

      if (!await hasNetworkConnection()) return;

      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        if (!isGitDir(dirPath)) return;

        Logger.gmLog(type: LogType.ForcePull, ".git folder found");

        try {
          return await GitManagerRs.downloadAndOverwrite(
            pathString: dirPath,
            remoteName: await uiSettingsManager.getRemote(),
            provider: (await uiSettingsManager.getGitProvider()).name,
            author: (await uiSettingsManager.getAuthorName(), await uiSettingsManager.getAuthorEmail()),
            credentials: await _getCredentials(uiSettingsManager),
            log: _logWrapper,
          );
        } catch (e, stackTrace) {
          if (!await hasNetworkConnection()) return;
          Logger.logError(LogType.ForcePull, e, stackTrace);
          return;
        }
      });
    });
  }

  static Future<void> uploadAndOverwrite() async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final dirPath = (await uiSettingsManager.getGitDirPath());
      if (dirPath == null) return;

      if (!await hasNetworkConnection()) return;

      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        if (!isGitDir(dirPath)) return;

        Logger.gmLog(type: LogType.ForcePush, ".git folder found");

        try {
          return await GitManagerRs.uploadAndOverwrite(
            pathString: dirPath,
            remoteName: await uiSettingsManager.getRemote(),
            provider: (await uiSettingsManager.getGitProvider()).name,
            credentials: await _getCredentials(uiSettingsManager),
            commitSigningCredentials: await uiSettingsManager.getGitCommitSigningCredentials(),
            author: (await uiSettingsManager.getAuthorName(), await uiSettingsManager.getAuthorEmail()),
            syncMessage: sprintf(await uiSettingsManager.getSyncMessage(), [
              (DateFormat(await uiSettingsManager.getSyncMessageTimeFormat())).format(DateTime.now()),
            ]),
            log: _logWrapper,
          );
        } catch (e, stackTrace) {
          if (!await hasNetworkConnection()) return;
          Logger.logError(LogType.ForcePush, e, stackTrace);
          return;
        }
      });
    });
  }

  static Future<void> discardChanges(List<String> filePaths) async {
    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final dirPath = (await uiSettingsManager.getGitDirPath());
      if (dirPath == null) return;

      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        if (!isGitDir(dirPath)) return;

        Logger.gmLog(type: LogType.PushToRepo, ".git folder found");

        try {
          return await GitManagerRs.discardChanges(pathString: dirPath, filePaths: filePaths, log: _logWrapper);
        } catch (e, stackTrace) {
          Logger.logError(LogType.PushToRepo, e, stackTrace);
          return;
        }
      });
    });
  }

  static Future<void> unstageAll() async {
    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final dirPath = (await uiSettingsManager.getGitDirPath());
      if (dirPath == null) return;

      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        if (!isGitDir(dirPath)) return;

        Logger.gmLog(type: LogType.PushToRepo, ".git folder found");

        try {
          return await GitManagerRs.unstageAll(pathString: dirPath, log: _logWrapper);
        } catch (e, stackTrace) {
          Logger.logError(LogType.PushToRepo, e, stackTrace);
          return;
        }
      });
    });
  }

  static List<GitManagerRs.Commit> _lastRecentCommits = [];
  static Future<List<GitManagerRs.Commit>> getRecentCommits() async {
    if (await isLocked()) {
      return _lastRecentCommits;
    }

    final dirPath = (await uiSettingsManager.getGitDirPath());
    if (dirPath == null || dirPath.isEmpty) return [];

    final result =
        await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
          if (!isGitDir(dirPath)) {
            return <GitManagerRs.Commit>[];
          }

          Logger.gmLog(type: LogType.RecentCommits, ".git folder found");

          try {
            return await GitManagerRs.getRecentCommits(pathString: dirPath, remoteName: await uiSettingsManager.getRemote(), log: _logWrapper);
          } catch (e, stackTrace) {
            Logger.logError(LogType.RecentCommits, e, stackTrace);
            return <GitManagerRs.Commit>[];
          }
        }) ??
        <GitManagerRs.Commit>[];

    _lastRecentCommits = result;
    return result;
  }

  static List<String> _lastConflicting = [];
  static Future<List<String>> getConflicting([int? repomanRepoindex]) async {
    if (await isLocked()) {
      return _lastConflicting;
    }

    final settingsManager = repomanRepoindex == null ? uiSettingsManager : await SettingsManager().reinit(repoIndex: repomanRepoindex);
    final dirPath = await settingsManager.getGitDirPath();
    if (dirPath == null || dirPath.isEmpty) return [];
    final result =
        await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
          if (!isGitDir(dirPath)) {
            return <String>[];
          }

          Logger.gmLog(type: LogType.RecentCommits, ".git folder found");

          try {
            return (await GitManagerRs.getConflicting(pathString: dirPath, log: _logWrapper)).toSet().toList();
          } catch (e, stackTrace) {
            Logger.logError(LogType.RecentCommits, e, stackTrace);
            return <String>[];
          }
        }) ??
        <String>[];

    _lastConflicting = result;
    return result;
  }

  static List<(String, int)> _lastUncommittedFilePaths = [];
  static Future<List<(String, int)>> getUncommittedFilePaths([int? repomanRepoindex]) async {
    if (await isLocked()) {
      return _lastUncommittedFilePaths;
    }

    if (demo) {
      return [
        ("storage/external/example/file_changed.md", 1),
        ("storage/external/example/file_added.md", 3),
        ("storage/external/example/file_removed.md", 2),
      ];
    }

    final settingsManager = repomanRepoindex == null ? uiSettingsManager : await SettingsManager().reinit(repoIndex: repomanRepoindex);
    final dirPath = (await settingsManager.getGitDirPath());
    if (dirPath == null) return [];
    final result =
        await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
          Logger.gmLog(type: LogType.RecentCommits, ".git folder found");

          try {
            return (await GitManagerRs.getUncommittedFilePaths(pathString: dirPath, log: _logWrapper)).toSet().toList();
          } catch (e, stackTrace) {
            Logger.logError(LogType.RecentCommits, e, stackTrace);
            return <(String, int)>[];
          }
        }) ??
        <(String, int)>[];

    _lastUncommittedFilePaths = result;
    return result;
  }

  static List<(String, int)> _lastStagedFilePaths = [];
  static Future<List<(String, int)>> getStagedFilePaths([int? repomanRepoindex]) async {
    if (await isLocked()) {
      return _lastStagedFilePaths;
    }

    if (demo) {
      return [("storage/external/example/file_staged.md", 1)];
    }

    final settingsManager = repomanRepoindex == null ? uiSettingsManager : await SettingsManager().reinit(repoIndex: repomanRepoindex);
    final dirPath = (await settingsManager.getGitDirPath());
    if (dirPath == null) return [];
    final result =
        await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
          Logger.gmLog(type: LogType.RecentCommits, ".git folder found");

          try {
            return (await GitManagerRs.getStagedFilePaths(pathString: dirPath, log: _logWrapper)).toSet().toList();
          } catch (e, stackTrace) {
            Logger.logError(LogType.RecentCommits, e, stackTrace);
            return <(String, int)>[];
          }
        }) ??
        <(String, int)>[];

    _lastStagedFilePaths = result;
    return result;
  }

  static Future<void> abortMerge() async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final dirPath = (await uiSettingsManager.getGitDirPath());
      if (dirPath == null) return;
      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        try {
          await GitManagerRs.abortMerge(pathString: dirPath, log: _logWrapper);
        } catch (e, stackTrace) {
          Logger.logError(LogType.AbortMerge, e, stackTrace);
        }
      });
    });
  }

  static String? _lastBranchName;
  static Future<String?> getBranchName([int? repomanRepoindex]) async {
    if (await isLocked()) {
      return _lastBranchName;
    }

    final settingsManager = repomanRepoindex == null ? uiSettingsManager : await SettingsManager().reinit(repoIndex: repomanRepoindex);
    final dirPath = (await settingsManager.getGitDirPath());
    if (dirPath == null) return repositoryNotFound;
    final result = await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
      Logger.gmLog(type: LogType.RecentCommits, ".git folder found");

      try {
        return (await GitManagerRs.getBranchName(pathString: dirPath, log: _logWrapper));
      } catch (e, stackTrace) {
        Logger.logError(LogType.RecentCommits, e, stackTrace);
        return repositoryNotFound;
      }
    });

    _lastBranchName = result;
    return result;
  }

  static List<String> _lastBranchNames = [];
  static Future<List<String>> getBranchNames([int? repomanRepoindex]) async {
    if (await isLocked()) {
      return _lastBranchNames;
    }

    final settingsManager = repomanRepoindex == null ? uiSettingsManager : await SettingsManager().reinit(repoIndex: repomanRepoindex);
    final dirPath = (await settingsManager.getGitDirPath());
    if (dirPath == null) return [];
    final result =
        await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
          Logger.gmLog(type: LogType.RecentCommits, ".git folder found");

          try {
            return (await GitManagerRs.getBranchNames(pathString: dirPath, remote: await settingsManager.getRemote(), log: _logWrapper));
          } catch (e, stackTrace) {
            Logger.logError(LogType.RecentCommits, e, stackTrace);
          }
          return null;
        }) ??
        <String>[];

    _lastBranchNames = result;
    return result;
  }

  static Future<void> checkoutBranch(String branchName, [int? repomanRepoindex]) async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repomanRepoindex ?? repoIndex, () async {
      final settingsManager = repomanRepoindex == null ? uiSettingsManager : await SettingsManager().reinit(repoIndex: repomanRepoindex);
      final dirPath = (await settingsManager.getGitDirPath());
      if (dirPath == null) return;
      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        Logger.gmLog(type: LogType.RecentCommits, ".git folder found");

        try {
          return (await GitManagerRs.checkoutBranch(
            pathString: dirPath,
            remote: await settingsManager.getRemote(),
            branchName: branchName,
            log: _logWrapper,
          ));
        } catch (e, stackTrace) {
          Logger.logError(LogType.RecentCommits, e, stackTrace);
          return;
        }
      });
    });
  }

  static Future<void> createBranch(String branchName, String basedOn, [int? repomanRepoindex]) async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repomanRepoindex ?? repoIndex, () async {
      final settingsManager = repomanRepoindex == null ? uiSettingsManager : await SettingsManager().reinit(repoIndex: repomanRepoindex);
      final dirPath = (await settingsManager.getGitDirPath());
      if (dirPath == null) return;

      if (!await hasNetworkConnection()) return;

      await useDirectory(dirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
        Logger.gmLog(type: LogType.RecentCommits, ".git folder found");

        try {
          return (await GitManagerRs.createBranch(
            pathString: dirPath,
            remoteName: await settingsManager.getRemote(),
            newBranchName: branchName,
            sourceBranchName: basedOn,
            provider: (await settingsManager.getGitProvider()).name,
            credentials: await _getCredentials(settingsManager),
            log: _logWrapper,
          ));
        } catch (e, stackTrace) {
          if (!await hasNetworkConnection()) return;

          Logger.logError(LogType.RecentCommits, e, stackTrace);
          return;
        }
      });
    });
  }

  static Future<String> readGitignore() async {
    final gitDirPath = (await uiSettingsManager.getGitDirPath());
    final gitignorePath = '$gitDirPath/$gitIgnorePath';
    if (gitDirPath == null) return "";
    return await useDirectory(gitDirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (gitDirPath) async {
          final file = File(gitignorePath);
          if (!file.existsSync()) return '';
          return file.readAsStringSync();
        }) ??
        "";
  }

  static void writeGitignore(String gitignoreString) async {
    final gitDirPath = (await uiSettingsManager.getGitDirPath());
    final gitignorePath = '$gitDirPath/$gitIgnorePath';
    if (gitDirPath == null) return;
    await useDirectory(gitDirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (gitDirPath) async {
      final file = File(gitignorePath);
      if (!file.existsSync()) file.createSync();
      file.writeAsStringSync(gitignoreString, mode: FileMode.write);
    });
  }

  static Future<String> readGitInfoExclude() async {
    final gitDirPath = (await uiSettingsManager.getGitDirPath());
    final gitInfoExcludeFullPath = '$gitDirPath/$gitInfoExcludePath';
    if (gitDirPath == null) return "";
    return await useDirectory(gitDirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (gitDirPath) async {
          final file = File(gitInfoExcludeFullPath);
          if (!file.existsSync()) return '';
          return file.readAsStringSync();
        }) ??
        "";
  }

  static void writeGitInfoExclude(String gitignoreString) async {
    final gitDirPath = (await uiSettingsManager.getGitDirPath());
    final gitInfoExcludeFullPath = '$gitDirPath/$gitInfoExcludePath';
    if (gitDirPath == null) return;
    await useDirectory(gitDirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (gitDirPath) async {
      final file = File(gitInfoExcludeFullPath);
      final parentDir = file.parent;
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }
      if (!file.existsSync()) file.createSync();
      file.writeAsStringSync(gitignoreString, mode: FileMode.write);
    });
  }

  static bool _lastDisableSsl = false;
  static Future<bool> getDisableSsl() async {
    if (await isLocked()) {
      return _lastDisableSsl;
    }

    final gitDirPath = (await uiSettingsManager.getGitDirPath());
    if (gitDirPath == null) return false;

    final result =
        await useDirectory(gitDirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (gitDirPath) async {
          try {
            return await GitManagerRs.getDisableSsl(gitDir: gitDirPath);
          } on AnyhowException catch (e, stackTrace) {
            Logger.logError(LogType.PullFromRepo, e.message, stackTrace);
          } catch (e, stackTrace) {
            Logger.logError(LogType.PullFromRepo, e, stackTrace);
          }
        }) ??
        false;

    _lastDisableSsl = result;
    return result;
  }

  static Future<void> setDisableSsl(bool disable) async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final gitDirPath = (await uiSettingsManager.getGitDirPath());
      if (gitDirPath == null) return;

      await useDirectory(gitDirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (gitDirPath) async {
        try {
          return await GitManagerRs.setDisableSsl(gitDir: gitDirPath, disable: disable);
        } on AnyhowException catch (e, stackTrace) {
          Logger.logError(LogType.PullFromRepo, e.message, stackTrace);
        } catch (e, stackTrace) {
          Logger.logError(LogType.PullFromRepo, e, stackTrace);
        }
      });
    });
  }

  static Future<(String, String)?> generateKeyPair(String passphrase) async {
    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      try {
        const ed25519Format = "ed25519";
        return await GitManagerRs.generateSshKey(format: ed25519Format, passphrase: passphrase, log: _logWrapper);
      } on AnyhowException catch (e, stackTrace) {
        Logger.logError(LogType.PullFromRepo, e.message, stackTrace);
      } catch (e, stackTrace) {
        Logger.logError(LogType.PullFromRepo, e, stackTrace);
      }
      return null;
    });
  }

  static Future<(String, String)?> getRemoteUrlLink([int? repomanRepoindex]) async {
    final settingsManager = repomanRepoindex == null ? uiSettingsManager : await SettingsManager().reinit(repoIndex: repomanRepoindex);
    final gitDirPath = (await settingsManager.getGitDirPath());
    final remoteName = await settingsManager.getRemote();

    if (gitDirPath == null) return null;

    return await useDirectory(gitDirPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (gitDirPath) async {
      try {
        final gitDir = Directory(gitDirPath);
        if (!await gitDir.exists()) {
          throw Exception('Directory does not exist: $gitDirPath');
        }

        String gitConfigPath = path.join(gitDirPath, '.git', 'config');

        final gitDirFile = File(path.join(gitDirPath, '.git'));
        if (await gitDirFile.exists()) {
          final gitDirContent = await gitDirFile.readAsString();
          final match = RegExp(r'gitdir:\s*(.+)').firstMatch(gitDirContent);
          if (match != null) {
            final actualGitDirPath = path.normalize(path.join(gitDirPath, match.group(1)!.trim()));
            gitConfigPath = path.join(actualGitDirPath, 'config');
          }
        }

        final configFile = File(gitConfigPath);

        if (!await configFile.exists()) {
          throw Exception('Not a Git repository: $gitDirPath');
        }

        final configContent = await configFile.readAsString();

        final remoteUrlPattern = RegExp(r'\[remote\s+"' + remoteName + r'"\]\s+url\s*=\s*([^\n]+)');
        final match = remoteUrlPattern.firstMatch(configContent);

        if (match == null || match.groupCount < 1) {
          return null;
        }

        String remoteUrl = match.group(1)!.trim();

        return (remoteUrl, _convertToWebUrl(remoteUrl));
      } catch (e) {
        print('Error getting Git remote URL: $e');
        return null;
      }
    });
  }

  static String _convertToWebUrl(String remoteUrl) {
    remoteUrl = remoteUrl.trim();

    final sshPattern = RegExp(r'^(?:ssh://)?(?:[^:@]+)@([^:]+):([^/]+)/(.+?)(?:\.git)?$');
    if (sshPattern.hasMatch(remoteUrl)) {
      final match = sshPattern.firstMatch(remoteUrl)!;
      final host = match.group(1)!;
      final username = match.group(2)!;
      final repo = match.group(3)!;

      return 'https://$host/$username/$repo';
    }

    final httpsPattern = RegExp(r'^https?://([^/]+)/(.+?)(?:\.git)?$');
    if (httpsPattern.hasMatch(remoteUrl)) {
      final match = httpsPattern.firstMatch(remoteUrl)!;
      final host = match.group(1)!;
      final path = match.group(2)!;

      return 'https://$host/$path';
    }

    final gitPattern = RegExp(r'^git://([^/]+)/(.+?)(?:\.git)?$');
    if (gitPattern.hasMatch(remoteUrl)) {
      final match = gitPattern.firstMatch(remoteUrl)!;
      final host = match.group(1)!;
      final path = match.group(2)!;

      return 'https://$host/$path';
    }

    return remoteUrl;
  }

  static Future<void> deleteDirContents([String? dirPath, int? repomanRepoindex]) async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final settingsManager = repomanRepoindex == null ? uiSettingsManager : await SettingsManager().reinit(repoIndex: repomanRepoindex);
      final gitDirPath = dirPath ?? (await uiSettingsManager.getGitDirPath());
      if (gitDirPath == null || gitDirPath.isEmpty) return;

      await useDirectory(gitDirPath, (bookmarkPath) async => await settingsManager.setGitDirPath(bookmarkPath), (selectedDirectory) async {
        final dir = Directory(selectedDirectory);
        if (Platform.isIOS) {
          try {
            final entities = dir.listSync(recursive: false);
            for (var entity in entities) {
              if (entity is File) {
                await entity.delete();
              } else if (entity is Directory) {
                await entity.delete(recursive: true);
              }
            }
          } catch (e) {
            print('Error while deleting folder contents: $e');
          }
        } else {
          await dir.delete(recursive: true);
          await dir.create();
        }
      });
    });
  }

  static Future<void> deleteGitIndex([int? repomanRepoindex]) async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final settingsManager = repomanRepoindex == null ? uiSettingsManager : await SettingsManager().reinit(repoIndex: repomanRepoindex);
      final gitDirPath = await uiSettingsManager.getGitDirPath();
      if (gitDirPath == null || gitDirPath.isEmpty) return;

      await useDirectory(gitDirPath, (bookmarkPath) async => await settingsManager.setGitDirPath(bookmarkPath), (selectedDirectory) async {
        final file = File("$selectedDirectory/$gitIndexPath");
        if (await file.exists()) {
          await file.delete();
        }
      });
    });
  }

  static Future<void> deleteFetchHead([int? repomanRepoindex]) async {
    if (await isLocked()) {
      Fluttertoast.showToast(msg: operationInProgressError, toastLength: Toast.LENGTH_SHORT, gravity: null);
      return;
    }

    final repoIndex = await repoManager.getInt(StorageKey.repoman_repoIndex);

    return await _runWithLock(repoIndex, () async {
      final settingsManager = repomanRepoindex == null ? uiSettingsManager : await SettingsManager().reinit(repoIndex: repomanRepoindex);
      final gitDirPath = await uiSettingsManager.getGitDirPath();
      if (gitDirPath == null || gitDirPath.isEmpty) return;

      await useDirectory(gitDirPath, (bookmarkPath) async => await settingsManager.setGitDirPath(bookmarkPath), (selectedDirectory) async {
        final file = File("$selectedDirectory/$gitFetchHeadPath");
        if (await file.exists()) {
          await file.delete();
        }
      });
    });
  }

  static final List<String> _lastSubmodulePaths = [];
  static Future<List<String>> getSubmodulePaths(String repoPath) async {
    if (await isLocked()) {
      return _lastSubmodulePaths;
    }

    if (!await hasNetworkConnection()) return [];
    return await useDirectory(repoPath, (bookmarkPath) async => await uiSettingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
          if (!isGitDir(dirPath)) return null;

          Logger.gmLog(type: LogType.SelectDirectory, ".git folder found");

          try {
            return await GitManagerRs.getSubmodulePaths(pathString: dirPath);
          } catch (e, stackTrace) {
            if (!await hasNetworkConnection()) return null;
            Logger.logError(LogType.SelectDirectory, e, stackTrace);
            return null;
          }
        }) ??
        [];
  }

  // Background Accessible
  static Future<bool?> downloadChanges(int repomanRepoindex, SettingsManager settingsManager, Function() syncCallback) async {
    return await _runWithLock(repomanRepoindex, () async {
      if (!await hasNetworkConnection()) return null;

      try {
        final dirPath = (await settingsManager.getGitDirPath());
        if (dirPath == null) return null;
        return await useDirectory(dirPath, (bookmarkPath) async => await settingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
          return await GitManagerRs.downloadChanges(
            pathString: dirPath,
            remote: await settingsManager.getRemote(),
            provider: (await settingsManager.getGitProvider()).name,
            author: (await settingsManager.getAuthorName(), await settingsManager.getAuthorEmail()),
            credentials: await _getCredentials(settingsManager),
            commitSigningCredentials: await settingsManager.getGitCommitSigningCredentials(),
            syncCallback: syncCallback,
            log: _logWrapper,
          );
        });
      } on AnyhowException catch (e, stackTrace) {
        final errorContent = _getErrorContent(e.message);
        if (errorContent == null) return false;
        Logger.logError(LogType.PullFromRepo, e.message, stackTrace, errorContent: errorContent);
      } catch (e, stackTrace) {
        Logger.logError(LogType.PullFromRepo, e, stackTrace);
      }
      return null;
    });
  }

  static Future<bool?> uploadChanges(
    int repomanRepoindex,
    SettingsManager settingsManager,
    Function() syncCallback, [
    List<String>? filePaths,
    String? syncMessage,
  ]) async {
    return await _runWithLock(repomanRepoindex, () async {
      if (!await hasNetworkConnection()) return null;

      try {
        final dirPath = (await settingsManager.getGitDirPath());
        if (dirPath == null) return null;

        return await useDirectory(dirPath, (bookmarkPath) async => await settingsManager.setGitDirPath(bookmarkPath), (dirPath) async {
          return await GitManagerRs.uploadChanges(
            pathString: dirPath,
            remoteName: await settingsManager.getRemote(),
            provider: (await settingsManager.getGitProvider()).name,
            author: (await settingsManager.getAuthorName(), await settingsManager.getAuthorEmail()),
            credentials: await _getCredentials(settingsManager),
            commitSigningCredentials: await settingsManager.getGitCommitSigningCredentials(),
            syncCallback: syncCallback,
            mergeConflictCallback: () {
              repoManager.setInt(StorageKey.repoman_repoIndex, repomanRepoindex);
              sendMergeConflictNotification();
            },
            filePaths: filePaths,
            syncMessage: sprintf(syncMessage ?? await settingsManager.getSyncMessage(), [
              (DateFormat(await settingsManager.getSyncMessageTimeFormat())).format(DateTime.now()),
            ]),
            log: _logWrapper,
          );
        });
      } on AnyhowException catch (e, stackTrace) {
        final errorContent = _getErrorContent(e.message);
        if (errorContent == null) return false;
        Logger.logError(LogType.PushToRepo, e.message, stackTrace, errorContent: errorContent);
      } catch (e, stackTrace) {
        Logger.logError(LogType.PushToRepo, e, stackTrace);
      }
      return null;
    });
  }
}
