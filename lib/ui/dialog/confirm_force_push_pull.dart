import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../ui/dialog/base_alert_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Future<void> showDialog(BuildContext context, Function() callback, {push = false}) {
  return mat.showDialog(
    context: context,
    builder:
        (BuildContext context) => BaseAlertDialog(
          title: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Text(
              push ? AppLocalizations.of(context).confirmForcePush : AppLocalizations.of(context).confirmForcePull,
              style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold),
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(
                  push ? AppLocalizations.of(context).confirmForcePushMsg : AppLocalizations.of(context).confirmForcePullMsg,
                  style: const TextStyle(color: primaryLight, fontWeight: FontWeight.bold, fontSize: textSM),
                ),
                SizedBox(height: spaceSM),
                Text(
                  AppLocalizations.of(context).localHistoryOverwriteWarning,
                  style: const TextStyle(color: tertiaryNegative, fontWeight: FontWeight.bold, fontSize: textSM),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).cancel.toUpperCase(), style: TextStyle(color: primaryLight, fontSize: textMD)),
              onPressed: () {
                Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              },
            ),
            TextButton(
              child: Text(
                (push ? AppLocalizations.of(context).forcePush : AppLocalizations.of(context).forcePull).toUpperCase(),
                style: TextStyle(color: primaryPositive, fontSize: textMD),
              ),
              onPressed: () async {
                Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                callback();
              },
            ),
          ],
        ),
  );
}
