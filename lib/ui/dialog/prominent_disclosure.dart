import 'dart:io';

import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../ui/dialog/base_alert_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Future<void> showDialog(BuildContext context, Future<void> Function() callback) {
  if (Platform.isIOS) return Future.value();

  return mat.showDialog(
    context: context,
    builder:
        (BuildContext context) => BaseAlertDialog(
          title: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Text(
              AppLocalizations.of(context).accessibilityServiceDisclosureTitle,
              style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold),
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(
                  AppLocalizations.of(context).accessibilityServiceDisclosureMessage,
                  style: const TextStyle(color: primaryLight, fontWeight: FontWeight.bold, fontSize: textSM),
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
              child: Text(AppLocalizations.of(context).ok.toUpperCase(), style: TextStyle(color: primaryPositive, fontSize: textMD)),
              onPressed: () async {
                Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                await callback();
              },
            ),
          ],
        ),
  );
}
