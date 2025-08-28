import 'dart:io';

import 'package:GitSync/constant/colors.dart';
import 'package:GitSync/constant/dimens.dart';
import 'package:GitSync/constant/strings.dart';
import 'package:GitSync/global.dart';
import 'package:GitSync/ui/component/auto_sync_settings.dart';
import 'package:GitSync/ui/component/scheduled_sync_settings.dart';
import 'package:GitSync/ui/component/tile_sync_settings.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class GroupSyncSettings extends StatelessWidget {
  const GroupSyncSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
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
            child: Text(t.otherSyncSettings, style: TextStyle(fontFeatures: [FontFeature.enable('smcp')], color: primaryLight, fontSize: textLG)),
          ),
        ),
      ],
    );
  }
}
