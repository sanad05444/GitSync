import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:GitSync/api/helper.dart';
import 'package:GitSync/api/logger.dart';
import 'package:GitSync/constant/colors.dart';
import 'package:GitSync/constant/dimens.dart';
import 'package:GitSync/constant/values.dart';
import 'package:GitSync/global.dart';
import 'package:GitSync/ui/component/button_setting.dart';
import 'package:GitSync/ui/dialog/info_dialog.dart' as InfoDialog;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mmap2/mmap2.dart';
import 'package:mmap2_flutter/mmap2_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../constant/strings.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart' as ReEditor;

class LogsChunkAnalyzer implements ReEditor.CodeChunkAnalyzer {
  static const List<String> matchSubstrings = ["RecentCommits:", "GitStatus:", "Getting local directory", ".git folder found"];

  const LogsChunkAnalyzer();

  @override
  List<ReEditor.CodeChunk> run(ReEditor.CodeLines codeLines) {
    final List<ReEditor.CodeChunk> chunks = [];
    int? runStart;

    for (int i = 0; i < codeLines.length; i++) {
      final String line = codeLines[i].text;
      final bool matches = _lineMatches(line);

      if (matches) {
        runStart ??= i;
      } else {
        if (runStart != null) {
          chunks.add(ReEditor.CodeChunk(runStart, i - 1));
          runStart = null;
        }
      }
    }

    if (runStart != null) {
      chunks.add(ReEditor.CodeChunk(runStart, codeLines.length - 1));
    }

    return chunks;
  }

