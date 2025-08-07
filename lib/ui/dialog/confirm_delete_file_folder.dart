import 'dart:io';

import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart';
import 'package:sprintf/sprintf.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../ui/dialog/base_alert_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

Future<void> showDialog(BuildContext context, List<String> selectedPaths, Future<void> Function() callback) {
  final oldPath = selectedPaths[0];
  final entity = FileSystemEntity.typeSync(oldPath);
  if (entity == FileSystemEntityType.notFound) {
    throw Exception('Path does not exist.');
  }
  String text = "Are you sure you want to delete the ${entity == FileSystemEntityType.directory ? "directory" : "file"} \"${p.basename(oldPath)}\" ";
  if (selectedPaths.length > 1) {
    text += "and ${selectedPaths.length - 1} more and their contents";
  } else {
    text += "and it's contents";
  }

  return mat.showDialog(
    context: context,
    builder:
        (BuildContext context) => BaseAlertDialog(
          title: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Text(
              AppLocalizations.of(context).confirmRepositoryDeleteTitle,
              style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold),
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(text, style: const TextStyle(color: primaryLight, fontWeight: FontWeight.bold, fontSize: textSM)),
                SizedBox(height: spaceMD),
                Text(
                  AppLocalizations.of(context).thisActionCannotBeUndone,
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
              child: Text(AppLocalizations.of(context).delete, style: TextStyle(color: tertiaryNegative, fontSize: textMD)),
              onPressed: () async {
                await callback();
                Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              },
            ),
          ],
        ),
  );
}
