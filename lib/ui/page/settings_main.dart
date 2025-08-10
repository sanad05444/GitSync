import 'package:GitSync/api/manager/storage.dart';
import 'package:GitSync/type/git_provider.dart';
import 'package:GitSync/ui/component/button_setting.dart';
import 'package:GitSync/ui/page/global_settings_main.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../api/helper.dart';
import '../../../api/manager/git_manager.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../constant/strings.dart';
import '../../../global.dart';
import '../../../ui/component/item_setting.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:GitSync/ui/dialog/import_priv_key.dart' as ImportPrivKeyDialog;

class SettingsMain extends StatefulWidget {
  const SettingsMain({super.key});

  @override
  State<SettingsMain> createState() => _SettingsMain();
}

class _SettingsMain extends State<SettingsMain> with WidgetsBindingObserver {
  final _controller = ScrollController();
  bool atTop = true;
  String? gitDirPath;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      atTop = _controller.offset <= 0;
      setState(() {});
    });
    initAsync(() async {
      gitDirPath = await uiSettingsManager.getStringNullable(StorageKey.setman_gitDirPath);
      if (gitDirPath == "") gitDirPath = null;
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
                gitDirPath == null
                    ? SizedBox.shrink()
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: spaceMD),
                          child: Text(
                            AppLocalizations.of(context).signedCommitsLabel.toUpperCase(),
                            style: TextStyle(color: primaryLight, fontSize: textMD, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: spaceMD),
                          child: Text(
                            AppLocalizations.of(context).signedCommitsDescription,
                            style: TextStyle(color: secondaryLight, fontSize: textSM, fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(height: spaceSM),
                        FutureBuilder(
                          future: uiSettingsManager.getStringNullable(StorageKey.setman_gitCommitSigningKey),
                          builder:
                              (context, gitCommitSigningKeySnapshot) => Container(
                                width: double.infinity,
                                decoration: BoxDecoration(color: tertiaryDark, borderRadius: BorderRadius.all(cornerRadiusMD)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    gitCommitSigningKeySnapshot.data == ""
                                        ? SizedBox.shrink()
                                        : Row(
                                          children: [
                                            Expanded(
                                              child: TextButton.icon(
                                                onPressed: () async {
                                                  await ImportPrivKeyDialog.showDialog(context, ((String, String) sshCredentials) async {
                                                    await uiSettingsManager.setStringNullable(
                                                      StorageKey.setman_gitCommitSigningKey,
                                                      sshCredentials.$2,
                                                    );
                                                    await uiSettingsManager.setStringNullable(
                                                      StorageKey.setman_gitCommitSigningPassphrase,
                                                      sshCredentials.$1,
                                                    );
                                                    setState(() {});
                                                  });
                                                },
                                                style: ButtonStyle(
                                                  alignment: Alignment.centerLeft,
                                                  backgroundColor: WidgetStatePropertyAll(tertiaryDark),
                                                  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceSM)),
                                                  shape: WidgetStatePropertyAll(
                                                    RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusMD), side: BorderSide.none),
                                                  ),
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  minimumSize: WidgetStatePropertyAll(Size.zero),
                                                ),
                                                icon: FaIcon(
                                                  FontAwesomeIcons.key,
                                                  color: gitCommitSigningKeySnapshot.data?.isNotEmpty == true ? primaryPositive : primaryLight,
                                                ),
                                                label: Padding(
                                                  padding: EdgeInsets.only(left: spaceXS),
                                                  child: Text(
                                                    (gitCommitSigningKeySnapshot.data?.isNotEmpty == true
                                                            ? AppLocalizations.of(context).commitKeyImported
                                                            : AppLocalizations.of(context).importCommitKey)
                                                        .toUpperCase(),
                                                    style: TextStyle(
                                                      color: gitCommitSigningKeySnapshot.data?.isNotEmpty == true ? primaryPositive : primaryLight,
                                                      fontSize: textMD,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            gitCommitSigningKeySnapshot.data?.isNotEmpty == true
                                                ? IconButton(
                                                  padding: EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceSM),
                                                  style: ButtonStyle(
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    shape: WidgetStatePropertyAll(
                                                      RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusMD), side: BorderSide.none),
                                                    ),
                                                  ),
                                                  constraints: BoxConstraints(),
                                                  onPressed: () async {
                                                    await uiSettingsManager.setStringNullable(StorageKey.setman_gitCommitSigningPassphrase, null);
                                                    await uiSettingsManager.setStringNullable(StorageKey.setman_gitCommitSigningKey, null);
                                                    setState(() {});
                                                  },
                                                  icon: FaIcon(FontAwesomeIcons.trash, color: tertiaryNegative, size: textMD),
                                                )
                                                : SizedBox.shrink(),
                                          ],
                                        ),
                                    FutureBuilder(
                                      future: uiSettingsManager.getGitProvider(),
                                      builder:
                                          (context, snapshot) =>
                                              (gitCommitSigningKeySnapshot.data == null || gitCommitSigningKeySnapshot.data?.isEmpty == true) &&
                                                      snapshot.data == GitProvider.SSH
                                                  ? TextButton.icon(
                                                    onPressed: () async {
                                                      await uiSettingsManager.setStringNullable(
                                                        StorageKey.setman_gitCommitSigningKey,
                                                        gitCommitSigningKeySnapshot.data == null ? "" : null,
                                                      );
                                                      setState(() {});
                                                    },
                                                    style: ButtonStyle(
                                                      alignment: Alignment.centerLeft,
                                                      backgroundColor: WidgetStatePropertyAll(tertiaryDark),
                                                      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceSM)),
                                                      shape: WidgetStatePropertyAll(
                                                        RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusMD), side: BorderSide.none),
                                                      ),
                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      minimumSize: WidgetStatePropertyAll(Size.zero),
                                                    ),
                                                    iconAlignment: IconAlignment.end,
                                                    icon: FaIcon(
                                                      gitCommitSigningKeySnapshot.data != null
                                                          ? FontAwesomeIcons.solidSquareCheck
                                                          : FontAwesomeIcons.squareCheck,
                                                      color: primaryPositive,
                                                      size: textLG,
                                                    ),
                                                    label: SizedBox(
                                                      width: double.infinity,
                                                      child: Text(
                                                        AppLocalizations.of(context).useSshKey.toUpperCase(),
                                                        style: TextStyle(color: primaryLight, fontSize: textMD, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  )
                                                  : SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ),
                        ),
                      ],
                    ),
                SizedBox(height: spaceMD),
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
                ...gitDirPath == null
                    ? []
                    : [
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
                    ],
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
