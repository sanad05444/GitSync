import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart' as mat;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:GitSync/api/manager/git_manager.dart';
import 'package:GitSync/api/manager/storage.dart';
import 'package:GitSync/constant/strings.dart';
import 'package:GitSync/global.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../ui/dialog/base_alert_dialog.dart';
import 'package:GitSync/ui/dialog/confirm_discard_changes.dart'
    as ConfirmDiscardChangesDialog;

Future<void> showDialog(BuildContext context) {
  final syncMessageController = TextEditingController();
  final selectedFiles = <String>[];

  if (demo) {
    selectedFiles.add("storage/external/example/file_changed.md");
  }

  bool uploading = false;

  return mat.showDialog(
    context: context,
    barrierColor: Colors.transparent,
    builder: (BuildContext context) => PopScope(
      canPop: !uploading,
      child: StatefulBuilder(
        builder: (context, setState) {
          SystemChannels.lifecycle.setMessageHandler((msg) async {
            if (msg == appLifecycleStateResumed) {
              try {
                setState(() {});
              } catch (e) {
                /**/
              }

              return null;
            }
            return msg;
          });
          return FutureBuilder(
            future: GitManager.getUncommittedFilePaths(),
            builder: (context, snapshot) => BaseAlertDialog(
              expandable: true,
              title: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Text(
                  t.manualSync.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: primaryLight,
                    fontSize: textXL,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              contentBuilder: (expanded) =>
                  (expanded
                  ? (List<Widget> children) => Column(children: children)
                  : (List<Widget> children) => SingleChildScrollView(
                      child: ListBody(children: children),
                    ))(<Widget>[
                    Text(
                      t.manualSyncMsg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: textSM,
                      ),
                    ),
                    SizedBox(height: spaceMD + spaceSM),
                    TextField(
                      controller: syncMessageController,
                      maxLines: null,
                      style: TextStyle(
                        color: primaryLight,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                        decorationThickness: 0,
                        fontSize: textMD,
                      ),
                      decoration: InputDecoration(
                        fillColor: secondaryDark,
                        filled: true,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(cornerRadiusSM),
                          borderSide: BorderSide.none,
                        ),
                        hintText: syncMessage,
                        isCollapsed: true,
                        label: Text(
                          t.commitMessage.toUpperCase(),
                          style: TextStyle(
                            color: secondaryLight,
                            fontSize: textSM,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: spaceMD,
                          vertical: spaceSM,
                        ),
                        isDense: true,
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),
                    SizedBox(height: spaceMD),
                    (expanded
                        ? (Widget child) => Expanded(child: child)
                        : (child) => child)(
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(cornerRadiusSM),
                          color: secondaryDark,
                        ),
                        padding: EdgeInsets.only(
                          left: spaceXXS,
                          right: spaceXXS,
                          bottom: spaceXXS,
                          top: spaceXXXS,
                        ),
                        child: SizedBox(
                          height: expanded
                              ? null
                              : MediaQuery.sizeOf(context).height / 3,
                          width: double.maxFinite,
                          child: snapshot.data == null
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: tertiaryLight,
                                  ),
                                )
                              : snapshot.data!.isEmpty
                              ? Center(
                                  child: Text(
                                    t.noUncommittedChanges.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryLight,
                                      fontSize: textMD,
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    Container(
                                      child: Row(
                                        children: [
                                          TextButton.icon(
                                            onPressed: () {
                                              if (selectedFiles.isNotEmpty) {
                                                selectedFiles.clear();
                                              } else {
                                                selectedFiles.clear();
                                                selectedFiles.addAll(
                                                  snapshot.data
                                                          ?.map(
                                                            (item) => item.$1,
                                                          )
                                                          .toList() ??
                                                      [],
                                                );
                                              }

                                              setState(() {});
                                            },
                                            style: ButtonStyle(
                                              alignment: Alignment.center,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              padding: WidgetStatePropertyAll(
                                                EdgeInsets.symmetric(
                                                  vertical: spaceXS,
                                                  horizontal:
                                                      spaceXS + spaceXXXS,
                                                ),
                                              ),
                                              shape: WidgetStatePropertyAll(
                                                RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.all(
                                                        cornerRadiusSM,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            icon: FaIcon(
                                              selectedFiles.length ==
                                                      snapshot.data?.length
                                                  ? FontAwesomeIcons
                                                        .solidCircleCheck
                                                  : (selectedFiles.isEmpty
                                                        ? FontAwesomeIcons
                                                              .circleCheck
                                                        : FontAwesomeIcons
                                                              .circleMinus),
                                              color: selectedFiles.isNotEmpty
                                                  ? secondaryInfo
                                                  : tertiaryInfo,
                                              size: textMD,
                                            ),
                                            label: Text(
                                              (selectedFiles.isNotEmpty
                                                      ? t.deselectAll
                                                      : t.selectAll)
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: primaryLight,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: AnimatedListView(
                                        items: snapshot.data ?? <String>[],
                                        itemBuilder: (context, index) {
                                          final fileName =
                                              snapshot.data![index].$1;
                                          final fileType =
                                              snapshot.data![index].$2;

                                          (IconData, Color) infoIcon = (
                                            FontAwesomeIcons.solidSquarePlus,
                                            tertiaryPositive,
                                          );
                                          switch (fileType) {
                                            case 1:
                                              {
                                                infoIcon = (
                                                  FontAwesomeIcons.squarePen,
                                                  tertiaryWarning,
                                                );
                                                break;
                                              }
                                            case 2:
                                              {
                                                infoIcon = (
                                                  FontAwesomeIcons
                                                      .solidSquareMinus,
                                                  tertiaryNegative,
                                                );
                                                break;
                                              }
                                            case 3:
                                              {
                                                infoIcon = (
                                                  FontAwesomeIcons
                                                      .solidSquarePlus,
                                                  tertiaryPositive,
                                                );
                                                break;
                                              }
                                          }

                                          return TextButton(
                                            key: Key(fileName),
                                            style: ButtonStyle(
                                              backgroundColor:
                                                  WidgetStatePropertyAll(
                                                    primaryDark,
                                                  ),
                                              padding: WidgetStatePropertyAll(
                                                EdgeInsets.symmetric(
                                                  vertical: spaceXS,
                                                  horizontal:
                                                      spaceXS + spaceXXXS,
                                                ),
                                              ),
                                              shape: WidgetStatePropertyAll(
                                                RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.all(
                                                        cornerRadiusSM,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            onPressed: () {
                                              if (selectedFiles.contains(
                                                fileName,
                                              )) {
                                                selectedFiles.remove(fileName);
                                              } else {
                                                selectedFiles.add(fileName);
                                              }
                                              setState(() {});
                                            },
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      FaIcon(
                                                        selectedFiles.contains(
                                                              fileName,
                                                            )
                                                            ? FontAwesomeIcons
                                                                  .solidCircleCheck
                                                            : FontAwesomeIcons
                                                                  .circleCheck,
                                                        color:
                                                            selectedFiles
                                                                .contains(
                                                                  fileName,
                                                                )
                                                            ? secondaryInfo
                                                            : tertiaryInfo,
                                                        size: textMD,
                                                      ),
                                                      SizedBox(width: spaceXS),
                                                      Flexible(
                                                        child: ExtendedText(
                                                          fileName,
                                                          maxLines: 1,
                                                          textAlign:
                                                              TextAlign.left,
                                                          overflowWidget:
                                                              TextOverflowWidget(
                                                                position:
                                                                    TextOverflowPosition
                                                                        .start,
                                                                child: Text(
                                                                  "…",
                                                                  style: TextStyle(
                                                                    color:
                                                                        tertiaryLight,
                                                                    fontSize:
                                                                        textMD,
                                                                  ),
                                                                ),
                                                              ),
                                                          style: TextStyle(
                                                            color: primaryLight,
                                                            fontSize: textMD,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(width: spaceLG),
                                                FaIcon(
                                                  infoIcon.$1,
                                                  color: infoIcon.$2,
                                                  size: textMD,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        isSameItem: (a, b) => a == b,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ]),
              actionsAlignment: MainAxisAlignment.center,
              actions: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    uploading
                        ? SizedBox.shrink()
                        : IconButton(
                            onPressed: selectedFiles.isNotEmpty
                                ? () async {
                                    ConfirmDiscardChangesDialog.showDialog(
                                      context,
                                      selectedFiles,
                                      () async {
                                        await GitManager.discardChanges(
                                          selectedFiles,
                                        );
                                        selectedFiles.clear();
                                        setState(() {});
                                      },
                                    );
                                  }
                                : null,
                            style: ButtonStyle(
                              alignment: Alignment.center,
                              backgroundColor: WidgetStatePropertyAll(
                                selectedFiles.isNotEmpty
                                    ? secondaryNegative
                                    : tertiaryDark,
                              ),
                              padding: WidgetStatePropertyAll(
                                EdgeInsets.symmetric(
                                  horizontal: spaceMD,
                                  vertical: spaceSM,
                                ),
                              ),
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                    cornerRadiusSM,
                                  ),
                                  side: BorderSide.none,
                                ),
                              ),
                            ),
                            icon: FaIcon(
                              FontAwesomeIcons.eraser,
                              color: selectedFiles.isNotEmpty
                                  ? primaryLight
                                  : tertiaryLight,
                              size: textMD,
                            ),
                          ),
                    TextButton.icon(
                      onPressed: selectedFiles.isNotEmpty
                          ? () async {
                              uploading = true;
                              setState(() {});

                              await GitManager.uploadChanges(
                                await repoManager.getInt(
                                  StorageKey.repoman_repoIndex,
                                ),
                                uiSettingsManager,
                                () {},
                                selectedFiles,
                                syncMessageController.text.isEmpty
                                    ? null
                                    : syncMessageController.text,
                              );

                              selectedFiles.clear();
                              uploading = false;
                              setState(() {});
                            }
                          : null,
                      style: ButtonStyle(
                        alignment: Alignment.center,
                        backgroundColor: WidgetStatePropertyAll(
                          selectedFiles.isNotEmpty
                              ? primaryPositive
                              : tertiaryDark,
                        ),
                        padding: WidgetStatePropertyAll(
                          EdgeInsets.symmetric(
                            horizontal: spaceMD,
                            vertical: spaceSM,
                          ),
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(cornerRadiusSM),
                            side: BorderSide.none,
                          ),
                        ),
                      ),
                      icon: uploading
                          ? Container(
                              height: textSM,
                              width: textSM,
                              margin: EdgeInsets.only(right: spaceXXXS),
                              child: CircularProgressIndicator(
                                color: tertiaryDark,
                              ),
                            )
                          : null,
                      label: Text(
                        (uploading ? t.syncStartPull : t.syncNow).toUpperCase(),
                        style: TextStyle(
                          color: selectedFiles.isNotEmpty
                              ? tertiaryDark
                              : tertiaryLight,
                          fontSize: textSM,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spaceXS),
              ],
            ),
          );
        },
      ),
    ),
  );
}
