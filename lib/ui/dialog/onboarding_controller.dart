import 'dart:io';
import 'package:GitSync/ui/page/global_settings_main.dart';
import 'package:GitSync/ui/page/settings_main.dart';
import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:GitSync/api/manager/storage.dart';
import 'package:GitSync/api/accessibility_service_helper.dart';
import 'package:GitSync/api/helper.dart';
import 'package:GitSync/constant/colors.dart';
import 'package:GitSync/constant/dimens.dart';
import 'package:GitSync/constant/strings.dart';
import 'package:GitSync/global.dart';
import 'package:GitSync/ui/dialog/base_alert_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:GitSync/ui/dialog/prominent_disclosure.dart' as ProminentDisclosureDialog;

class OnboardingController {
  final BuildContext context;
  final Future<void> Function() showAuthDialog;
  final Future<void> Function() showCloneRepoPage;
  final List<GlobalKey> showCaseKeys;
  bool hasSkipped = false;
  final GlobalKey _currentDialog = GlobalKey();

  OnboardingController(this.context, this.showAuthDialog, this.showCloneRepoPage, this.showCaseKeys);

  void _showDialog(BaseAlertDialog dialog, {bool cancelable = true}) {
    mat.showDialog(context: context, builder: (BuildContext context) => dialog, barrierDismissible: cancelable);
  }

  Future<void> show() async {
    switch (await repoManager.getInt(StorageKey.repoman_onboardingStep)) {
      case 0:
        await welcomeDialog();
      case 1:
        await showAlmostThereOrSkip();
      case 2:
        await authDialog();
      case 3:
        await showCloneRepoPage();
      case 4:
        await repoManager.setOnboardingStep(4);
        ShowCaseWidget.of(context).startShowCase(showCaseKeys);
        while (!ShowCaseWidget.of(context).isShowCaseCompleted) {
          await Future.delayed(Duration(milliseconds: 100));
        }
        await Navigator.of(context).push(createGlobalSettingsMainRoute(onboarding: true));
        await repoManager.setOnboardingStep(-1);
    }
  }

  Future<void> dismissAll() async {
    if (_currentDialog.currentContext != null) {
      Navigator.of(context).canPop() ? Navigator.pop(context) : null;
    }
  }

