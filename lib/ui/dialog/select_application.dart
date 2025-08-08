import 'package:GitSync/api/manager/storage.dart';
import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:GitSync/api/accessibility_service_helper.dart';
import 'package:GitSync/api/helper.dart';
import 'package:GitSync/constant/strings.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../global.dart';
import '../../../ui/dialog/base_alert_dialog.dart';
import 'package:async/async.dart';

Future<void> showDialog(BuildContext parentContext, Set<String>? prevSelectedApplications) async {
  final List<String> selectedApplications = prevSelectedApplications?.toList() ?? [];
  final searchController = TextEditingController();

  return await mat.showDialog(
    context: parentContext,
    builder:
        (BuildContext context) => BaseAlertDialog(
          title: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Text(
              t.selectApplication.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(color: primaryLight, fontSize: textXL, fontWeight: FontWeight.bold),
            ),
          ),
          content: StatefulBuilder(
            builder:
                (BuildContext context, setState) => SingleChildScrollView(
                  child: ListBody(
                    children: [
                      TextField(
                        controller: searchController,
                        maxLines: 1,
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
                          label: Text(t.search.toUpperCase(), style: TextStyle(color: secondaryLight, fontSize: textSM, fontWeight: FontWeight.bold)),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          contentPadding: const EdgeInsets.symmetric(horizontal: spaceMD, vertical: spaceSM),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          debounce(selectApplicationSearchReference, 100, () {
                            setState(() {});
                          });
                        },
                      ),
                      SizedBox(height: spaceMD),
                      FutureBuilder(
                        future: AsyncMemoizer().runOnce(() => AccessibilityServiceHelper.getDeviceApplications(searchController.text)),
                        builder: (context, deviceAppsSnapshot) {
                          final packageNames = <String>{...selectedApplications, ...deviceAppsSnapshot.data ?? []}.toList();

                          return SizedBox(
                            width: double.maxFinite,
                            height: MediaQuery.of(context).size.height / 3,
                            child:
                                deviceAppsSnapshot.data == null
                                    ? Center(child: CircularProgressIndicator(color: tertiaryLight))
                                    : GridView.builder(
                                      shrinkWrap: true,
                                      itemCount: packageNames.length,
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: spaceMD,
                                        mainAxisSpacing: spaceMD,
                                      ),
                                      itemBuilder: (BuildContext context, int index) {
                                        final packageName = packageNames[index];
                                        return Stack(
                                          key: Key(packageName),
                                          children: [
                                            TextButton(
                                              onPressed: () {
                                                if (selectedApplications.contains(packageName)) {
                                                  selectedApplications.remove(packageName);
                                                } else {
                                                  selectedApplications.add(packageName);
                                                }
                                                setState(() {});
                                              },
                                              style: ButtonStyle(
                                                alignment: Alignment.centerLeft,
                                                backgroundColor: WidgetStatePropertyAll(tertiaryDark),
                                                padding: WidgetStatePropertyAll(EdgeInsets.all(spaceSM)),
                                                shape: WidgetStatePropertyAll(
                                                  RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusMD), side: BorderSide.none),
                                                ),
                                              ),
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    SizedBox(
                                                      height: textXXL,
                                                      width: textXXL,
                                                      child: FutureBuilder(
                                                        future: AsyncMemoizer().runOnce(
                                                          () async => AccessibilityServiceHelper.getApplicationIcon(packageName),
                                                        ),
                                                        builder:
                                                            (context, snapshot) =>
                                                                snapshot.data == null
                                                                    ? CircularProgressIndicator(color: tertiaryLight)
                                                                    : Image.memory(
                                                                      height: textXXL,
                                                                      width: textXXL,
                                                                      gaplessPlayback: true,
                                                                      snapshot.data!,
                                                                    ),
                                                      ),
                                                    ),
                                                    SizedBox(height: spaceSM),
                                                    FutureBuilder(
                                                      future: AsyncMemoizer().runOnce(
                                                        () async => AccessibilityServiceHelper.getApplicationLabel(packageName),
                                                      ),
                                                      // future: AccessibilityServiceHelper.getApplicationLabel(packageName),
                                                      builder:
                                                          (context, snapshot) => Text(
                                                            (snapshot.data ?? "").toUpperCase(),
                                                            textAlign: TextAlign.center,
                                                            style: TextStyle(color: primaryLight, fontSize: textSM, fontWeight: FontWeight.bold),
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            ...selectedApplications.contains(packageName)
                                                ? [
                                                  Positioned(
                                                    top: spaceSM,
                                                    right: spaceSM,
                                                    child: FaIcon(FontAwesomeIcons.solidCircleCheck, color: primaryPositive, size: textXL),
                                                  ),
                                                ]
                                                : [],
                                          ],
                                        );
                                      },
                                    ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(t.cancel.toUpperCase(), style: TextStyle(color: primaryLight, fontSize: textMD)),
              onPressed: () {
                Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              },
            ),
            TextButton(
              child: Text(t.saveApplication.toUpperCase(), style: TextStyle(color: primaryPositive, fontSize: textMD)),
              onPressed: () async {
                uiSettingsManager.setStringList(StorageKey.setman_packageNames, selectedApplications);
                Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              },
            ),
          ],
        ),
  );
}
