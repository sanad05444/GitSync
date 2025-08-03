import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:GitSync/ui/component/custom_showcase.dart';
import 'package:GitSync/ui/component/scheduled_sync_settings.dart';
import 'package:GitSync/ui/dialog/base_alert_dialog.dart';
import 'package:GitSync/api/manager/storage.dart';
import 'package:GitSync/ui/dialog/change_language.dart' as ChangeLanguageDialog show showDialog;
import 'package:GitSync/ui/dialog/create_branch.dart' as CreateBranchDialog;
import 'package:GitSync/ui/dialog/merge_conflict.dart' as MergeConflictDialog;
import 'package:GitSync/ui/page/global_settings_main.dart';
import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:GitSync/api/accessibility_service_helper.dart';
import 'package:GitSync/ui/component/auto_sync_settings.dart';
import 'package:GitSync/ui/component/item_merge_conflict.dart';
import 'package:GitSync/ui/component/tile_sync_settings.dart';
import 'package:GitSync/ui/dialog/onboarding_controller.dart';
import 'package:mixin_logger/mixin_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';
import '../api/helper.dart';
import '../api/logger.dart';
import '../api/manager/git_manager.dart';
import '../constant/strings.dart';
import '../gitsync_service.dart';
import '../src/rust/api/git_manager.dart' as GitManagerRs;
import '../src/rust/frb_generated.dart';
import '../type/git_provider.dart';
import '../ui/dialog/auth.dart' as AuthDialog;
import '../ui/dialog/author_details_prompt.dart' as AuthorDetailsPromptDialog;
import '../ui/dialog/legacy_app_user.dart' as LegacyAppUserDialog;
import '../ui/dialog/add_container.dart' as AddContainerDialog;
import '../ui/dialog/remove_container.dart' as RemoveContainerDialog;
import '../ui/dialog/rename_container.dart' as RenameContainerDialog;
import '../ui/dialog/unlock_premium.dart' as UnlockPremiumDialog;
import 'ui/dialog/confirm_force_push_pull.dart' as ConfirmForcePushPullDialog;
import '../ui/dialog/force_push_pull.dart' as ForcePushPullDialog;
import '../ui/dialog/manual_sync.dart' as ManualSyncDialog;
import '../ui/dialog/confirm_branch_checkout.dart' as ConfirmBranchCheckoutDialog;
import '../constant/colors.dart';
import '../constant/dimens.dart';
import '../global.dart';
import '../ui/component/item_commit.dart';
import '../ui/page/clone_repo_main.dart';
import '../ui/page/settings_main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

const SET_AS_FOREGROUND = "setAsForeground";
const SET_AS_BACKGROUND = "setAsBackground";

const REPO_INDEX = "repoman_repoIndex";
const PACKAGE_NAME = "packageName";
const ENABLED_INPUT_METHODS = "enabledInputMethods";
const COMMIT_MESSAGE = "commitMessage";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await gitSyncService.initialise(onServiceStart, callbackDispatcher);
  await uiSettingsManager.reinit();
  initLogger("${(await getTemporaryDirectory()).path}/logs", maxFileCount: 10, maxFileLength: 5 * 1024 * 1024);
  await Logger.init();
  await RustLib.init();
  await requestStoragePerm(false);
  // Loads premiumManager initial state
  await premiumManager.init();

  if (kReleaseMode) {
    FlutterError.onError = (details) {
      e("${LogType.Global.name}: ${"${details.stack.toString()}\nError: ${details.exception.toString()}"}");
    };
  }

  runApp(const MyApp());
}

