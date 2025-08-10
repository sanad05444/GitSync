import 'dart:io';

import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart';
import 'package:sprintf/sprintf.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../ui/dialog/base_alert_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

Future<void> showDialog(BuildContext context, Future<void> Function() callback) {
  return mat.showDialog(
    context: context,
    builder:
        (BuildContext context) => BaseAlertDialog(
          title: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Text("Disable SSL?", style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold)),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(
                  "The address you cloned starts with \"http\" (not secure). Disabling SSL will match the URL but reduce security.",
                  style: const TextStyle(color: primaryLight, fontWeight: FontWeight.bold, fontSize: textSM),
                ),
                SizedBox(height: spaceMD),
                Text("Proceed anyway?", style: const TextStyle(color: primaryLight, fontWeight: FontWeight.bold, fontSize: textSM)),
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
              child: Text("Disable SSL".toUpperCase(), style: TextStyle(color: tertiaryPositive, fontSize: textMD)),
              onPressed: () async {
                await callback();
                Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              },
            ),
          ],
        ),
  );
}