  Future<void> authDialog() async {
    _showDialog(
      BaseAlertDialog(
        key: _currentDialog,
        title: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Text(
            AppLocalizations.of(context).authDialogTitle,
            style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold),
          ),
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(
                AppLocalizations.of(context).authDialogMessage,
                style: const TextStyle(color: primaryLight, fontWeight: FontWeight.bold, fontSize: textSM),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: <Widget>[
          TextButton(
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceXS)),
            ),
            child: Text(AppLocalizations.of(context).skip.toUpperCase(), style: TextStyle(color: secondaryLight, fontSize: textSM)),
            onPressed: () async {
              Navigator.of(context).canPop() ? Navigator.pop(context) : null;
            },
          ),
          TextButton(
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceXS)),
            ),
            child: Text(AppLocalizations.of(context).ok.toUpperCase(), style: TextStyle(color: primaryPositive, fontSize: textSM)),
            onPressed: () async {
              Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              await showAuthDialog();
            },
          ),
        ],
      ),
      cancelable: false,
    );
  }

  Future<void> almostThereDialog() async {
    _showDialog(
      BaseAlertDialog(
        key: _currentDialog,
        title: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Text(
            AppLocalizations.of(context).almostThereDialogTitle,
            style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold),
          ),
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(
                Platform.isAndroid
                    ? AppLocalizations.of(context).almostThereDialogMessageAndroid
                    : AppLocalizations.of(context).almostThereDialogMessageIos,
                style: const TextStyle(color: primaryLight, fontWeight: FontWeight.bold, fontSize: textSM),
              ),
              SizedBox(height: spaceMD),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      launchUrl(Uri.parse(documentationLink));
                    },
                    style: ButtonStyle(
                      alignment: Alignment.center,
                      backgroundColor: WidgetStatePropertyAll(tertiaryInfo),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusSM), side: BorderSide.none)),
                    ),
                    icon: FaIcon(FontAwesomeIcons.solidFileLines, color: secondaryDark, size: textSM),
                    // icon:
                    label: Text(
                      AppLocalizations.of(context).documentation.toUpperCase(),
                      style: TextStyle(color: primaryDark, fontSize: textSM, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: <Widget>[
          TextButton(
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceXS)),
            ),
            child: Text(AppLocalizations.of(context).cancel.toUpperCase(), style: TextStyle(color: secondaryLight, fontSize: textSM)),
            onPressed: () async {
              Navigator.of(context).canPop() ? Navigator.pop(context) : null;
            },
          ),
          TextButton(
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceXS)),
            ),
            child: Text(AppLocalizations.of(context).ok.toUpperCase(), style: TextStyle(color: primaryPositive, fontSize: textSM)),
            onPressed: () async {
              await repoManager.setOnboardingStep(2);
              Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              await authDialog();
            },
          ),
        ],
      ),
    );
  }

  Future<void> showAlmostThereOrSkip() async {
    await repoManager.setOnboardingStep(1);
    if (hasSkipped) return;
    await almostThereDialog();
  }

  Future<void> enableAllFilesDialog([bool standalone = false]) async {
    _showDialog(
      BaseAlertDialog(
        key: _currentDialog,
        title: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Text(
            AppLocalizations.of(context).allFilesAccessDialogTitle,
            style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold),
          ),
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(
                AppLocalizations.of(context).allFilesAccessDialogMessage,
                style: const TextStyle(color: primaryLight, fontWeight: FontWeight.bold, fontSize: textSM),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: <Widget>[
          FutureBuilder(
            future: requestStoragePerm(false),
            builder:
                (context, snapshot) => TextButton(
                  style: ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceXS)),
                  ),
                  child: Text(
                    (snapshot.data == true ? AppLocalizations.of(context).done : AppLocalizations.of(context).ok).toUpperCase(),
                    style: TextStyle(color: primaryPositive, fontSize: textSM),
                  ),
                  onPressed: () async {
                    if (await requestStoragePerm()) {
                      Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                      await showAlmostThereOrSkip();
                    }
                  },
                ),
          ),
        ],
      ),
    );
  }

  Future<bool> showAllFilesAccessOrNext([bool standalone = false]) async {
    if (!(Platform.isIOS || await requestStoragePerm(false))) {
      await enableAllFilesDialog(standalone);
      return true;
    }

    if (standalone) return false;

    await showAlmostThereOrSkip();
    return false;
  }

  Future<void> enableNotificationsDialog() async {
    _showDialog(
      BaseAlertDialog(
        key: _currentDialog,
        title: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Text(
            AppLocalizations.of(context).notificationDialogTitle,
            style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold),
          ),
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(
                AppLocalizations.of(context).notificationDialogMessage,
                style: const TextStyle(color: primaryLight, fontWeight: FontWeight.bold, fontSize: textSM),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: <Widget>[
          TextButton(
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceXS)),
            ),
            child: Text(AppLocalizations.of(context).skip.toUpperCase(), style: TextStyle(color: secondaryLight, fontSize: textSM)),
            onPressed: () async {
              Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              await showAllFilesAccessOrNext();
            },
          ),
          FutureBuilder(
            future: Permission.notification.isGranted,
            builder:
                (context, snapshot) => TextButton(
                  style: ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceXS)),
                  ),
                  child: Text(
                    (snapshot.data == true ? AppLocalizations.of(context).done : AppLocalizations.of(context).ok).toUpperCase(),
                    style: TextStyle(color: primaryPositive, fontSize: textSM),
                  ),
                  onPressed: () async {
                    if (await Permission.notification.request().isGranted) {
                      Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                      await showAllFilesAccessOrNext();
                    }
                  },
                ),
          ),
        ],
      ),
    );
  }

  Future<bool> showNotificationsOrNext() async {
    if (!await Permission.notification.isGranted) {
      await enableNotificationsDialog();
      return true;
    } else {
      return await showAllFilesAccessOrNext();
    }
  }

  Future<void> welcomeDialog() async {
    _showDialog(
      BaseAlertDialog(
        key: _currentDialog,
        title: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Text(AppLocalizations.of(context).welcome, style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold)),
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(
                AppLocalizations.of(context).welcomeMessage,
                style: const TextStyle(color: primaryLight, fontWeight: FontWeight.bold, fontSize: textSM),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: <Widget>[
          TextButton(
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceXS)),
            ),
            child: Text(AppLocalizations.of(context).welcomeNeutral.toUpperCase(), style: TextStyle(color: secondaryLight, fontSize: textSM)),
            onPressed: () async {
              hasSkipped = true;
              Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              await showNotificationsOrNext();
            },
          ),
          TextButton(
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceXS)),
            ),
            child: Text(AppLocalizations.of(context).welcomeNegative.toUpperCase(), style: TextStyle(color: secondaryLight, fontSize: textSM)),
            onPressed: () async {
              hasSkipped = true;
              await repoManager.setOnboardingStep(-1);
              Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              await showNotificationsOrNext();
            },
          ),
          TextButton(
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceXS)),
            ),
            child: Text(AppLocalizations.of(context).welcomePositive.toUpperCase(), style: TextStyle(color: primaryPositive, fontSize: textSM)),
            onPressed: () async {
              Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              await showNotificationsOrNext();
            },
          ),
        ],
      ),
    );
  }
}
