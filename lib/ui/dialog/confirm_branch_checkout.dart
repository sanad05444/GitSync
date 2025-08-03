import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../ui/dialog/base_alert_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Future<void> showDialog(BuildContext context, String branchName, Future<void> Function() callback) {
  bool loading = false;

  return mat.showDialog(
    context: context,
    builder:
        (BuildContext context) => StatefulBuilder(
          builder:
              (context, setState) => BaseAlertDialog(
                title: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: Text(
                    AppLocalizations.of(context).confirmBranchCheckoutTitle,
                    style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold),
                  ),
                ),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(color: primaryLight, fontWeight: FontWeight.bold, fontSize: textSM),
                          children: [
                            TextSpan(text: AppLocalizations.of(context).confirmBranchCheckoutMsgPart1),
                            TextSpan(text: "[$branchName]", style: TextStyle(color: tertiaryInfo)),
                            TextSpan(text: AppLocalizations.of(context).confirmBranchCheckoutMsgPart2),
                          ],
                        ),
                      ),
                      SizedBox(height: spaceSM),
                      Text(
                        AppLocalizations.of(context).unsavedChangesMayBeLost,
                        style: const TextStyle(color: tertiaryNegative, fontWeight: FontWeight.bold, fontSize: textSM),
                      ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text(
                      AppLocalizations.of(context).cancel.toUpperCase(),
                      style: TextStyle(color: primaryLight, fontSize: textMD, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                    },
                  ),
                  TextButton.icon(
                    label: Text(
                      AppLocalizations.of(context).checkout.toUpperCase(),
                      style: TextStyle(color: primaryPositive, fontSize: textMD, fontWeight: FontWeight.bold),
                    ),
                    iconAlignment: IconAlignment.end,
                    icon:
                        loading
                            ? SizedBox(height: spaceMD, width: spaceMD, child: CircularProgressIndicator(color: primaryPositive))
                            : SizedBox.shrink(),
                    onPressed: () async {
                      loading = true;
                      setState(() {});
                      await callback();
                      loading = false;
                      setState(() {});
                      Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                    },
                  ),
                ],
              ),
        ),
  );
}
