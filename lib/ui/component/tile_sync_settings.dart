import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:GitSync/constant/colors.dart';
import 'package:GitSync/api/manager/storage.dart';
import 'package:GitSync/constant/dimens.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:GitSync/global.dart';

class TileSyncSettings extends StatefulWidget {
  const TileSyncSettings({super.key});

  @override
  State<TileSyncSettings> createState() => _TileSyncSettingsState();
}

class _TileSyncSettingsState extends State<TileSyncSettings> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: secondaryDark, borderRadius: BorderRadius.all(cornerRadiusMD)),
      child: FutureBuilder(
        future: uiSettingsManager.getBool(StorageKey.setman_otherSyncSettingsExpanded),
        builder:
            (context, snapshot) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () async {
                      uiSettingsManager.setBool(StorageKey.setman_otherSyncSettingsExpanded, !(snapshot.data ?? false));
                      setState(() {});
                    },
                    iconAlignment: IconAlignment.end,
                    style: ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceLG, vertical: spaceMD)),
                      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusMD), side: BorderSide.none)),
                    ),
                    icon: FaIcon(
                      (snapshot.data ?? false) ? FontAwesomeIcons.chevronUp : FontAwesomeIcons.chevronDown,
                      color: primaryLight,
                      size: textXL,
                    ),
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        AppLocalizations.of(context).tileSyncSettings,
                        style: TextStyle(fontFeatures: [FontFeature.enable('smcp')], color: primaryLight, fontSize: textLG),
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: Duration(milliseconds: 200),
                  child: SizedBox(
                    height: (snapshot.data ?? false) ? null : 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          (snapshot.data ?? false)
                              ? [
                                TextButton.icon(
                                  onPressed: () async {
                                    await repoManager.setInt(
                                      StorageKey.repoman_tileSyncIndex,
                                      await repoManager.getInt(StorageKey.repoman_repoIndex),
                                    );
                                    setState(() {});
                                  },
                                  iconAlignment: IconAlignment.end,
                                  style: ButtonStyle(
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    padding: WidgetStatePropertyAll(
                                      EdgeInsets.only(left: spaceMD + spaceXS, right: spaceLG, top: spaceMD, bottom: spaceMD),
                                    ),
                                    shape: WidgetStatePropertyAll(
                                      RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusMD), side: BorderSide.none),
                                    ),
                                  ),
                                  icon: FutureBuilder(
                                    future:
                                        (() async =>
                                            await repoManager.getInt(StorageKey.repoman_tileSyncIndex) ==
                                            await repoManager.getInt(StorageKey.repoman_repoIndex))(),
                                    builder:
                                        (context, snapshot) => FaIcon(
                                          snapshot.data == true ? FontAwesomeIcons.solidCircleCheck : FontAwesomeIcons.circle,
                                          color: snapshot.data == true ? primaryPositive : secondaryLight,
                                          size: textLG,
                                        ),
                                  ),
                                  label: SizedBox(
                                    width: double.infinity,
                                    child: Text(AppLocalizations.of(context).useForTileSync, style: TextStyle(color: primaryLight, fontSize: textMD)),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    await repoManager.setInt(
                                      StorageKey.repoman_tileManualSyncIndex,
                                      await repoManager.getInt(StorageKey.repoman_repoIndex),
                                    );
                                    setState(() {});
                                  },
                                  iconAlignment: IconAlignment.end,
                                  style: ButtonStyle(
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    padding: WidgetStatePropertyAll(
                                      EdgeInsets.only(left: spaceMD + spaceXS, right: spaceLG, top: spaceMD, bottom: spaceMD),
                                    ),
                                    shape: WidgetStatePropertyAll(
                                      RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusMD), side: BorderSide.none),
                                    ),
                                  ),
                                  icon: FutureBuilder(
                                    future:
                                        (() async =>
                                            await repoManager.getInt(StorageKey.repoman_tileManualSyncIndex) ==
                                            await repoManager.getInt(StorageKey.repoman_repoIndex))(),
                                    builder:
                                        (context, snapshot) => FaIcon(
                                          snapshot.data == true ? FontAwesomeIcons.solidCircleCheck : FontAwesomeIcons.circle,
                                          color: snapshot.data == true ? primaryPositive : secondaryLight,
                                          size: textLG,
                                        ),
                                  ),
                                  label: SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      AppLocalizations.of(context).useForTileManualSync,
                                      style: TextStyle(color: primaryLight, fontSize: textMD),
                                    ),
                                  ),
                                ),
                                // SizedBox(height: spaceSM),
                              ]
                              : [],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
