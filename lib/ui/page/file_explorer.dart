import 'dart:io';

import 'package:GitSync/api/helper.dart';
import 'package:GitSync/constant/colors.dart';
import 'package:GitSync/constant/dimens.dart';
import 'package:GitSync/constant/values.dart';
import 'package:GitSync/ui/dialog/create_folder.dart' as CreateFolderDialog;
import 'package:GitSync/ui/page/code_editor.dart';
import 'package:file_manager/file_manager.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../constant/strings.dart';
import 'package:path/path.dart' as p;

class FileExplorer extends StatefulWidget {
  const FileExplorer({super.key, required this.path});

  final String path;

  @override
  State<FileExplorer> createState() => _FileExplorer();
}

class _FileExplorer extends State<FileExplorer> with WidgetsBindingObserver {
  final FileManagerController controller = FileManagerController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.setCurrentPath = widget.path;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  String getPathLeadingText() => widget.path.replaceFirst(RegExp(r'/[^/]+$'), '/');

  @override
  Widget build(BuildContext context) {
    print(controller.getPathNotifier);
    print(widget.path);

    return WillPopScope(
      onWillPop: () async {
        if (controller.getCurrentPath == widget.path) {
          return true;
        } else {
          controller.goToParentDirectory();

          return false;
        }
      },
      child: Scaffold(
        backgroundColor: secondaryDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: ValueListenableBuilder(
            valueListenable: controller.getPathNotifier,
            builder:
                (context, currentPath, child) =>
                    getBackButton(
                      context,
                      () =>
                          currentPath == widget.path
                              ? (Navigator.of(context).canPop() ? Navigator.pop(context) : null)
                              : controller.goToParentDirectory(),
                    ) ??
                    SizedBox.shrink(),
          ),
          title: ValueListenableBuilder(
            valueListenable: controller.getPathNotifier,
            builder:
                (context, currentPath, child) => Text(
                  currentPath.replaceFirst(getPathLeadingText(), ""),
                  style: TextStyle(fontSize: textLG, color: primaryLight, fontWeight: FontWeight.bold),
                ),
          ),
          actions: [
            IconButton(
              onPressed: () async {
                CreateFolderDialog.showDialog(context, (folderName) async {
                  await FileManager.createFolder(controller.getCurrentPath, folderName);
                  controller.setCurrentPath = "${controller.getCurrentPath}/$folderName";
                });
              },
              icon: FaIcon(FontAwesomeIcons.folderPlus, color: primaryLight, size: textLG),
            ),
            SizedBox(width: spaceMD),
          ],
        ),
        body: FileManager(
          controller: controller,
          hideHiddenEntity: false,
          builder: (context, snapshot) {
            final List<FileSystemEntity> entities = snapshot;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: spaceMD),
              child: ListView.builder(
                itemCount: entities.length,
                itemBuilder: (context, index) {
                  final isHidden = FileManager.basename(entities[index]) == "" || FileManager.basename(entities[index]).startsWith('.');
                  final isFile = FileManager.isFile(entities[index]);

                  return Padding(
                    padding: EdgeInsets.only(bottom: spaceMD),
                    child: TextButton.icon(
                      onPressed: () async {
                        if (FileManager.isDirectory(entities[index])) {
                          controller.openDirectory(entities[index]);
                        } else {
                          try {
                            File(entities[index].path).readAsStringSync();
                            await Navigator.of(context).push(createCodeEditorRoute(entities[index].path));
                          } catch (e) {
                            print(e);
                            Fluttertoast.showToast(msg: "Editing unavailable", toastLength: Toast.LENGTH_LONG, gravity: null);
                          }
                        }
                      },
                      icon: Container(
                        width: textMD,
                        margin: EdgeInsets.all(spaceXS),
                        child: FaIcon(
                          isHidden
                              ? (isFile
                                  ? (extensionToLanguageMap.keys.contains(p.extension(entities[index].path).replaceFirst('.', ''))
                                      ? FontAwesomeIcons.fileLines
                                      : FontAwesomeIcons.file)
                                  : FontAwesomeIcons.folder)
                              : (isFile
                                  ? (extensionToLanguageMap.keys.contains(p.extension(entities[index].path).replaceFirst('.', ''))
                                      ? FontAwesomeIcons.solidFileLines
                                      : FontAwesomeIcons.solidFile)
                                  : FontAwesomeIcons.solidFolder),
                          color: isFile ? secondaryLight : tertiaryPositive,
                          size: textMD,
                        ),
                      ),
                      style: ButtonStyle(
                        alignment: Alignment.centerLeft,
                        padding: WidgetStatePropertyAll(EdgeInsets.all(spaceSM)),
                        backgroundColor: WidgetStatePropertyAll(tertiaryDark),
                        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(cornerRadiusSM), side: BorderSide.none)),
                      ),
                      label: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            FileManager.basename(entities[index]),
                            style: TextStyle(color: primaryLight, fontSize: textMD, overflow: TextOverflow.ellipsis),
                          ),
                          FutureBuilder<FileStat>(
                            future: entities[index].stat(),
                            builder:
                                (context, snapshot) => Text(
                                  snapshot.hasData
                                      ? (entities[index] is File
                                          ? FileManager.formatBytes(snapshot.data!.size)
                                          : "${snapshot.data!.modified}".substring(0, 10))
                                      : "",
                                  style: TextStyle(color: secondaryLight, fontSize: textSM),
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

Route createFileExplorerRoute(String path) {
  return PageRouteBuilder(
    settings: const RouteSettings(name: settings_main),
    pageBuilder: (context, animation, secondaryAnimation) => FileExplorer(path: path),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.ease;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
