import 'dart:convert';
import 'dart:io';

import 'package:GitSync/api/logger.dart';
import 'package:GitSync/api/manager/settings_manager.dart';
import 'package:GitSync/api/manager/storage.dart';
import 'package:GitSync/ui/component/button_setting.dart';
import 'package:GitSync/ui/component/custom_showcase.dart';
import 'package:archive/archive_io.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:GitSync/ui/dialog/unlock_premium.dart' as UnlockPremiumDialog;
import 'package:url_launcher/url_launcher.dart';
import '../../../api/helper.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../constant/strings.dart';
import '../../../global.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../dialog/change_language.dart' as ChangeLanguageDialog;
import '../dialog/enter_backup_restore_password.dart' as EnterBackupRestorePasswordDialog;

class GlobalSettingsMain extends StatefulWidget {
  const GlobalSettingsMain({super.key, this.onboarding = false});
  final bool onboarding;

  @override
  State<GlobalSettingsMain> createState() => _GlobalSettingsMain();
}

class _GlobalSettingsMain extends State<GlobalSettingsMain> with WidgetsBindingObserver {
  final _controller = ScrollController();
  bool atTop = true;
  final _uiSetupGuideKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      atTop = _controller.offset <= 0;
      setState(() {});
    });

    if (widget.onboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _controller.animateTo(_controller.position.maxScrollExtent, duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
        await Future.delayed(Duration(milliseconds: 200));
        ShowCaseWidget.of(context).startShowCase([_uiSetupGuideKey]);
        while (!ShowCaseWidget.of(context).isShowCaseCompleted) {
          await Future.delayed(Duration(milliseconds: 100));
        }
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: getBackButton(context, () => Navigator.of(context).canPop() ? Navigator.pop(context) : null),
        centerTitle: true,
        title: Text(AppLocalizations.of(context).globalSettings.toUpperCase(), style: TextStyle(color: primaryLight, fontWeight: FontWeight.bold)),
      ),
      body: ShaderMask(
        shaderCallback: (Rect rect) {
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [atTop ? Colors.transparent : Colors.black, Colors.transparent, Colors.transparent, Colors.transparent],
            stops: [0.0, 0.1, 0.9, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstOut,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spaceMD + spaceSM),
          child: SingleChildScrollView(
            controller: _controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                ButtonSetting(
                  text: AppLocalizations.of(context).language,
                  icon: FontAwesomeIcons.earthOceania,
                  onPressed: () async {
                    await ChangeLanguageDialog.showDialog(context, (locale) async {
                      await repoManager.setStringNullable(StorageKey.repoman_appLocale, locale);
                      Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                      setState(() {});
                      Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                    });
                  },
                ),
                SizedBox(height: spaceLG),
                // Padding(
                //   padding: EdgeInsets.only(left: spaceXS),
                //   child: Text(
                //     AppLocalizations.of(context).backupRestoreTitle,
                //     style: TextStyle(fontSize: textLG, color: primaryLight, fontWeight: FontWeight.bold),
                //   ),
                // ),
                // SizedBox(height: spaceLG),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: spaceMD),
                  child: Row(
                    children: [
                      Expanded(child: Container(color: tertiaryLight, height: spaceXXXXS, margin: EdgeInsets.only(right: spaceSM))),
                      Text(
                        AppLocalizations.of(context).backupRestoreTitle.toUpperCase(),
                        style: TextStyle(fontSize: textSM, color: primaryLight, fontWeight: FontWeight.bold),
                      ),
                      Expanded(child: Container(color: tertiaryLight, height: spaceXXXXS, margin: EdgeInsets.only(left: spaceSM))),
                    ],
                  ),
                ),
                SizedBox(height: spaceSM),
                ButtonSetting(
                  text: AppLocalizations.of(context).backup,
                  icon: FontAwesomeIcons.solidFloppyDisk,
                  onPressed: () async {
                    await EnterBackupRestorePasswordDialog.showDialog(context, true, (text) async {
                      final repoManagerSettings = await repoManager.getAll();
                      final repoCount = (await repoManager.getStringList(StorageKey.repoman_repoNames)).length;
                      final settingsManagerSettings = <Map<String, String>>[];

                      for (var i = 0; i < repoCount; i++) {
                        final settingsManager = SettingsManager();
                        settingsManager.reinit(repoIndex: i);
                        settingsManagerSettings.add(await settingsManager.getAll());
                      }

                      final Map<String, dynamic> settingsMap = {"repoManager": repoManagerSettings, "settingsManager": settingsManagerSettings};

                      await FilePicker.platform.saveFile(
                        dialogTitle: 'Select location to save backup',
                        fileName: "backup_${DateTime.now().toLocal().toString().replaceAll(":", "-")}.gsbak",
                        bytes: utf8.encode(await encryptMap(settingsMap, text)),
                      );
                    });
                  },
                ),
                SizedBox(height: spaceMD),
                ButtonSetting(
                  text: AppLocalizations.of(context).restore,
                  icon: FontAwesomeIcons.arrowRotateLeft,
                  onPressed: () async {
                    FilePickerResult? result = await FilePicker.platform.pickFiles();
                    if (result == null) return;

                    File file = File(result.files.single.path!);

                    await EnterBackupRestorePasswordDialog.showDialog(context, false, (text) async {
                      Map<String, dynamic> settingsMap = {};
                      try {
                        settingsMap = await decryptMap(file.readAsStringSync(), text);
                      } catch (e) {
                        await Fluttertoast.showToast(
                          msg: AppLocalizations.of(context).invalidPassword,
                          toastLength: Toast.LENGTH_LONG,
                          gravity: null,
                        );
                        return;
                      }

                      await repoManager.setAll(settingsMap["repoManager"]);
                      List<dynamic> settingsManagerSettings = settingsMap["settingsManager"];

                      for (var i = 0; i < settingsManagerSettings.length; i++) {
                        final settingsManager = SettingsManager();
                        settingsManager.reinit(repoIndex: i);
                        await settingsManager.setAll(settingsManagerSettings[i]);
                      }

                      Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                    });
                  },
                ),

                SizedBox(height: spaceLG),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: spaceMD),
                  child: Row(
                    children: [
                      Expanded(child: Container(color: tertiaryLight, height: spaceXXXXS, margin: EdgeInsets.only(right: spaceSM))),
                      Text("community".toUpperCase(), style: TextStyle(fontSize: textSM, color: primaryLight, fontWeight: FontWeight.bold)),
                      Expanded(child: Container(color: tertiaryLight, height: spaceXXXXS, margin: EdgeInsets.only(left: spaceSM))),
                    ],
                  ),
                ),
                SizedBox(height: spaceSM),
                ButtonSetting(
                  text: AppLocalizations.of(context).reportABug,
                  icon: FontAwesomeIcons.bug,
                  textColor: primaryDark,
                  iconColor: primaryDark,
                  buttonColor: tertiaryNegative,
                  onPressed: () async {
                    await Logger.reportIssue(context);
                  },
                ),
                SizedBox(height: spaceMD),
                ButtonSetting(
                  text: AppLocalizations.of(context).shareLogs,
                  icon: FontAwesomeIcons.envelopeOpenText,
                  loads: true,
                  onPressed: () async {
                    final dir = await getTemporaryDirectory();
                    final logsDir = Directory('${dir.path}/logs');
                    final files = !logsDir.existsSync() ? [] : logsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.log')).toList();

                    if (files.isEmpty || !logsDir.existsSync()) {
                      Fluttertoast.showToast(msg: "No log files found!", toastLength: Toast.LENGTH_SHORT, gravity: null);
                      return;
                    }

                    final zipFile = File('${dir.path}/logs.zip');

                    var encoder = ZipFileEncoder();
                    encoder.create('${dir.path}/logs.zip');

                    for (var file in files) {
                      await encoder.addFile(file);
                    }
                    await encoder.close();

                    final deviceInfo = DeviceInfoPlugin();
                    final packageInfo = await PackageInfo.fromPlatform();

                    String osVersion = '';
                    String deviceModel = '';

                    if (Platform.isIOS) {
                      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
                      osVersion = iosInfo.systemVersion;
                      deviceModel = iosInfo.utsname.machine;
                    } else {
                      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
                      osVersion = '${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
                      deviceModel = androidInfo.model;
                    }

                    String appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

                    final Email email = Email(
                      body: """

Platform: ${Platform.isIOS ? "iOS" : "Android"}
Device Model: $deviceModel
OS Version: $osVersion
App Version: $appVersion

""",
                      subject: 'GitSync Logs (${Platform.isIOS ? "iOS" : "Android"})',
                      recipients: ['bugsviscouspotential@gmail.com'],
                      attachmentPaths: [zipFile.path],
                      isHTML: false,
                    );

                    try {
                      await FlutterEmailSender.send(email);
                    } catch (e, stackStrace) {
                      Logger.logError(LogType.Global, e, stackStrace);
                    }
                  },
                ),
                SizedBox(height: spaceMD),
                ButtonSetting(
                  text: AppLocalizations.of(context).requestAFeature,
                  icon: FontAwesomeIcons.solidHandPointUp,
                  onPressed: () async {
                    if (await canLaunchUrl(Uri.parse(githubFeatureTemplate))) {
                      await launchUrl(Uri.parse(githubFeatureTemplate));
                    }
                  },
                ),
                SizedBox(height: spaceMD),
                ButtonSetting(
                  text: AppLocalizations.of(context).joinTheDiscussion,
                  icon: FontAwesomeIcons.solidComments,
                  onPressed: () async {
                    if (await canLaunchUrl(Uri.parse(githubDiscussionsLink))) {
                      await launchUrl(Uri.parse(githubDiscussionsLink));
                    }
                  },
                ),

                SizedBox(height: spaceLG),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: spaceMD),
                  child: Row(
                    children: [
                      Expanded(child: Container(color: tertiaryLight, height: spaceXXXXS, margin: EdgeInsets.only(right: spaceSM))),
                      Text("guides".toUpperCase(), style: TextStyle(fontSize: textSM, color: primaryLight, fontWeight: FontWeight.bold)),
                      Expanded(child: Container(color: tertiaryLight, height: spaceXXXXS, margin: EdgeInsets.only(left: spaceSM))),
                    ],
                  ),
                ),
                SizedBox(height: spaceSM),
                ButtonSetting(
                  text: AppLocalizations.of(context).viewDocumentation,
                  icon: FontAwesomeIcons.solidFileLines,
                  onPressed: () async {
                    launchUrl(Uri.parse(documentationLink));
                  },
                ),
                SizedBox(height: spaceMD),
                CustomShowcase(
                  globalKey: _uiSetupGuideKey,
                  description: AppLocalizations.of(context).guidedSetupHint,
                  last: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ButtonSetting(
                        text: AppLocalizations.of(context).guidedSetup,
                        icon: FontAwesomeIcons.chalkboardUser,
                        onPressed: () async {
                          await repoManager.setInt(StorageKey.repoman_onboardingStep, 0);
                          Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                          await onboardingController?.show();
                        },
                      ),
                      SizedBox(height: spaceMD),
                      ButtonSetting(
                        text: AppLocalizations.of(context).uiGuide,
                        icon: FontAwesomeIcons.route,
                        onPressed: () async {
                          await repoManager.setInt(StorageKey.repoman_onboardingStep, 4);
                          Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                          await onboardingController?.show();
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: spaceLG + spaceMD),

                ValueListenableBuilder(
                  valueListenable: premiumManager.hasPremiumNotifier,
                  builder:
                      (context, hasPremium, child) => ButtonSetting(
                        text:
                            (hasPremium == true ? AppLocalizations.of(context).contributeTitle : AppLocalizations.of(context).premiumDialogTitle)
                                .toUpperCase(),
                        icon: hasPremium == true ? FontAwesomeIcons.circleDollarToSlot : FontAwesomeIcons.solidGem,
                        iconColor: tertiaryPositive,
                        onPressed: () async {
                          if (hasPremium == true) {
                            await launchUrl(Uri.parse(contributeLink));
                          } else {
                            await UnlockPremiumDialog.showDialog(context, () => setState(() {}));
                            setState(() {});
                          }
                        },
                      ),
                ),
                SizedBox(height: spaceMD),
                ButtonSetting(
                  text: AppLocalizations.of(context).viewPrivacyPolicy,
                  icon: FontAwesomeIcons.userShield,
                  onPressed: () async {
                    launchUrl(Uri.parse(privacyPolicyLink));
                  },
                ),
                SizedBox(height: spaceMD),
                ButtonSetting(
                  text: AppLocalizations.of(context).viewEula,
                  icon: FontAwesomeIcons.fileContract,
                  onPressed: () async {
                    launchUrl(Uri.parse(eulaLink));
                  },
                ),

                SizedBox(height: spaceLG),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Route createGlobalSettingsMainRoute({bool onboarding = false}) {
  return PageRouteBuilder(
    settings: const RouteSettings(name: settings_main),
    pageBuilder: (context, animation, secondaryAnimation) => ShowCaseWidget(builder: (context) => GlobalSettingsMain(onboarding: onboarding)),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.ease;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
