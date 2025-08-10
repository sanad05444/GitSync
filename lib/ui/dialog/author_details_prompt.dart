import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../ui/dialog/base_alert_dialog.dart';
import 'package:GitSync/global.dart';

Future<void> showDialog(BuildContext context, Future<void> Function() successCallback, Future<void> Function() callback) {
  return mat.showDialog(
    context: context,
    builder:
        (BuildContext context) => BaseAlertDialog(
          title: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Text(t.authorDetailsPromptTitle, style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold)),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(t.authorDetailsPromptMessage, style: const TextStyle(color: primaryLight, fontWeight: FontWeight.bold, fontSize: textSM)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(t.dismiss, style: TextStyle(color: primaryLight, fontSize: textMD)),
              onPressed: () async {
                Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                await callback();
              },
            ),
            TextButton(
              child: Text(t.goToSettings, style: TextStyle(color: primaryPositive, fontSize: textMD)),
              onPressed: () async {
                Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                await successCallback();
                await callback();
              },
            ),
          ],
        ),
  );
}
