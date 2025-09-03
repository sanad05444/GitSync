import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import 'package:GitSync/global.dart';
import '../../../ui/dialog/base_alert_dialog.dart';

Future<void> showDialog(BuildContext context, Function callback) {
  return mat.showDialog(
    context: context,
    builder: (BuildContext context) => BaseAlertDialog(
      title: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Text(
          t.legacyAppUserDialogTitle,
          style: TextStyle(
            color: primaryLight,
            fontSize: textXL,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      content: SingleChildScrollView(
        child: ListBody(
          children: [
            Text(
              t.legacyAppUserDialogMessagePart1,
              style: const TextStyle(
                color: primaryLight,
                fontWeight: FontWeight.bold,
                fontSize: textMD,
              ),
            ),
            SizedBox(height: spaceSM),
            Text(
              t.legacyAppUserDialogMessagePart2,
              style: const TextStyle(
                color: secondaryLight,
                fontWeight: FontWeight.bold,
                fontSize: textSM,
              ),
            ),
            SizedBox(height: spaceSM),
            Text(
              t.legacyAppUserDialogMessagePart3,
              style: const TextStyle(
                color: secondaryLight,
                fontWeight: FontWeight.bold,
                fontSize: textSM,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(
            t.setUp.toUpperCase(),
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
