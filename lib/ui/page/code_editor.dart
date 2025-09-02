import 'dart:io';
import 'dart:typed_data';

import 'package:GitSync/api/helper.dart';
import 'package:GitSync/constant/colors.dart';
import 'package:GitSync/constant/dimens.dart';
import 'package:GitSync/constant/values.dart';
import 'package:flutter/material.dart';
import 'package:mmap2/mmap2.dart';
import 'package:mmap2_flutter/mmap2_flutter.dart';
import '../../../constant/strings.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart' as ReEditor;

class CodeEditor extends StatefulWidget {
  const CodeEditor({super.key, required this.path, this.logs = false});

  final String path;
  final bool logs;

  @override
  State<CodeEditor> createState() => _CodeEditor();
}

class _CodeEditor extends State<CodeEditor> with WidgetsBindingObserver {
  final fileSaving = ValueNotifier(false);
  final ReEditor.CodeLineEditingController controller = ReEditor.CodeLineEditingController();
  final ScrollController horizontalController = ScrollController();
  final ScrollController verticalController = ScrollController();
  Mmap? writeMmap;

  @override
  void initState() {
    super.initState();
    MmapFlutter.initialize();

    try {
      _mapFile();
      controller.text = writeMmap == null ? "" : String.fromCharCodes(writeMmap!.writableData);
      print(writeMmap == null ? "" : String.fromCharCodes(writeMmap!.writableData));

      controller.addListener(_onTextChanged);

      //   controller.reversed = widget.logs;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (widget.logs) {
          await Future.delayed(Duration(milliseconds: 500));
          horizontalController.jumpTo(80);
          await Future.delayed(Duration(milliseconds: 500));
          horizontalController.jumpTo(80);

          verticalController.jumpTo(verticalController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      print(e);
    }
  }

  void _mapFile() {
    writeMmap?.close();
    writeMmap = Mmap.fromFile(widget.path, mode: AccessMode.write);
  }

  void _onTextChanged() {
    fileSaving.value = true;

    final newBytes = Uint8List.fromList(controller.text.codeUnits);

    if (writeMmap == null) return;

    if (newBytes.length != writeMmap!.writableData.length) {
      File(widget.path).writeAsBytesSync(newBytes);
      _mapFile();
    } else {
      writeMmap!.writableData.setAll(0, newBytes);
      writeMmap!.sync();
    }

    fileSaving.value = false;
  }

  @override
  void dispose() {
    controller.removeListener(_onTextChanged);
    writeMmap?.sync();
    writeMmap?.close();
    controller.dispose();
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
    return Scaffold(
      backgroundColor: secondaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: getBackButton(context, () => (Navigator.of(context).canPop() ? Navigator.pop(context) : null)) ?? SizedBox.shrink(),
        title: Text(
          p.basename(widget.path),
          style: TextStyle(fontSize: textLG, color: primaryLight, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: ValueListenableBuilder(
        valueListenable: fileSaving,
        builder: (context, saving, _) => saving
            ? Container(
                height: spaceMD + spaceXXS,
                width: spaceMD + spaceXXS,
                margin: EdgeInsets.only(right: spaceXXXS, top: spaceLG + spaceXXS),
                child: CircularProgressIndicator(color: primaryLight),
              )
            : SizedBox.shrink(),
      ),
      body: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.all(cornerRadiusMD), color: tertiaryDark),
        margin: EdgeInsets.only(left: spaceSM, right: spaceSM, bottom: spaceLG),
        padding: EdgeInsets.only(right: spaceXS),
        clipBehavior: Clip.hardEdge,
        child: ReEditor.CodeEditor(
          controller: controller,
          scrollController: ReEditor.CodeScrollController(verticalScroller: verticalController, horizontalScroller: horizontalController),
          wordWrap: false,

          style: ReEditor.CodeEditorStyle(
            textColor: Color(0xfff8f8f2),
            fontSize: textMD,

            codeTheme: ReEditor.CodeHighlightTheme(
              languages:
                  (extensionToLanguageMap.keys.contains(p.extension(widget.path).replaceFirst('.', ''))
                          ? {p.extension(widget.path).replaceFirst('.', ''): extensionToLanguageMap[p.extension(widget.path).replaceFirst('.', '')]!}
                          : {"txt": extensionToLanguageMap["txt"]!})
                      .map((key, value) => MapEntry(key, ReEditor.CodeHighlightThemeMode(mode: value))),
              theme: {
                'root': TextStyle(color: Color(0xfff8f8f2), backgroundColor: Color(0xff2b2b2b)),
                'comment': TextStyle(color: Color(0xffd4d0ab)),
                'quote': TextStyle(color: Color(0xffd4d0ab)),
                'variable': TextStyle(color: Color(0xffffa07a)),
                'template-variable': TextStyle(color: Color(0xffffa07a)),
                'tag': TextStyle(color: Color(0xffffa07a)),
                'name': TextStyle(color: Color(0xffffa07a)),
                'selector-id': TextStyle(color: Color(0xffffa07a)),
                'selector-class': TextStyle(color: Color(0xffffa07a)),
                'regexp': TextStyle(color: Color(0xffffa07a)),
                'deletion': TextStyle(color: Color(0xffffa07a)),
                'number': TextStyle(color: Color(0xfff5ab35)),
                'built_in': TextStyle(color: Color(0xfff5ab35)),
                'builtin-name': TextStyle(color: Color(0xfff5ab35)),
                'literal': TextStyle(color: Color(0xfff5ab35)),
                'type': TextStyle(color: Color(0xfff5ab35)),
                'params': TextStyle(color: Color(0xfff5ab35)),
                'meta': TextStyle(color: Color(0xfff5ab35)),
                'link': TextStyle(color: Color(0xfff5ab35)),
                'attribute': TextStyle(color: Color(0xffffd700)),
                'string': TextStyle(color: Color(0xffabe338)),
                'symbol': TextStyle(color: Color(0xffabe338)),
                'bullet': TextStyle(color: Color(0xffabe338)),
                'addition': TextStyle(color: Color(0xffabe338)),
                'title': TextStyle(color: Color(0xff00e0e0)),
                'section': TextStyle(color: Color(0xff00e0e0)),
                'keyword': TextStyle(color: Color(0xffdcc6e0)),
                'selector-tag': TextStyle(color: Color(0xffdcc6e0)),
                'emphasis': TextStyle(fontStyle: FontStyle.italic),
                'strong': TextStyle(fontWeight: FontWeight.bold),
              },
            ),
          ),
          readOnly: widget.logs,
          indicatorBuilder: (context, editingController, chunkController, notifier) {
            return Row(
              children: [
                if (!widget.logs) ReEditor.DefaultCodeLineNumber(controller: editingController, notifier: notifier),
                ReEditor.DefaultCodeChunkIndicator(width: 20, controller: chunkController, notifier: notifier),
              ],
            );
          },
        ),
      ),
    );
  }
}

Route createCodeEditorRoute(String path, {bool logs = false}) {
  return PageRouteBuilder(
    settings: const RouteSettings(name: settings_main),
    pageBuilder: (context, animation, secondaryAnimation) => CodeEditor(path: path, logs: logs),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.ease;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
