import 'dart:io';

import 'package:GitSync/api/manager/storage.dart';
import 'package:GitSync/ui/component/button_setting.dart';
import 'package:GitSync/ui/component/custom_showcase.dart';
import 'package:GitSync/ui/page/global_settings_main.dart';
import 'package:archive/archive_io.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:GitSync/api/logger.dart';
import 'package:GitSync/ui/dialog/unlock_premium.dart' as UnlockPremiumDialog;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../api/helper.dart';
import '../../../api/manager/git_manager.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../constant/strings.dart';
import '../../../global.dart';
import '../../../ui/component/item_setting.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsMain extends StatefulWidget {
  const SettingsMain({super.key});

  @override
  State<SettingsMain> createState() => _SettingsMain();
}

class _SettingsMain extends State<SettingsMain> with WidgetsBindingObserver {
  final _controller = ScrollController();
  bool atTop = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      atTop = _controller.offset <= 0;
      setState(() {});
    });
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
        title: Text(AppLocalizations.of(context).settings.toUpperCase(), style: TextStyle(color: primaryLight, fontWeight: FontWeight.bold)),
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
                ItemSetting(
                  setFn: (value) => uiSettingsManager.setString(StorageKey.setman_syncMessage, value),
                  getFn: () => uiSettingsManager.getString(StorageKey.setman_syncMessage),
                  title: AppLocalizations.of(context).syncMessageLabel,
                  description: AppLocalizations.of(context).syncMessageDescription,
                  hint: syncMessage,
                  maxLines: null,
                  minLines: null,
                ),
                SizedBox(height: spaceMD),
                ItemSetting(
                  setFn: (value) => uiSettingsManager.setString(StorageKey.setman_syncMessageTimeFormat, value),
                  getFn: () => uiSettingsManager.getString(StorageKey.setman_syncMessageTimeFormat),
                  title: AppLocalizations.of(context).syncMessageTimeFormatLabel,
                  description: AppLocalizations.of(context).syncMessageTimeFormatDescription,
                  hint: syncMessageTimeFormat,
                ),
                SizedBox(height: spaceLG),
                ItemSetting(
                  setFn: (value) => uiSettingsManager.setString(StorageKey.setman_authorName, value.trim()),
                  getFn: demo ? () async => "" : () => uiSettingsManager.getString(StorageKey.setman_authorName),
                  title: AppLocalizations.of(context).authorNameLabel,
                  hint: AppLocalizations.of(context).authorName,
                ),
                SizedBox(height: spaceMD),
                ItemSetting(
                  setFn: (value) => uiSettingsManager.setString(StorageKey.setman_authorEmail, value.trim()),
                  getFn: demo ? () async => "" : () => uiSettingsManager.getString(StorageKey.setman_authorEmail),
                  title: AppLocalizations.of(context).authorEmailLabel,
                  hint: AppLocalizations.of(context).authorEmail,
                ),
                SizedBox(height: spaceLG),
                ItemSetting(
                  setFn: (value) => uiSettingsManager.setString(StorageKey.setman_remote, value),
                  getFn: () => uiSettingsManager.getString(StorageKey.setman_remote),
                  title: AppLocalizations.of(context).remoteLabel,
                  hint: AppLocalizations.of(context).defaultRemote,
                ),
                SizedBox(height: spaceLG),
                ItemSetting(
                  setFn: GitManager.writeGitignore,
                  getFn: demo ? () async => "" : GitManager.readGitignore,
                  title: AppLocalizations.of(context).gitIgnore,
                  description: AppLocalizations.of(context).gitIgnoreDescription,
                  hint: AppLocalizations.of(context).gitIgnoreHint,
                  maxLines: -1,
                  minLines: -1,
                  isTextArea: true,
                ),
                SizedBox(height: spaceMD),
                ItemSetting(
                  setFn: GitManager.writeGitInfoExclude,
                  getFn: demo ? () async => "" : GitManager.readGitInfoExclude,
                  title: AppLocalizations.of(context).gitInfoExclude,
                  description: AppLocalizations.of(context).gitInfoExcludeDescription,
                  hint: AppLocalizations.of(context).gitInfoExcludeHint,
                  maxLines: -1,
                  minLines: -1,
                  isTextArea: true,
                ),
                SizedBox(height: spaceSM),
                FutureBuilder(
                  future: GitManager.getDisableSsl(),
                  builder:
                      (context, snapshot) => TextButton.icon(
                        onPressed: () async {
                          await GitManager.setDisableSsl(!(snapshot.data ?? false));
                          setState(() {});
                        },
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(
                            AppLocalizations.of(context).disableSsl.toUpperCase(),
                            style: TextStyle(color: primaryLight, fontSize: textMD, fontWeight: FontWeight.bold),
                          ),
                        ),
                        iconAlignment: IconAlignment.end,
                        icon: FaIcon(
                          snapshot.data == true ? FontAwesomeIcons.solidSquareCheck : FontAwesomeIcons.squareCheck,
                          color: primaryPositive,
                          size: textLG,
                        ),
                      ),
                ),
                SizedBox(height: spaceMD),
                ButtonSetting(
                  text: AppLocalizations.of(context).moreOptions,
                  icon: FontAwesomeIcons.ellipsisVertical,
                  onPressed: () async {
                    Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                    await Navigator.of(context).push(createGlobalSettingsMainRoute());
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

Route createSettingsMainRoute() {
  return PageRouteBuilder(
    settings: const RouteSettings(name: settings_main),
    pageBuilder: (context, animation, secondaryAnimation) => SettingsMain(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.ease;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
