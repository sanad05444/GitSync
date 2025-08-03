import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart';
import 'package:GitSync/constant/strings.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../ui/dialog/base_alert_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Future<void> showDialog(BuildContext context, String errorMessage) {
  return mat.showDialog(
    context: context,
    builder:
        (BuildContext context) => BaseAlertDialog(
          title: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Text(cloneFailed, style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold)),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [Text(errorMessage, style: const TextStyle(color: tertiaryNegative, fontWeight: FontWeight.bold, fontSize: textSM))],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context).cancel, style: TextStyle(color: primaryLight, fontSize: textMD)),
              onPressed: () {
                Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(context).ok, style: TextStyle(color: primaryPositive, fontSize: textMD)),
              onPressed: () async {
                Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              },
            ),
          ],
        ),
  );
}
