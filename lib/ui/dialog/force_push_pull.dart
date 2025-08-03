import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../ui/dialog/base_alert_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Future<void> showDialog(BuildContext context, {push = false}) async {
  return mat.showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (BuildContext context) => PopScope(
          child: BaseAlertDialog(
            title: Row(
              mainAxisAlignment: mat.MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  push ? AppLocalizations.of(context).forcePushing : AppLocalizations.of(context).forcePulling,
                  style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold),
                ),
                SizedBox(
                  height: textXL,
                  width: textXL,
                  child: Center(
                    child: CircularProgressIndicator(
                      backgroundColor: secondaryLight,
                      color: primaryPositive,
                      semanticsLabel:
                          push ? AppLocalizations.of(context).forcePushProgressLabel : AppLocalizations.of(context).forcePullProgressLabel,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: ListBody(
                children: [
                  Text(
                    AppLocalizations.of(context).forcePushPullMessage,
                    style: const TextStyle(color: tertiaryNegative, fontSize: textMD, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: spaceMD),
                ],
              ),
            ),
            actions: null,
          ),
        ),
  );
}
