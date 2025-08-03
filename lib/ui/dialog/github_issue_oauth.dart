import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../ui/dialog/base_alert_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Future<void> showDialog(BuildContext context, Future<void> Function() collectOauth) {
  return mat.showDialog(
    context: context,
    builder:
        (BuildContext context) => BaseAlertDialog(
          backgroundColor: secondaryDark,
          title: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Text(
              AppLocalizations.of(context).githubIssueOauthTitle,
              style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold),
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(
                  AppLocalizations.of(context).githubIssueOauthMsg,
                  style: const TextStyle(color: primaryLight, fontWeight: FontWeight.bold, fontSize: textSM),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).cancel.toUpperCase(), style: TextStyle(color: primaryLight, fontSize: textMD)),
              onPressed: () async {
                Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              },
            ),
            TextButton.icon(
              icon: FaIcon(FontAwesomeIcons.squareArrowUpRight, color: secondaryDark, size: textMD),
              label: Text(
                AppLocalizations.of(context).oauth.toUpperCase(),
                style: TextStyle(color: secondaryDark, fontSize: textMD, fontWeight: FontWeight.bold),
              ),
              style: ButtonStyle(
                alignment: Alignment.center,
                backgroundColor: WidgetStatePropertyAll(primaryPositive),
                padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: spaceSM, vertical: spaceXS)),
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusMD), side: BorderSide.none)),
              ),
              onPressed: () async {
                await collectOauth();
                Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              },
            ),
          ],
        ),
  );
}