  bool _lineMatches(String line) {
    final String trimmed = line;
    if (RegExp(r'^.*\s\[E\]\s.*$').hasMatch(line)) return true;
    if (RegExp(r'^(?!.*\s\[(I|W|E|D|V|T)\]\s).*$').hasMatch(line)) return true;
    for (final String sub in matchSubstrings) {
      if (trimmed.contains(sub)) {
        return true;
      }
    }
    return false;
  }
}

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
  Map<String, ReEditor.CodeHighlightThemeMode> languages = {};
  bool logsCollapsed = false;

  @override
  void initState() {
    super.initState();
    MmapFlutter.initialize();

    try {
      _mapFile();
      controller.text = writeMmap == null ? "" : utf8.decode(writeMmap!.writableData, allowMalformed: true);

      controller.addListener(_onTextChanged);
    } catch (e) {
      print(e);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!widget.logs || controller.text.isEmpty) return;

      final chunkController = ReEditor.CodeChunkController(controller, LogsChunkAnalyzer());
      while (chunkController.value.isEmpty) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      int offset = 0;

      if (widget.logs) {
        for (final chunk in chunkController.value) {
          chunkController.collapse(chunk.index - offset);
          offset += max(0, chunk.end - chunk.index - 1);
        }
      }
      logsCollapsed = true;
      setState(() {});
      logsScrollToBottom();
    });

    languages =
        (extensionToLanguageMap.keys.contains(p.extension(widget.path).replaceFirst('.', ''))
                ? extensionToLanguageMap[p.extension(widget.path).replaceFirst('.', '')]!
                : extensionToLanguageMap["txt"]!)
            .map((key, value) => MapEntry(key, ReEditor.CodeHighlightThemeMode(mode: value)));
  }

  void logsScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.logs) {
        await Future.delayed(Duration(milliseconds: 500));
        horizontalController.jumpTo(80);
        await Future.delayed(Duration(milliseconds: 500));
        horizontalController.jumpTo(80);

        verticalController.jumpTo(verticalController.position.maxScrollExtent);
      }
    });
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
      File(widget.path).writeAsStringSync(controller.text);
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
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: secondaryDark,
          systemNavigationBarColor: secondaryDark,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
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
      body: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.all(cornerRadiusMD), color: tertiaryDark),
            margin: EdgeInsets.only(left: spaceSM, right: spaceSM, bottom: spaceLG),
            padding: EdgeInsets.only(right: spaceXS),
            clipBehavior: Clip.hardEdge,
            child: widget.logs && !logsCollapsed
                ? Center(child: CircularProgressIndicator(color: primaryLight))
                : ReEditor.CodeEditor(
                    controller: controller,
                    scrollController: ReEditor.CodeScrollController(verticalScroller: verticalController, horizontalScroller: horizontalController),
                    wordWrap: false,
                    chunkAnalyzer: widget.logs ? LogsChunkAnalyzer() : ReEditor.DefaultCodeChunkAnalyzer(),
                    style: ReEditor.CodeEditorStyle(
                      textColor: Color(0xfff8f8f2),
                      fontSize: textMD,
                      codeTheme: ReEditor.CodeHighlightTheme(
                        languages: languages,
                        theme: {
                          'root': TextStyle(color: primaryLight),
                          'comment': TextStyle(color: secondaryLight),
                          'quote': TextStyle(color: tertiaryInfo),
                          'variable': TextStyle(color: secondaryWarning),
                          'template-variable': TextStyle(color: secondaryWarning),
                          'tag': TextStyle(color: secondaryWarning),
                          'name': TextStyle(color: secondaryWarning),
                          'selector-id': TextStyle(color: secondaryWarning),
                          'selector-class': TextStyle(color: secondaryWarning),
                          'regexp': TextStyle(color: secondaryWarning),
                          'deletion': TextStyle(color: secondaryWarning),
                          'number': TextStyle(color: primaryWarning),
                          'built_in': TextStyle(color: primaryWarning),
                          'builtin-name': TextStyle(color: primaryWarning),
                          'literal': TextStyle(color: primaryWarning),
                          'type': TextStyle(color: primaryWarning),
                          'params': TextStyle(color: primaryWarning),
                          'meta': TextStyle(color: primaryWarning),
                          'link': TextStyle(color: primaryWarning),
                          'attribute': TextStyle(color: tertiaryInfo),
                          'string': TextStyle(color: primaryPositive),
                          'symbol': TextStyle(color: primaryPositive),
                          'bullet': TextStyle(color: primaryPositive),
                          'addition': TextStyle(color: primaryPositive),
                          'title': TextStyle(color: tertiaryInfo, fontWeight: FontWeight.w500),
                          'section': TextStyle(color: tertiaryInfo, fontWeight: FontWeight.w500),
                          'keyword': TextStyle(color: tertiaryNegative),
                          'selector-tag': TextStyle(color: tertiaryNegative),
                          'emphasis': TextStyle(fontStyle: FontStyle.italic),
                          'strong': TextStyle(fontWeight: FontWeight.bold),

                          'logDate': TextStyle(color: tertiaryInfo.withAlpha(170)),
                          'logTime': TextStyle(color: tertiaryInfo),
                          'logLevel': TextStyle(color: tertiaryPositive),
                          'logComponent': TextStyle(color: primaryPositive),
                          'logError': TextStyle(color: tertiaryNegative),
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
          if (!widget.logs)
            Positioned(
              bottom: spaceXXL,
              child: Container(
                decoration: BoxDecoration(color: primaryDark, borderRadius: BorderRadius.all(cornerRadiusSM)),
                padding: EdgeInsets.symmetric(horizontal: spaceSM, vertical: spaceXS),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          style: ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          constraints: BoxConstraints(),
                          onPressed: () async {
                            InfoDialog.showDialog(
                              context,
                              "Code Editor Limits",
                              "The code editor provides basic, functional editing but hasn’t been exhaustively tested for edge cases or heavy use. \n\nIf you encounter bugs or want to suggest features, I welcome feedback! Please use the Bug Report or Feature Request options in Global Settings or below.",
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(height: spaceMD),
                                  ButtonSetting(
                                    text: t.requestAFeature,
                                    icon: FontAwesomeIcons.solidHandPointUp,
                                    onPressed: () async {
                                      if (await canLaunchUrl(Uri.parse(githubFeatureTemplate))) {
                                        await launchUrl(Uri.parse(githubFeatureTemplate));
                                      }
                                    },
                                  ),
                                  SizedBox(height: spaceSM),
                                  ButtonSetting(
                                    text: t.reportABug,
                                    icon: FontAwesomeIcons.bug,
                                    textColor: primaryDark,
                                    iconColor: primaryDark,
                                    buttonColor: tertiaryNegative,
                                    onPressed: () async {
                                      await Logger.reportIssue(context);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                          visualDensity: VisualDensity.compact,
                          icon: FaIcon(FontAwesomeIcons.circleInfo, color: secondaryLight, size: textMD),
                        ),
                        Text(
                          t.experimental.toUpperCase(),
                          style: TextStyle(color: primaryLight, fontSize: textMD, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: spaceXS),
                      ],
                    ),
                    SizedBox(height: spaceXXXS),
                    Text(
                      t.experimentalMsg,
                      style: TextStyle(color: secondaryLight, fontSize: textSM),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