@pragma('vm:entry-point')
void callbackDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await RustLib.init();

  Workmanager().executeTask((task, inputData) async {
    try {
      if (task.contains(scheduledSyncKey)) {
        final int repoIndex =
            inputData?["repoIndex"] ?? int.tryParse(task.replaceAll(scheduledSyncKey, "")) ?? await repoManager.getInt(StorageKey.repoman_repoIndex);

        if (Platform.isIOS) {
          await gitSyncService.debouncedSync(repoIndex, true, true);
        } else {
          FlutterBackgroundService().invoke(GitsyncService.FORCE_SYNC, {REPO_INDEX: "$repoIndex"});
        }

        return Future.value(true);
      }

      if (task.contains(networkScheduledSyncKey)) {
        final int repoIndex =
            inputData?["repoIndex"] ?? int.tryParse(task.replaceAll(scheduledSyncKey, "")) ?? await repoManager.getInt(StorageKey.repoman_repoIndex);

        if (Platform.isIOS) {
          await gitSyncService.debouncedSync(repoIndex, true, true);
        } else {
          FlutterBackgroundService().invoke(GitsyncService.FORCE_SYNC, {REPO_INDEX: "$repoIndex"});
        }

        return Future.value(true);
      }
      return Future.value(false);
    } catch (e) {
      return Future.error(e);
    }
  });
}

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  serviceInstance = service;
  await RustLib.init();

  service.on(GitsyncService.ACCESSIBILITY_EVENT).listen((event) {
    print(GitsyncService.ACCESSIBILITY_EVENT);
    if (event == null) return;
    gitSyncService.accessibilityEvent(event[PACKAGE_NAME], event[ENABLED_INPUT_METHODS].toString().split(","));
  });

  service.on(GitsyncService.FORCE_SYNC).listen((event) async {
    print(GitsyncService.FORCE_SYNC);
    gitSyncService.debouncedSync(int.tryParse(event?[REPO_INDEX] ?? "null") ?? await repoManager.getInt(StorageKey.repoman_repoIndex), true);
  });

  service.on(GitsyncService.INTENT_SYNC).listen((event) async {
    print(GitsyncService.INTENT_SYNC);
    gitSyncService.debouncedSync(int.tryParse(event?[REPO_INDEX] ?? "null") ?? await repoManager.getInt(StorageKey.repoman_repoIndex));
  });

  service.on(GitsyncService.TILE_SYNC).listen((event) async {
    print(GitsyncService.TILE_SYNC);
    gitSyncService.debouncedSync(await repoManager.getInt(StorageKey.repoman_tileSyncIndex), true);
  });

  service.on(GitsyncService.MERGE).listen((event) async {
    print(GitsyncService.MERGE);
    gitSyncService.merge(
      int.tryParse(event?[REPO_INDEX] ?? "null") ?? await repoManager.getInt(StorageKey.repoman_repoIndex),
      event?[COMMIT_MESSAGE],
    );
  });

  service.on("stop").listen((event) async {
    await repoManager.setStringList(StorageKey.repoman_locks, []);
    gitSyncService.refreshUi();
    service.stopSelf();
  });

  if (service is AndroidServiceInstance) {
    service.on(SET_AS_FOREGROUND).listen((event) {
      service.setAsForegroundService();
    });

    service.on(SET_AS_BACKGROUND).listen((event) {
      service.setAsBackgroundService();
    });
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: repoManager.getStringNullable(StorageKey.repoman_appLocale),
      builder:
          (context, appLocaleSnapshot) => MaterialApp(
            title: appName,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: [LocaleNamesLocalizationsDelegate(), ...AppLocalizations.localizationsDelegates],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: appLocaleSnapshot.data == null ? null : Locale(appLocaleSnapshot.data!),
            initialRoute: "/",
            localeResolutionCallback: (locale, supportedLocales) {
              for (var supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale?.languageCode) {
                  return supportedLocale;
                }
              }
              return const Locale('en');
            },
            theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: primaryDark), useMaterial3: true),
            home: ShowCaseWidget(blurValue: 3, builder: (context) => MyHomePage(title: appName, setState: setState)),
          ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.setState});

  final String title;
  final void Function(VoidCallback) setState;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  bool repoSettingsExpanded = false;
  bool demoConflicting = false;
  bool? previousLocked;
  bool showCheck = false;
  double opacity = 0.0;
  Timer? hideCheckTimer;
  StreamSubscription<List<ConnectivityResult>>? networkSubscription;

  final syncMethodsDropdownKey = GlobalKey();
  final syncMethodMainButtonKey = GlobalKey();
  final _globalSettingsKey = GlobalKey();
  final _syncProgressKey = GlobalKey();
  final _addMoreKey = GlobalKey();
  final _controlKey = GlobalKey();
  final _configKey = GlobalKey();
  final _autoSyncOptionsKey = GlobalKey();

  @override
  void initState() {
    showCheck = false;
    opacity = 0.0;

    AccessibilityServiceHelper.init(context, setState);
    WidgetsBinding.instance.addObserver(this);

    // TODO: Make sure this is commented for release
    // if (demo) {
    //   repoManager.storage.deleteAll();
    //   uiSettingsManager.storage.deleteAll();
    // }

    // TODO: Make sure this is commented for release
    // repoManager.set(StorageKey.repoman_hasStorePremium, false);
    // repoManager.set(StorageKey.repoman_hasGHSponsorPremium, false);
    // repoManager.set(StorageKey.repoman_hasEnhancedScheduledSync, false);
    // uiSettingsManager.set(StorageKey.setman_schedule, "never|");

    // TODO: Make sure this is commented for release
    // Logger.logError(LogType.TEST, "test", StackTrace.fromString("test stack"));
    // Future.delayed(Duration(seconds: 5), () => Logger.logError(LogType.TEST, "test", StackTrace.fromString("test stack")));

    premiumManager.hasPremiumNotifier.addListener(() async {
      if (premiumManager.hasPremiumNotifier.value == false) {
        await premiumManager.cullNonPremium();
      }
      setState(() {});
    });

    FlutterBackgroundService().on(GitsyncService.REFRESH).listen((event) async {
      await Logger.dismissError(context);
      setState(() {});
    });

    FlutterBackgroundService().on(GitsyncService.MERGE_COMPLETE).listen((event) async {
      Navigator.of(context).canPop() ? Navigator.pop(context) : null;
      await Logger.dismissError(context);
      setState(() {});
    });

    networkSubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) => setState(() {}));

    initAsync(() async {
      // TODO: Commented for release
      // await repoManager.setInt(StorageKey.repoman_onboardingStep, 0);

      if (await repoManager.hasLegacySettings()) {
        if (!mounted) return;
        await LegacyAppUserDialog.showDialog(context, () => onboardingController?.show());
        return;
      }
      final step = await repoManager.getInt(StorageKey.repoman_onboardingStep);
      if (step != -1) {
        onboardingController?.show();
      }
    });

    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    Logger.dismissError(context);

    onboardingController = OnboardingController(context, showAuthDialog, showCloneRepoPage, [
      _globalSettingsKey,
      _syncProgressKey,
      _addMoreKey,
      _controlKey,
      _configKey,
      _autoSyncOptionsKey,
    ]);
  }

  Future<void> addRepo() async {
    repoSettingsExpanded = false;
    setState(() {});

    AddContainerDialog.showDialog(context, (text) async {
      List<String> repomanReponames = List.from(await repoManager.getStringList(StorageKey.repoman_repoNames));

      if (repomanReponames.contains(text)) {
        text = "${text}_alt";
      }

      repomanReponames = [...repomanReponames, text];

      await repoManager.setStringList(StorageKey.repoman_repoNames, repomanReponames);
      await repoManager.setInt(StorageKey.repoman_repoIndex, repomanReponames.indexOf(text));
      await uiSettingsManager.reinit();

      setState(() {});
    });
  }

  Future<bool> isAuthenticated() async {
    final provider = await uiSettingsManager.getGitProvider();
    return provider == GitProvider.SSH
        ? (await uiSettingsManager.getGitSshAuthCredentials()).$2.isNotEmpty
        : (await uiSettingsManager.getGitHttpAuthCredentials()).$2.isNotEmpty;
    // if (authenticated) {
    //   await uiSettingsManager.setOnboardingStep(3);
    //   await onboardingController?.dismissAll();
    // }
  }

  Future<Map<String, (IconData, Future<void> Function())>> getSyncOptions() async {
    final repomanRepoindex = await repoManager.getInt(StorageKey.repoman_repoIndex);
    Map<String, (IconData, Future<void> Function())> syncOptions = {};

    if ((await GitManager.getConflicting()).isEmpty) {
      syncOptions.addAll({
        AppLocalizations.of(context).syncNow: (
          FontAwesomeIcons.solidCircleDown,
          () async {
            FlutterBackgroundService().invoke(GitsyncService.FORCE_SYNC);
          },
        ),
        AppLocalizations.of(context).manualSync: (
          FontAwesomeIcons.listCheck,
          () async {
            ManualSyncDialog.showDialog(context);
          },
        ),
        AppLocalizations.of(context).pushChanges: (
          FontAwesomeIcons.angleUp,
          () async {
            final result = await GitManager.uploadChanges(repomanRepoindex, uiSettingsManager, () async {
              if (await uiSettingsManager.getBool(StorageKey.setman_syncMessageEnabled)) {
                Fluttertoast.showToast(msg: AppLocalizations.of(context).syncStartPush, toastLength: Toast.LENGTH_LONG, gravity: null);
              }
            });
            if (result == null) return;

            if (result == false) {
              Fluttertoast.showToast(msg: AppLocalizations.of(context).syncNotRequired, toastLength: Toast.LENGTH_LONG, gravity: null);
              return;
            }

            if (await uiSettingsManager.getBool(StorageKey.setman_syncMessageEnabled)) {
              Fluttertoast.showToast(msg: AppLocalizations.of(context).syncComplete, toastLength: Toast.LENGTH_LONG, gravity: null);
            }
          },
        ),
        AppLocalizations.of(context).pullChanges: (
          FontAwesomeIcons.angleDown,
          () async {
            final result = await GitManager.downloadChanges(repomanRepoindex, uiSettingsManager, () async {
              if (await uiSettingsManager.getBool(StorageKey.setman_syncMessageEnabled)) {
                Fluttertoast.showToast(msg: AppLocalizations.of(context).syncStartPull, toastLength: Toast.LENGTH_LONG, gravity: null);
              }
            });
            if (result == null) return;

            if (result == false) {
              Fluttertoast.showToast(msg: AppLocalizations.of(context).pullFailed, toastLength: Toast.LENGTH_LONG, gravity: null);
              return;
            }

            if (await uiSettingsManager.getBool(StorageKey.setman_syncMessageEnabled)) {
              Fluttertoast.showToast(msg: AppLocalizations.of(context).syncComplete, toastLength: Toast.LENGTH_LONG, gravity: null);
            }
          },
        ),
      });
    }

    syncOptions.addAll({
      AppLocalizations.of(context).forcePush: (
        FontAwesomeIcons.anglesUp,
        () async {
          ConfirmForcePushPullDialog.showDialog(context, push: true, () async {
            ForcePushPullDialog.showDialog(context, push: true);
            await GitManager.forcePush();
            await GitManager.forcePull();
            Navigator.of(context).canPop() ? Navigator.pop(context) : null;
            setState(() {});
          });
        },
      ),
      AppLocalizations.of(context).forcePull: (
        FontAwesomeIcons.anglesDown,
        () async {
          ConfirmForcePushPullDialog.showDialog(context, () async {
            ForcePushPullDialog.showDialog(context);
            await GitManager.forcePull();
            Navigator.of(context).canPop() ? Navigator.pop(context) : null;
            setState(() {});
          });
        },
      ),
    });

    return syncOptions;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    premiumManager.dispose();

    networkSubscription?.cancel();
    hideCheckTimer?.cancel();
    for (var key in debounceTimers.keys) {
      if (key.startsWith(iosFolderAccessDebounceReference)) {
        cancelDebounce(key, true);
      }
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await Logger.dismissError(context);
      setState(() {});
    }
    if (state == AppLifecycleState.paused) {
      // if (uiSettingsManager.getOnboardingStep() != 0 && onboardingController?.hasSkipped == false) {
      //   onboardingController?.dismissAll();
      // }
    }
  }

  Future<void> showAuthDialog([Function(BaseAlertDialog dialog, {bool cancelable})? showDialog]) async {
    if (AuthDialog.authDialogKey.currentContext != null) {
      Navigator.of(context).canPop() ? Navigator.pop(context) : null;
    }

    return AuthDialog.showDialog(context, () async {
      setState(() {});
      if ((await uiSettingsManager.getString(StorageKey.setman_authorEmail)).isEmpty ||
          (await uiSettingsManager.getString(StorageKey.setman_authorName)).isEmpty) {
        await AuthorDetailsPromptDialog.showDialog(
          context,
          () async {
            await Navigator.of(context).push(createSettingsMainRoute());
          },
          () async {
            await onboardingController?.show();
          },
        );
        return;
      }
      if (await repoManager.getInt(StorageKey.repoman_onboardingStep) == -1) {
        showCloneRepoPage();
      } else {
        onboardingController?.show();
      }
    });
  }

  Future<void> showCloneRepoPage() async {
    Navigator.of(context).push(createCloneRepoMainRoute()).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        actionsPadding: EdgeInsets.only(bottom: spaceXXS),
        actions: [
          CustomShowcase(
            globalKey: _globalSettingsKey,
            description: AppLocalizations.of(context).globalSettingsHint,
            cornerRadius: cornerRadiusMax,
            first: true,
            child: IconButton(
              padding: EdgeInsets.zero,
              style: ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              constraints: BoxConstraints(),
              onPressed: () async {
                await Navigator.of(context).push(createGlobalSettingsMainRoute());
                widget.setState(() {});
              },
              icon: FaIcon(FontAwesomeIcons.gear, color: tertiaryDark, size: spaceMD + 7),
            ),
          ),
          SizedBox(width: spaceSM),
          FutureBuilder(
            future: GitManager.isLocked(),
            builder: (context, snapshot) {
              final locked = snapshot.data ?? false;

              if (previousLocked == true && locked == false) {
                showCheck = true;
                Future.delayed(Duration(milliseconds: 10), () {
                  opacity = 1.0;
                  setState(() {});
                });
                hideCheckTimer?.cancel();
                hideCheckTimer = Timer(Duration(seconds: 2), () {
                  showCheck = false;
                  opacity = 0.0;
                  setState(() {});
                });
              } else if (locked == true) {
                showCheck = false;
                hideCheckTimer?.cancel();
              }

              previousLocked = locked;

              return Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: CustomShowcase(
                      globalKey: _syncProgressKey,
                      description: AppLocalizations.of(context).syncProgressHint,
                      cornerRadius: cornerRadiusMax,
                      child: Container(
                        width: spaceMD + spaceXS,
                        height: spaceMD + spaceXS,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: tertiaryDark, width: 4)),
                      ),
                    ),
                  ),

                  if (locked)
                    Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: spaceMD + spaceXS,
                        height: spaceMD + spaceXS,
                        child: CircularProgressIndicator(
                          color: primaryLight,
                          padding: EdgeInsets.zero,
                          strokeAlign: BorderSide.strokeAlignInside,
                          strokeWidth: 4.2,
                        ),
                      ),
                    ),
                  AnimatedOpacity(
                    opacity: locked ? 0 : opacity,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    child: Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: spaceMD + spaceXS,
                        height: spaceMD + spaceXS,
                        child: FaIcon(FontAwesomeIcons.solidCircleCheck, color: primaryPositive, size: spaceMD + spaceXS),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(width: spaceSM),
          CustomShowcase(
            globalKey: _addMoreKey,
            description: AppLocalizations.of(context).addMoreHint,
            cornerRadius: cornerRadiusMax,
            customTooltipActions: [
              TooltipActionButton(
                backgroundColor: secondaryInfo,
                textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: textSM, color: primaryLight),
                leadIcon: ActionButtonIcon(icon: Icon(FontAwesomeIcons.solidFileLines, color: primaryLight, size: textSM)),
                name: AppLocalizations.of(context).learnMore.toUpperCase(),
                onTap: () => launchUrl(Uri.parse(multiRepoDocsLink)),
                type: null,
              ),
            ],
            child: FutureBuilder(
              future: repoManager.getStringList(StorageKey.repoman_repoNames),
              builder:
                  (context, repoNamesSnapshot) => Container(
                    padding: EdgeInsets.zero,
                    decoration: BoxDecoration(color: tertiaryDark, borderRadius: BorderRadius.all(cornerRadiusMax)),
                    child: FutureBuilder(
                      future: repoManager.getInt(StorageKey.repoman_repoIndex),
                      builder:
                          (context, repoIndexSnapshot) =>
                              repoNamesSnapshot.data == null
                                  ? SizedBox.shrink()
                                  : Row(
                                    children: [
                                      SizedBox(width: spaceXXXS),
                                      TextButton(
                                        style: ButtonStyle(
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          minimumSize: WidgetStatePropertyAll(Size.zero),
                                          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceXS, vertical: spaceXS)),
                                        ),
                                        onPressed: () async {
                                          if (premiumManager.hasPremiumNotifier.value != true) {
                                            await UnlockPremiumDialog.showDialog(context, () {
                                              setState(() {});
                                              addRepo();
                                            });
                                            setState(() {});
                                            return;
                                          }

                                          if (repoNamesSnapshot.data!.length == 1 || repoSettingsExpanded) {
                                            addRepo();
                                            return;
                                          }

                                          repoSettingsExpanded = !repoSettingsExpanded;
                                          setState(() {});

                                          if (repoSettingsExpanded) {
                                            Future.delayed(
                                              Duration(seconds: 5),
                                              () => setState(() {
                                                repoSettingsExpanded = false;
                                              }),
                                            );
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            ValueListenableBuilder(
                                              valueListenable: premiumManager.hasPremiumNotifier,
                                              builder:
                                                  (context, hasPremium, child) => FaIcon(
                                                    hasPremium == true
                                                        ? (repoNamesSnapshot.data!.length == 1 || repoSettingsExpanded
                                                            ? FontAwesomeIcons.solidSquarePlus
                                                            : FontAwesomeIcons.ellipsis)
                                                        : FontAwesomeIcons.solidGem,
                                                    color:
                                                        repoNamesSnapshot.data!.length == 1 || repoSettingsExpanded
                                                            ? tertiaryPositive
                                                            : secondaryLight,
                                                    size: textLG,
                                                  ),
                                            ),
                                            repoNamesSnapshot.data!.length != 1
                                                ? SizedBox.shrink()
                                                : Padding(
                                                  padding: EdgeInsets.only(left: spaceSM),
                                                  child: Text(
                                                    AppLocalizations.of(context).addMore.toUpperCase(),
                                                    style: TextStyle(color: primaryLight, fontSize: textSM, fontWeight: FontWeight.w900),
                                                  ),
                                                ),
                                          ],
                                        ),
                                      ),
                                      repoNamesSnapshot.data!.length > 1 && repoSettingsExpanded
                                          ? Row(
                                            children: [
                                              IconButton(
                                                style: ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                                constraints: BoxConstraints(),
                                                onPressed: () {
                                                  repoSettingsExpanded = false;
                                                  setState(() {});

                                                  RemoveContainerDialog.showDialog(context, (deleteContents) async {
                                                    if (deleteContents) {
                                                      await GitManager.deleteDirContents();
                                                    }

                                                    await uiSettingsManager.clearAll();

                                                    final repomanReponames = await repoManager.getStringList(StorageKey.repoman_repoNames);
                                                    repomanReponames.removeAt(await repoManager.getInt(StorageKey.repoman_repoIndex));

                                                    repoManager.setStringList(StorageKey.repoman_repoNames, repomanReponames);

                                                    if (await repoManager.getInt(StorageKey.repoman_repoIndex) >= repomanReponames.length) {
                                                      await repoManager.setInt(StorageKey.repoman_repoIndex, repomanReponames.length - 1);
                                                    }

                                                    if (await repoManager.getInt(StorageKey.repoman_tileSyncIndex) >= repomanReponames.length) {
                                                      await repoManager.setInt(StorageKey.repoman_tileSyncIndex, repomanReponames.length - 1);
                                                    }

                                                    if (await repoManager.getInt(StorageKey.repoman_tileManualSyncIndex) >= repomanReponames.length) {
                                                      await repoManager.setInt(StorageKey.repoman_tileManualSyncIndex, repomanReponames.length - 1);
                                                    }

                                                    await uiSettingsManager.reinit();
                                                    setState(() {});
                                                  });
                                                },
                                                icon: FaIcon(FontAwesomeIcons.solidSquareMinus, color: tertiaryNegative, size: textLG),
                                              ),
                                              IconButton(
                                                style: ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                                constraints: BoxConstraints(),
                                                onPressed: () {
                                                  repoSettingsExpanded = false;
                                                  setState(() {});

                                                  if (repoNamesSnapshot.data == null || repoIndexSnapshot.data == null) return;

                                                  RenameContainerDialog.showDialog(
                                                    context,
                                                    repoNamesSnapshot.data![repoIndexSnapshot.data!].toLowerCase(),
                                                    (text) async {
                                                      if (text.isEmpty) return;

                                                      final repomanReponames = await repoManager.getStringList(StorageKey.repoman_repoNames);
                                                      uiSettingsManager.renameNamespace(text);
                                                      repomanReponames[await repoManager.getInt(StorageKey.repoman_repoIndex)] = text;

                                                      await repoManager.setStringList(StorageKey.repoman_repoNames, repomanReponames);
                                                      setState(() {});
                                                    },
                                                  );
                                                },
                                                icon: FaIcon(FontAwesomeIcons.squarePen, color: tertiaryInfo, size: textLG),
                                              ),
                                            ],
                                          )
                                          : SizedBox.shrink(),
                                      SizedBox(width: spaceXXXS),
                                      ...repoNamesSnapshot.data!.length > 1
                                          ? [
                                            SizedBox(width: spaceXXXS),
                                            DropdownButton(
                                              borderRadius: BorderRadius.all(cornerRadiusMD),
                                              padding: EdgeInsets.zero,
                                              icon: Padding(
                                                padding: EdgeInsets.symmetric(horizontal: spaceSM),
                                                child: FaIcon(FontAwesomeIcons.caretDown, color: secondaryLight, size: textSM),
                                              ),
                                              value: repoIndexSnapshot.data ?? 0,
                                              style: const TextStyle(color: tertiaryLight, fontWeight: FontWeight.w900, fontSize: textMD),
                                              isDense: true,
                                              underline: const SizedBox.shrink(),
                                              dropdownColor: secondaryDark,
                                              onChanged: (value) async {
                                                if (value == null) return;

                                                await repoManager.setInt(StorageKey.repoman_repoIndex, value);
                                                await uiSettingsManager.reinit();

                                                setState(() {});
                                              },
                                              items:
                                                  List.generate(
                                                    (repoNamesSnapshot.data!.length),
                                                    (index) => DropdownMenuItem(
                                                      value: index,
                                                      child: Row(
                                                        children: [
                                                          Text(
                                                            repoNamesSnapshot.data![index].toUpperCase(),
                                                            style: TextStyle(fontSize: textXS, color: primaryLight),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ).toList(),
                                            ),
                                          ]
                                          : [SizedBox.shrink()],
                                    ],
                                  ),
                    ),
                  ),
            ),
          ),
          SizedBox(width: spaceMD),
        ],
        title: Padding(
          padding: EdgeInsets.only(left: spaceMD, bottom: spaceXXS),
          child: Text(widget.title, textAlign: TextAlign.right, style: TextStyle(color: primaryLight, fontWeight: FontWeight.bold)),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spaceMD),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              CustomShowcase(
                globalKey: _controlKey,
                cornerRadius: cornerRadiusMD,
                description: AppLocalizations.of(context).controlHint,
                child: FutureBuilder(
                  future: GitManager.getRecentCommits(),
                  builder:
                      (context, recentCommitsSnapshot) => FutureBuilder(
                        future: GitManager.getConflicting(),
                        builder: (context, conflictingSnapshot) {
                          final items = [
                            ...((conflictingSnapshot.data == null || conflictingSnapshot.data!.isEmpty)
                                ? <GitManagerRs.Commit>[]
                                : [
                                  GitManagerRs.Commit(
                                    timestamp: 0,
                                    author: "",
                                    reference: mergeConflictReference,
                                    commitMessage: "",
                                    additions: 0,
                                    deletions: 0,
                                  ),
                                ]),
                            ...recentCommitsSnapshot.data ?? <GitManagerRs.Commit>[],
                          ];

                          if (demoConflicting) {
                            while (items.length < 3) {
                              items.add(
                                GitManagerRs.Commit(
                                  timestamp: 0,
                                  author: "",
                                  reference: "REFERENCE${Random().nextInt(100)}",
                                  commitMessage: "",
                                  additions: 0,
                                  deletions: 0,
                                ),
                              );
                            }
                            items[2] = GitManagerRs.Commit(
                              timestamp: 0,
                              author: "",
                              reference: mergeConflictReference,
                              commitMessage: "",
                              additions: 0,
                              deletions: 0,
                            );
                          }

                          return Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: secondaryDark,
                                  borderRadius: BorderRadius.only(
                                    topLeft: cornerRadiusMD,
                                    bottomLeft: cornerRadiusSM,
                                    topRight: cornerRadiusMD,
                                    bottomRight: cornerRadiusSM,
                                  ),
                                ),
                                padding: EdgeInsets.only(left: spaceSM, bottom: spaceXS, right: spaceSM, top: spaceXS),
                                child: Column(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        SizedBox(
                                          height: 220,
                                          child: ShaderMask(
                                            shaderCallback: (Rect rect) {
                                              return LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [Colors.black, Colors.transparent, Colors.transparent, Colors.transparent],
                                                stops: [0.0, 0.1, 0.9, 1.0],
                                              ).createShader(rect);
                                            },
                                            blendMode: BlendMode.dstOut,
                                            child:
                                                ((recentCommitsSnapshot.data ?? []).isEmpty &&
                                                            recentCommitsSnapshot.connectionState == ConnectionState.waiting) ||
                                                        conflictingSnapshot.data == null
                                                    ? Center(child: CircularProgressIndicator(color: tertiaryLight))
                                                    : (recentCommitsSnapshot.data!.isEmpty && conflictingSnapshot.data!.isEmpty
                                                        ? Center(
                                                          child: Text(
                                                            AppLocalizations.of(context).commitsNotFound.toUpperCase(),
                                                            style: TextStyle(color: secondaryLight, fontWeight: FontWeight.bold, fontSize: textLG),
                                                          ),
                                                        )
                                                        : Column(
                                                          children: [
                                                            Expanded(
                                                              child: AnimatedListView(
                                                                items: items,
                                                                reverse: true,
                                                                isSameItem: (a, b) => a.reference == b.reference,
                                                                itemBuilder: (BuildContext context, int index) {
                                                                  final reference = items[index].reference;

                                                                  if (reference == mergeConflictReference) {
                                                                    return ItemMergeConflict(
                                                                      key: Key(reference),
                                                                      conflictingSnapshot.data!,
                                                                      () => setState(() {}),
                                                                    );
                                                                  }

                                                                  return ItemCommit(key: Key(reference), items[index]);
                                                                },
                                                              ),
                                                            ),
                                                          ],
                                                        )),
                                          ),
                                        ),
                                        ...(recentCommitsSnapshot.data?.isNotEmpty == true &&
                                                recentCommitsSnapshot.connectionState == ConnectionState.waiting)
                                            ? [
                                              Positioned(
                                                top: -(spaceXS / 2),
                                                left: 0,
                                                right: 0,
                                                child: LinearProgressIndicator(
                                                  value: null,
                                                  backgroundColor: secondaryDark,
                                                  color: tertiaryDark,
                                                  borderRadius: BorderRadius.all(cornerRadiusMD),
                                                ),
                                              ),
                                            ]
                                            : [],
                                      ],
                                    ),
                                    SizedBox(height: spaceXS),
                                    FutureBuilder(
                                      future: GitManager.getBranchName(),
                                      builder:
                                          (context, branchNameSnapshot) => FutureBuilder(
                                            future: GitManager.getBranchNames(),
                                            builder:
                                                (context, branchNamesSnapshot) => Row(
                                                  children: [
                                                    Expanded(
                                                      child: DropdownButton(
                                                        isDense: true,
                                                        isExpanded: true,
                                                        hint: Text(
                                                          AppLocalizations.of(context).detachedHead.toUpperCase(),
                                                          style: TextStyle(fontSize: textMD, fontWeight: FontWeight.bold, color: secondaryLight),
                                                        ),
                                                        padding: EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceXS),
                                                        value:
                                                            branchNamesSnapshot.data?.contains(branchNameSnapshot.data) == true
                                                                ? branchNameSnapshot.data
                                                                : null,
                                                        menuMaxHeight: 250,
                                                        dropdownColor: secondaryDark,
                                                        borderRadius: BorderRadius.all(cornerRadiusSM),
                                                        selectedItemBuilder:
                                                            (context) => List.generate(
                                                              (branchNamesSnapshot.data ?? []).length,
                                                              (index) => Row(
                                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                                children: [
                                                                  Text(
                                                                    (branchNamesSnapshot.data ?? [])[index].toUpperCase(),
                                                                    style: TextStyle(
                                                                      fontSize: textMD,
                                                                      fontWeight: FontWeight.bold,
                                                                      color:
                                                                          !(conflictingSnapshot.data == null || conflictingSnapshot.data!.isEmpty)
                                                                              ? tertiaryLight
                                                                              : primaryLight,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                        underline: const SizedBox.shrink(),
                                                        onChanged:
                                                            !(conflictingSnapshot.data == null || conflictingSnapshot.data!.isEmpty)
                                                                ? null
                                                                : <String>(value) async {
                                                                  if (value == branchNameSnapshot.data) return;

                                                                  await ConfirmBranchCheckoutDialog.showDialog(context, value, () async {
                                                                    await GitManager.checkoutBranch(value);
                                                                  });
                                                                  setState(() {});
                                                                },
                                                        items:
                                                            (branchNamesSnapshot.data ?? [])
                                                                .map(
                                                                  (item) => DropdownMenuItem(
                                                                    value: item,
                                                                    child: Text(
                                                                      item.toUpperCase(),
                                                                      style: TextStyle(
                                                                        fontSize: textSM,
                                                                        color: primaryLight,
                                                                        fontWeight: FontWeight.bold,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                )
                                                                .toList(),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      onPressed:
                                                          branchNamesSnapshot.data?.contains(branchNameSnapshot.data) == true
                                                              ? () {
                                                                CreateBranchDialog.showDialog(context, (branchName, basedOn) async {
                                                                  await GitManager.createBranch(branchName, basedOn);
                                                                  setState(() {});
                                                                });
                                                              }
                                                              : null,
                                                      style: ButtonStyle(
                                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                        backgroundColor: WidgetStatePropertyAll(secondaryDark),
                                                        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceXS)),
                                                        shape: WidgetStatePropertyAll(
                                                          RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.all(cornerRadiusSM),
                                                            side: BorderSide.none,
                                                          ),
                                                        ),
                                                      ),
                                                      constraints: BoxConstraints(),
                                                      icon: FaIcon(
                                                        FontAwesomeIcons.solidSquarePlus,
                                                        color:
                                                            branchNamesSnapshot.data?.contains(branchNameSnapshot.data) == true
                                                                ? primaryLight
                                                                : secondaryLight,
                                                        size: textXL,
                                                        semanticLabel: AppLocalizations.of(context).addBranchLabel,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: spaceSM),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: FutureBuilder(
                                        future: getSyncOptions(),
                                        builder:
                                            (context, syncOptionsSnapshot) => FutureBuilder(
                                              future: uiSettingsManager.getString(StorageKey.setman_lastSyncMethod),
                                              builder:
                                                  (context, lastSyncMethodSnapshot) => Stack(
                                                    children: [
                                                      Positioned.fill(
                                                        child: TextButton.icon(
                                                          key: syncMethodMainButtonKey,
                                                          onPressed: () async {
                                                            if (syncOptionsSnapshot.data == null || lastSyncMethodSnapshot.data == null) return;

                                                            if (syncOptionsSnapshot.data?.containsKey(lastSyncMethodSnapshot.data) == true) {
                                                              syncOptionsSnapshot.data![lastSyncMethodSnapshot.data]!.$2();
                                                            } else {
                                                              syncOptionsSnapshot.data?.values.first.$2();
                                                            }
                                                          },
                                                          style: ButtonStyle(
                                                            alignment: Alignment.centerLeft,
                                                            backgroundColor: WidgetStatePropertyAll(secondaryDark),
                                                            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceMD)),
                                                            shape: WidgetStatePropertyAll(
                                                              RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.only(
                                                                  topLeft: cornerRadiusSM,
                                                                  topRight: cornerRadiusSM,
                                                                  bottomLeft: cornerRadiusMD,
                                                                  bottomRight: cornerRadiusSM,
                                                                ),
                                                                side: BorderSide.none,
                                                              ),
                                                            ),
                                                          ),
                                                          icon: FaIcon(
                                                            syncOptionsSnapshot.data?[lastSyncMethodSnapshot.data]?.$1 ??
                                                                syncOptionsSnapshot.data?.values.first.$1 ??
                                                                FontAwesomeIcons.solidCircleDown,
                                                            color: primaryLight,
                                                            size: textLG,
                                                          ),
                                                          label: Padding(
                                                            padding: EdgeInsets.only(left: spaceXS),
                                                            child: Text(
                                                              ((syncOptionsSnapshot.data?.containsKey(lastSyncMethodSnapshot.data) == true
                                                                          ? lastSyncMethodSnapshot.data
                                                                          : syncOptionsSnapshot.data?.keys.first) ??
                                                                      AppLocalizations.of(context).syncNow)
                                                                  .toUpperCase(),
                                                              style: TextStyle(color: primaryLight, fontSize: textMD, fontWeight: FontWeight.bold),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        left: 0,
                                                        right: 0,
                                                        top: spaceMD * 4,
                                                        child: Container(
                                                          decoration: BoxDecoration(borderRadius: BorderRadius.all(cornerRadiusSM)),
                                                          margin: EdgeInsets.only(left: spaceMD),
                                                          child: DropdownButton(
                                                            key: syncMethodsDropdownKey,
                                                            borderRadius: BorderRadius.all(cornerRadiusSM),
                                                            selectedItemBuilder:
                                                                (context) =>
                                                                    List.generate(syncOptionsSnapshot.data?.length ?? 0, (_) => SizedBox.shrink()),
                                                            icon: SizedBox.shrink(),
                                                            underline: const SizedBox.shrink(),
                                                            dropdownColor: secondaryDark,
                                                            padding: EdgeInsets.zero,
                                                            onChanged: (value) {},
                                                            items:
                                                                (syncOptionsSnapshot.data ?? {}).entries
                                                                    .where(
                                                                      (item) =>
                                                                          item.key !=
                                                                          (syncOptionsSnapshot.data?.containsKey(lastSyncMethodSnapshot.data) == true
                                                                              ? lastSyncMethodSnapshot.data
                                                                              : syncOptionsSnapshot.data?.keys.first),
                                                                    )
                                                                    .map(
                                                                      (item) => DropdownMenuItem(
                                                                        onTap: () async {
                                                                          await uiSettingsManager.setString(
                                                                            StorageKey.setman_lastSyncMethod,
                                                                            item.key,
                                                                          );
                                                                          await item.value.$2();
                                                                          setState(() {});
                                                                        },
                                                                        value: item.key,
                                                                        child: Row(
                                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                                          children: [
                                                                            FaIcon(item.value.$1, color: primaryLight, size: textLG),
                                                                            SizedBox(width: spaceMD),
                                                                            Text(
                                                                              item.key.toUpperCase(),
                                                                              style: TextStyle(
                                                                                fontSize: textMD,
                                                                                color: primaryLight,
                                                                                fontWeight: FontWeight.bold,
                                                                                overflow: TextOverflow.ellipsis,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    )
                                                                    .toList(),
                                                          ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        right: 0,
                                                        top: 0,
                                                        bottom: 0,
                                                        child: IconButton(
                                                          onPressed: () {
                                                            if (demo) {
                                                              demoConflicting = true;
                                                              setState(() {});
                                                              MergeConflictDialog.showDialog(context, ["Readme.md"])
                                                                  .then((_) {
                                                                    demoConflicting = false;
                                                                    setState(() {});
                                                                  })
                                                                  .then((_) => setState(() {}));

                                                              return;
                                                            }

                                                            GestureDetector? detector;

                                                            void searchForGestureDetector(BuildContext? element) {
                                                              element?.visitChildElements((element) {
                                                                if (element.widget is GestureDetector) {
                                                                  detector = element.widget as GestureDetector;
                                                                  return;
                                                                } else {
                                                                  searchForGestureDetector(element);
                                                                }

                                                                return;
                                                              });
                                                            }

                                                            searchForGestureDetector(syncMethodsDropdownKey.currentContext);

                                                            detector?.onTap!();
                                                          },
                                                          style: ButtonStyle(
                                                            backgroundColor: WidgetStatePropertyAll(secondaryDark),
                                                            padding: WidgetStatePropertyAll(
                                                              EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceMD),
                                                            ),
                                                            shape: WidgetStatePropertyAll(
                                                              RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.all(cornerRadiusSM),
                                                                side: BorderSide.none,
                                                              ),
                                                            ),
                                                          ),
                                                          icon: FaIcon(
                                                            FontAwesomeIcons.ellipsis,
                                                            color: primaryLight,
                                                            size: textLG,
                                                            semanticLabel: AppLocalizations.of(context).moreSyncOptionsLabel,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: spaceSM),
                                    IconButton(
                                      onPressed: () {
                                        Navigator.of(context).push(createSettingsMainRoute()).then((_) => setState(() {}));
                                      },
                                      style: ButtonStyle(
                                        backgroundColor: WidgetStatePropertyAll(secondaryDark),
                                        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceMD)),
                                        shape: WidgetStatePropertyAll(
                                          RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusSM), side: BorderSide.none),
                                        ),
                                      ),
                                      icon: FaIcon(
                                        FontAwesomeIcons.gear,
                                        color: primaryLight,
                                        size: textLG,
                                        semanticLabel: AppLocalizations.of(context).repositorySettingsLabel,
                                      ),
                                    ),
                                    SizedBox(width: spaceSM),
                                    FutureBuilder(
                                      future: uiSettingsManager.getBool(StorageKey.setman_syncMessageEnabled),
                                      builder:
                                          (context, snapshot) => IconButton(
                                            onPressed: () async {
                                              if (!(snapshot.data ?? false)) {
                                                if (!(await Permission.notification.request().isGranted)) return;
                                              }

                                              uiSettingsManager.setBool(StorageKey.setman_syncMessageEnabled, !(snapshot.data ?? false));
                                              setState(() {});
                                            },
                                            style: ButtonStyle(
                                              backgroundColor: WidgetStatePropertyAll(secondaryDark),
                                              padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceMD)),
                                              shape: WidgetStatePropertyAll(
                                                RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.only(
                                                    topLeft: cornerRadiusSM,
                                                    topRight: cornerRadiusSM,
                                                    bottomLeft: cornerRadiusSM,
                                                    bottomRight: cornerRadiusMD,
                                                  ),
                                                  side: BorderSide.none,
                                                ),
                                              ),
                                            ),
                                            icon: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                FaIcon(FontAwesomeIcons.solidBellSlash, color: Colors.transparent, size: textLG - 2),
                                                FaIcon(
                                                  demo || snapshot.data == true ? FontAwesomeIcons.solidBell : FontAwesomeIcons.solidBellSlash,
                                                  color: demo || snapshot.data == true ? primaryPositive : primaryLight,
                                                  size: textLG - 2,
                                                  semanticLabel: AppLocalizations.of(context).syncMessagesLabel,
                                                ),
                                              ],
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                ),
              ),
              SizedBox(height: spaceLG),
              CustomShowcase(
                cornerRadius: cornerRadiusMD,
                globalKey: _configKey,
                description: AppLocalizations.of(context).configHint,
                child: FutureBuilder(
                  future: uiSettingsManager.getGitDirPath(true),
                  builder:
                      (context, gitDirPathSnapshot) => FutureBuilder(
                        future: isAuthenticated(),
                        builder:
                            (context, isAuthenticatedSnapshot) => Column(
                              children: [
                                IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      FutureBuilder(
                                        future: GitManager.getRemoteUrlLink(),
                                        builder:
                                            (context, snapshot) => Expanded(
                                              child: TextButton.icon(
                                                onPressed:
                                                    demo
                                                        ? () {
                                                          ManualSyncDialog.showDialog(context);
                                                        }
                                                        : (snapshot.data == null ? null : () => launchUrl(Uri.parse(snapshot.data!.$2))),
                                                style: ButtonStyle(
                                                  alignment: Alignment.centerLeft,
                                                  backgroundColor: WidgetStatePropertyAll(secondaryDark),
                                                  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceMD)),
                                                  shape: WidgetStatePropertyAll(
                                                    RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusMD), side: BorderSide.none),
                                                  ),
                                                ),
                                                icon: Padding(
                                                  padding: EdgeInsets.only(left: spaceMD),
                                                  child: FaIcon(
                                                    snapshot.data != null ? FontAwesomeIcons.squareArrowUpRight : FontAwesomeIcons.solidCircleXmark,
                                                    color: snapshot.data != null ? primaryPositive : primaryNegative,
                                                    size: textLG,
                                                  ),
                                                ),
                                                iconAlignment: IconAlignment.end,
                                                label: SizedBox.expand(
                                                  child: ExtendedText(
                                                    demo
                                                        ? "https://github.com/ViscousTests/TestObsidianVault.git"
                                                        : (snapshot.data == null ? AppLocalizations.of(context).repoNotFound : snapshot.data!.$1),
                                                    maxLines: 1,
                                                    textAlign: TextAlign.left,
                                                    softWrap: false,
                                                    overflowWidget: TextOverflowWidget(
                                                      position: TextOverflowPosition.start,
                                                      child: Text(
                                                        "…",
                                                        style: TextStyle(color: tertiaryLight, fontSize: textMD, fontWeight: FontWeight.w400),
                                                      ),
                                                    ),
                                                    style: TextStyle(
                                                      color: snapshot.data != null ? primaryLight : secondaryLight,
                                                      fontSize: textMD,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                      ),
                                      SizedBox(width: gitDirPathSnapshot.data == null ? spaceSM : 0),
                                      Visibility(
                                        visible: gitDirPathSnapshot.data == null,
                                        child: IconButton(
                                          onPressed:
                                              isAuthenticatedSnapshot.data == true
                                                  ? () async {
                                                    await showCloneRepoPage();
                                                  }
                                                  : null,
                                          style: ButtonStyle(
                                            backgroundColor: WidgetStatePropertyAll(secondaryDark),
                                            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceMD)),
                                            shape: WidgetStatePropertyAll(
                                              RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusMD), side: BorderSide.none),
                                            ),
                                          ),
                                          icon: FaIcon(
                                            FontAwesomeIcons.cloudArrowDown,
                                            color: isAuthenticatedSnapshot.data == true ? primaryLight : tertiaryLight,
                                            size: textLG - 2,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: spaceSM),
                                      TextButton.icon(
                                        onPressed: () async {
                                          await showAuthDialog();
                                        },
                                        style: ButtonStyle(
                                          alignment: Alignment.centerLeft,
                                          backgroundColor: WidgetStatePropertyAll(secondaryDark),
                                          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceMD)),
                                          shape: WidgetStatePropertyAll(
                                            RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusMD), side: BorderSide.none),
                                          ),
                                        ),
                                        icon: FaIcon(
                                          isAuthenticatedSnapshot.data == true
                                              ? FontAwesomeIcons.solidCircleCheck
                                              : FontAwesomeIcons.solidCircleXmark,
                                          color: isAuthenticatedSnapshot.data == true ? primaryPositive : primaryNegative,
                                          size: textLG,
                                        ),
                                        label: Padding(
                                          padding: EdgeInsets.only(left: spaceXS),
                                          child: Text(
                                            AppLocalizations.of(context).auth.toUpperCase(),
                                            style: TextStyle(color: primaryLight, fontSize: textMD, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: spaceMD),
                                IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: secondaryDark,
                                            borderRadius: BorderRadius.only(
                                              bottomLeft: cornerRadiusMD,
                                              bottomRight: cornerRadiusSM,
                                              topLeft: cornerRadiusMD,
                                              topRight: cornerRadiusSM,
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Padding(
                                                  padding: EdgeInsets.all(spaceMD),
                                                  child: ExtendedText(
                                                    demo
                                                        ? (Platform.isIOS
                                                            ? "TestObsidianVault"
                                                            : "/storage/emulated/0/github/ViscousTests/TestObsidianVault")
                                                        : (gitDirPathSnapshot.data == null
                                                            ? AppLocalizations.of(context).repoNotFound
                                                            : (Platform.isIOS ? gitDirPathSnapshot.data?.split("/").last : gitDirPathSnapshot.data) ??
                                                                ""),
                                                    maxLines: 1,
                                                    textAlign: TextAlign.left,
                                                    softWrap: false,
                                                    overflowWidget: TextOverflowWidget(
                                                      position: TextOverflowPosition.start,
                                                      child: Text(
                                                        "…",
                                                        style: TextStyle(
                                                          color: gitDirPathSnapshot.data == null ? secondaryLight : primaryLight,
                                                          fontSize: textMD,
                                                        ),
                                                      ),
                                                    ),
                                                    style: TextStyle(
                                                      color: gitDirPathSnapshot.data == null ? secondaryLight : primaryLight,
                                                      fontSize: textMD,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              gitDirPathSnapshot.data == null
                                                  ? SizedBox.shrink()
                                                  : IconButton(
                                                    onPressed: () async {
                                                      await uiSettingsManager.setString(StorageKey.setman_gitDirPath, "");
                                                      setState(() {});
                                                    },
                                                    constraints: BoxConstraints(),
                                                    style: ButtonStyle(
                                                      backgroundColor: WidgetStatePropertyAll(secondaryDark),
                                                      padding: WidgetStatePropertyAll(EdgeInsets.all(spaceMD)),
                                                      visualDensity: VisualDensity.compact,
                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      shape: WidgetStatePropertyAll(
                                                        RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusSM), side: BorderSide.none),
                                                      ),
                                                    ),
                                                    icon: FaIcon(
                                                      FontAwesomeIcons.solidCircleXmark,
                                                      size: textLG,
                                                      color: primaryLight,
                                                      semanticLabel: AppLocalizations.of(context).deselectDirLabel,
                                                    ),
                                                  ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: spaceSM),
                                      IconButton(
                                        onPressed:
                                            isAuthenticatedSnapshot.data == true
                                                ? () async {
                                                  String? selectedDirectory;
                                                  if (await requestStoragePerm()) {
                                                    selectedDirectory = await pickDirectory();
                                                  }
                                                  if (selectedDirectory == null) return;

                                                  await uiSettingsManager.setString(StorageKey.setman_gitDirPath, selectedDirectory);
                                                  await repoManager.setOnboardingStep(4);

                                                  await onboardingController?.show();

                                                  setState(() {});
                                                }
                                                : null,
                                        style: ButtonStyle(
                                          backgroundColor: WidgetStatePropertyAll(secondaryDark),
                                          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceMD)),
                                          shape: WidgetStatePropertyAll(
                                            RoundedRectangleBorder(
                                              borderRadius: BorderRadius.only(
                                                bottomLeft: cornerRadiusSM,
                                                bottomRight: cornerRadiusMD,
                                                topLeft: cornerRadiusSM,
                                                topRight: cornerRadiusMD,
                                              ),
                                              side: BorderSide.none,
                                            ),
                                          ),
                                        ),
                                        icon: FaIcon(
                                          FontAwesomeIcons.solidFolderOpen,
                                          color: isAuthenticatedSnapshot.data == true ? primaryLight : tertiaryLight,
                                          size: textLG - 2,
                                          semanticLabel: AppLocalizations.of(context).selectDirLabel,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                      ),
                ),
              ),
              SizedBox(height: spaceLG),
              CustomShowcase(
                globalKey: _autoSyncOptionsKey,
                description: AppLocalizations.of(context).autoSyncOptionsHint,
                cornerRadius: cornerRadiusMD,
                targetPadding: EdgeInsets.all(spaceSM),
                customTooltipActions: [
                  TooltipActionButton(
                    backgroundColor: secondaryInfo,
                    textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: textSM, color: primaryLight),
                    leadIcon: ActionButtonIcon(icon: Icon(FontAwesomeIcons.solidFileLines, color: primaryLight, size: textSM)),
                    name: AppLocalizations.of(context).learnMore.toUpperCase(),
                    onTap: () => launchUrl(Uri.parse(syncOptionsBGDocsLink)),
                    type: null,
                  ),
                ],
                child: Column(
                  children: [
                    ...Platform.isIOS ? [] : [AutoSyncSettings(), SizedBox(height: spaceMD)],
                    ScheduledSyncSettings(),
                    SizedBox(height: spaceMD),
                    ...Platform.isIOS ? [] : [TileSyncSettings(), SizedBox(height: spaceMD)],
                    TextButton.icon(
                      onPressed: () async {
                        launchUrl(Uri.parse(syncOptionsDocsLink));
                      },
                      iconAlignment: IconAlignment.end,
                      style: ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceLG, vertical: spaceMD)),
                        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusMD), side: BorderSide.none)),
                        backgroundColor: WidgetStatePropertyAll(secondaryDark),
                      ),
                      icon: FaIcon(FontAwesomeIcons.squareArrowUpRight, color: primaryLight, size: textXL),
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(
                          AppLocalizations.of(context).otherSyncSettings,
                          style: TextStyle(fontFeatures: [FontFeature.enable('smcp')], color: primaryLight, fontSize: textLG),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spaceMD),
            ],
          ),
        ),
      ),
      bottomNavigationBar: FutureBuilder(
        future: hasNetworkConnection(),
        builder:
            (context, snapshot) =>
                snapshot.data == false
                    ? Container(
                      decoration: BoxDecoration(color: tertiaryNegative),
                      padding: EdgeInsets.symmetric(vertical: spaceXXS, horizontal: spaceSM),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: AppLocalizations.of(context).youreOffline, style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: AppLocalizations.of(context).someFeaturesMayNotWork),
                          ],
                        ),
                      ),
                    )
                    : SizedBox.shrink(),
      ),
    );
  }
}
