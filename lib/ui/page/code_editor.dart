import 'package:GitSync/api/helper.dart';
import 'package:GitSync/constant/colors.dart';
import 'package:GitSync/constant/dimens.dart';
import 'package:GitSync/constant/values.dart';
import 'package:GitSync/global.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:sprintf/sprintf.dart';
import '../../../constant/strings.dart';
import 'package:path/path.dart' as p;

class CodeEditor extends StatefulWidget {
  const CodeEditor({super.key, required this.path, this.logs = false});

  final String path;
  final bool logs;

  @override
  State<CodeEditor> createState() => _CodeEditor();
}

class _CodeEditor extends State<CodeEditor> with WidgetsBindingObserver {
  final CodeController controller = CodeController(chunkConfig: ChunkConfig(chunkSize: 1000, chunkLineOverlap: 100));

  @override
  void initState() {
    super.initState();
    try {
      controller.language = extensionToLanguageMap[p.extension(widget.path).replaceFirst('.', '')] ?? extensionToLanguageMap["txt"];
      controller.openFile(widget.path);
      controller.fileAutoSave = true;
      controller.reversed = widget.logs;
      controller.readOnly = widget.logs;
    } catch (e) {
      print(e);
      controller.text = "";
      controller.language = null;
    }
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
        title: Text(p.basename(widget.path), style: TextStyle(fontSize: textLG, color: primaryLight, fontWeight: FontWeight.bold)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: ValueListenableBuilder(
        valueListenable: controller.fileSaving,
        builder:
            (context, saving, _) =>
                saving
                    ? Container(
                      height: spaceMD + spaceXXS,
                      width: spaceMD + spaceXXS,
                      margin: EdgeInsets.only(right: spaceXXXS, top: spaceLG + spaceXXS),
                      child: CircularProgressIndicator(color: primaryLight),
                    )
                    : SizedBox.shrink(),
      ),
      body: CodeTheme(
        data: CodeThemeData(
          styles: {
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
            'root': TextStyle(backgroundColor: Color(0xff2b2b2b), color: Color(0xfff8f8f2)),
            'emphasis': TextStyle(fontStyle: FontStyle.italic),
            'strong': TextStyle(fontWeight: FontWeight.bold),
          },
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.all(cornerRadiusMD), color: tertiaryDark),
              margin: EdgeInsets.only(left: spaceSM, right: spaceSM, bottom: spaceLG),
              padding: EdgeInsets.only(right: spaceXS),
              clipBehavior: Clip.hardEdge,
              child: ValueListenableBuilder(
                valueListenable: controller,
                builder:
                    (context, _, _) => CodeField(
                      expands: true,
                      readOnly: controller.readOnly,
                      controller: controller,
                      textStyle: TextStyle(fontSize: textMD),
                      background: Colors.transparent,
                      onChanged: (_) => setState(() {}),
                      gutterStyle: GutterStyle(
                        showErrors: true,
                        showFoldingHandles: true,
                        showLineNumbers: !widget.logs,
                        textStyle: TextStyle(height: 1.5, fontSize: textMD),
                        margin: widget.logs ? 0 : spaceXS,
                        textAlign: TextAlign.right,
                      ),
                    ),
              ),
            ),

            ValueListenableBuilder(
              valueListenable: controller,
              builder:
                  (context, _, _) =>
                      !controller.readOnly
                          ? const SizedBox.shrink()
                          : Positioned(
                            bottom: spaceXXL,
                            child: Container(
                              decoration: BoxDecoration(color: primaryDark, borderRadius: BorderRadius.all(cornerRadiusSM)),
                              padding: EdgeInsets.symmetric(horizontal: spaceSM, vertical: spaceXS),
                              child: Column(
                                children: [
                                  Text(
                                    t.readOnly.toUpperCase(),
                                    style: TextStyle(color: primaryLight, fontSize: textMD, fontWeight: FontWeight.bold),
                                  ),
                                  ...!controller.fileTooLarge.value
                                      ? []
                                      : [
                                        SizedBox(height: spaceXXXS),
                                        Text(
                                          sprintf(t.fileTooLarge, [controller.chunkConfig.chunkSize]),
                                          style: TextStyle(color: secondaryLight, fontSize: textSM),
                                        ),
                                      ],
                                ],
                              ),
                            ),
                          ),
            ),
            // ValueListenableBuilder(
            //   valueListenable: controller.fileTooLarge,
            //   builder:
            //       (context, isFileTooLarge, _) =>
            //           !isFileTooLarge
            //               ? const SizedBox.shrink()
            //               : Positioned(
            //                 bottom: spaceXXL,
            //                 child: Container(
            //                   decoration: BoxDecoration(color: primaryDark, borderRadius: BorderRadius.all(cornerRadiusSM)),
            //                   padding: EdgeInsets.symmetric(horizontal: spaceSM, vertical: spaceXS),
            //                   child: Column(
            //                     children: [
            //                       Text(
            //                         t.readOnly.toUpperCase(),
            //                         style: TextStyle(color: primaryLight, fontSize: textMD, fontWeight: FontWeight.bold),
            //                       ),
            //                       SizedBox(height: spaceXXXS),
            //                       Text(
            //                         sprintf(t.fileTooLarge, [controller.chunkConfig.chunkSize]),
            //                         style: TextStyle(color: secondaryLight, fontSize: textSM),
            //                       ),
            //                     ],
            //                   ),
            //                 ),
            //               ),
            // ),
          ],
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
