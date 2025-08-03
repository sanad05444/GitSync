import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../ui/dialog/base_alert_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Future<void> showDialog(BuildContext context, Future<void> Function(String, String, String) report) {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final minimalReproController = TextEditingController();

  return mat.showDialog(
    context: context,
    barrierColor: Colors.transparent,
    builder:
        (BuildContext context) => StatefulBuilder(
          builder:
              (context, setState) => BaseAlertDialog(
                expandable: true,
                backgroundColor: secondaryDark,
                title: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: Text(
                    AppLocalizations.of(context).reportABug.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold),
                  ),
                ),
                contentBuilder:
                    (expanded) => (expanded
                        ? (List<Widget> children) => Column(children: children)
                        : (List<Widget> children) => SingleChildScrollView(child: ListBody(children: children)))([
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: spaceMD),
                            child: Text(
                              AppLocalizations.of(context).issueReportTitleTitle.toUpperCase(),
                              style: TextStyle(color: primaryLight, fontSize: textMD, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: spaceMD),
                            child: Text(
                              AppLocalizations.of(context).issueReportTitleDesc,
                              style: TextStyle(color: secondaryLight, fontSize: textSM, fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(height: spaceSM),
                          TextField(
                            controller: titleController,
                            maxLines: 1,
                            minLines: 1,
                            style: TextStyle(
                              color: primaryLight,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                              decorationThickness: 0,
                              fontSize: textMD,
                            ),
                            decoration: InputDecoration(
                              fillColor: tertiaryDark,
                              filled: true,
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(cornerRadiusMD), borderSide: BorderSide.none),
                              isCollapsed: true,
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              contentPadding: const EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceSM),
                              errorText: titleController.text.isEmpty ? AppLocalizations.of(context).fieldCannotBeEmpty : null,
                              errorStyle: TextStyle(color: tertiaryNegative),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                      SizedBox(height: spaceMD),
                      (expanded ? (child) => Expanded(child: child) : (child) => child)(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: spaceMD),
                              child: Text(
                                AppLocalizations.of(context).issueReportDescTitle.toUpperCase(),
                                style: TextStyle(color: primaryLight, fontSize: textMD, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: spaceMD),
                              child: Text(
                                AppLocalizations.of(context).issueReportDescDesc,
                                style: TextStyle(color: secondaryLight, fontSize: textSM, fontWeight: FontWeight.bold),
                              ),
                            ),
                            SizedBox(height: spaceSM),
                            (expanded ? (child) => Flexible(child: child) : (child) => child)(
                              TextField(
                                controller: descriptionController,
                                maxLines: null,
                                minLines: 3,
                                style: TextStyle(
                                  color: primaryLight,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none,
                                  decorationThickness: 0,
                                  fontSize: textMD,
                                ),

                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceSM),
                                  border: const OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(cornerRadiusMD)),
                                  errorText: descriptionController.text.isEmpty ? AppLocalizations.of(context).fieldCannotBeEmpty : null,
                                  errorStyle: TextStyle(color: tertiaryNegative),
                                  isCollapsed: true,
                                  fillColor: tertiaryDark,
                                  filled: true,
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: spaceMD),
                      (expanded ? (child) => Expanded(child: child) : (child) => child)(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: spaceMD),
                              child: Text(
                                AppLocalizations.of(context).issueReportMinimalReproTitle.toUpperCase(),
                                style: TextStyle(color: primaryLight, fontSize: textMD, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: spaceMD),
                              child: Text(
                                AppLocalizations.of(context).issueReportMinimalReproDesc,
                                style: TextStyle(color: secondaryLight, fontSize: textSM, fontWeight: FontWeight.bold),
                              ),
                            ),
                            SizedBox(height: spaceSM),
                            (expanded ? (child) => Flexible(child: child) : (child) => child)(
                              TextField(
                                controller: minimalReproController,
                                maxLines: null,
                                minLines: 3,
                                style: TextStyle(
                                  color: primaryLight,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none,
                                  decorationThickness: 0,
                                  fontSize: textMD,
                                ),

                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceSM),
                                  border: const OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(cornerRadiusMD)),
                                  isCollapsed: true,
                                  errorText: minimalReproController.text.isEmpty ? AppLocalizations.of(context).fieldCannotBeEmpty : null,
                                  errorStyle: TextStyle(color: tertiaryNegative),
                                  fillColor: tertiaryDark,
                                  filled: true,
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: spaceMD),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppLocalizations.of(context).issueReportMessage,
                            textAlign: TextAlign.end,
                            style: const TextStyle(color: secondaryLight, fontWeight: FontWeight.bold, fontSize: textSM),
                          ),
                        ],
                      ),
                    ]),
                actions: <Widget>[
                  TextButton(
                    child: Text(AppLocalizations.of(context).cancel.toUpperCase(), style: TextStyle(color: primaryLight, fontSize: textMD)),
                    onPressed: () async {
                      Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                    },
                  ),

                  TextButton.icon(
                    icon: FaIcon(
                      FontAwesomeIcons.solidPaperPlane,
                      color:
                          minimalReproController.text.isEmpty || descriptionController.text.isEmpty || titleController.text.isEmpty
                              ? tertiaryLight
                              : primaryPositive,
                      size: textMD,
                    ),
                    label: Text(
                      AppLocalizations.of(context).report.toUpperCase(),
                      style: TextStyle(
                        color:
                            minimalReproController.text.isEmpty || descriptionController.text.isEmpty || titleController.text.isEmpty
                                ? tertiaryLight
                                : primaryPositive,
                        fontSize: textMD,
                      ),
                    ),
                    onPressed:
                        minimalReproController.text.isEmpty || descriptionController.text.isEmpty || titleController.text.isEmpty
                            ? null
                            : () async {
                              Navigator.of(context).canPop() ? Navigator.pop(context) : null;
                              await report(titleController.text, descriptionController.text, minimalReproController.text);
                            },
                  ),
                ],
              ),
        ),
  );
}
