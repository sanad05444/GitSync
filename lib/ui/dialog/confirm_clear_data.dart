import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../ui/dialog/base_alert_dialog.dart';
import 'package:GitSync/global.dart';

Future<void> showDialog(
  BuildContext context,
  Future<void> Function() deleteContentsCallback,
) {
  return mat.showDialog(
    context: context,
    builder: (BuildContext context) => BaseAlertDialog(
      title: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Text(
          t.clearDataConfirmTitle,
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
              t.clearDataConfirmMsg,
              style: const TextStyle(
                color: primaryLight,
                fontWeight: FontWeight.bold,
                fontSize: textSM,
              ),
            ),
            SizedBox(height: spaceSM),
            Text(
              t.confirmCloneOverwriteWarning,
              style: const TextStyle(
                color: tertiaryNegative,
                fontWeight: FontWeight.bold,
                fontSize: textSM,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          label: Text(
            t.iosClearDataAction.toUpperCase(),
            style: TextStyle(color: tertiaryNegative, fontSize: textMD),
          ),
          iconAlignment: IconAlignment.start,
          onPressed: () async {
            Navigator.of(context).canPop() ? Navigator.pop(context) : null;
            await deleteContentsCallback();
          },
        ),
        TextButton(
          child: Text(
            t.cancel.toUpperCase(),
            style: TextStyle(color: primaryLight, fontSize: textMD),
          ),
          onPressed: () {
            Navigator.of(context).canPop() ? Navigator.pop(context) : null;
          },
        ),
      ],
    ),
  );
}
