import 'dart:io';

import 'package:GitSync/api/manager/git_manager.dart';
import 'package:GitSync/ui/dialog/prompt_disable_ssl.dart'
    as PromptDisableSslDialog;
import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../api/helper.dart';
import '../../../api/manager/auth/git_provider_manager.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../constant/strings.dart';
import '../../../global.dart';
import '../../../type/git_provider.dart';
import '../../../ui/dialog/select_folder.dart' as SelectFolderDialog;
import '../../../ui/dialog/cloning_repository.dart' as CloningRepositoryDialog;
import '../../../ui/dialog/repo_url_invalid.dart' as RepoUrlInvalid;
import '../../../ui/dialog/clone_failed.dart' as CloneFailedDialog;
import '../../../ui/dialog/confirm_clone_overwrite.dart'
    as ConfirmCloneOverwriteDialog;

class CloneRepoMain extends StatefulWidget {
  const CloneRepoMain({super.key});

  @override
  State<CloneRepoMain> createState() => _CloneRepoMain();
}

class _CloneRepoMain extends State<CloneRepoMain> with WidgetsBindingObserver {
  final _controller = ScrollController();
  final cloneUrlController = TextEditingController();

  bool atTop = true;
  bool atBottom = false;

  bool loadingRepos = false;
  Function()? loadNextRepos;
  final List<(String, String)> repoList = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.position.atEdge) {
        atTop = _controller.offset == 0;
        atBottom = _controller.offset != 0;
        if (atBottom) {
          if (loadNextRepos == null) return;
          setLoadingRepos(true);
          loadNextRepos!();
        }
      } else {
        atTop = false;
        atBottom = false;
      }

      if (!mounted) return;
      setState(() {});
    });

    initAsync(() async {
      final gitProviderManager = GitProviderManager.getGitProviderManager(
        await uiSettingsManager.getGitProvider(),
      );
      if (gitProviderManager == null) return;

      setLoadingRepos(true);
      final accessToken =
          (await uiSettingsManager.getGitHttpAuthCredentials()).$2;

      gitProviderManager.getRepos(
        accessToken,
        addRepos,
        (callback) => loadNextRepos = callback,
      );
    });
  }

  void addRepos(List<(String, String)> repos) {
    setLoadingRepos(false);
    repoList.addAll(repos);

    if (!mounted) return;
    setState(() {});
  }

  void setLoadingRepos(bool loading) {
    if (loading && loadNextRepos != null) {
      repoList.add((t.loadingElipsis, t.loadingElipsis));
    } else {
      repoList.removeWhere((repo) => repo.$1 == t.loadingElipsis);
    }
    loadingRepos = loading;

    if (!mounted) return;
    setState(() {});
  }

  bool validateGitRepoUrl(bool isSsh, String url) {
    if (url.isEmpty) return false;

    if (isSsh) {
      return sshPattern.hasMatch(url) ? true : false;
    } else {
      return httpsPattern.hasMatch(url) ? true : false;
    }
  }

  void cloneRepository(String repoUrl) {
    SelectFolderDialog.showDialog(context, () async {
      String? selectedDirectory;
      if (await requestStoragePerm()) {
        selectedDirectory = await pickDirectory();
      }
      if (selectedDirectory == null) return;

      final isEmpty = await useDirectory(
        selectedDirectory,
        (bookmarkPath) async =>
            await uiSettingsManager.setGitDirPath(bookmarkPath),
        (selectedDirectory) async {
          final dir = Directory(selectedDirectory);
          return await dir.exists() && (await dir.list().isEmpty);
        },
      );

      Future<void> startClone() async {
        await CloningRepositoryDialog.showDialog(
          context,
          repoUrl,
          selectedDirectory!,
          (result) async {
            if (result == null) {
              if (!mounted) return;
              await setGitDirPathGetSubmodules(context, selectedDirectory!);
              if (repoUrl.startsWith("http") && !repoUrl.startsWith("https")) {
                await PromptDisableSslDialog.showDialog(context, () async {
                  GitManager.setDisableSsl(true);
                });
              }
              await repoManager.setOnboardingStep(4);
              if (context.mounted) {
                Navigator.of(context).canPop() ? Navigator.pop(context) : null;
              }
              await onboardingController?.show();
            } else {
              await CloneFailedDialog.showDialog(context, result);
            }
          },
        );
      }

      if (isEmpty == true) {
        await startClone();
      } else {
        await ConfirmCloneOverwriteDialog.showDialog(
          context,
          () async {
            await GitManager.deleteDirContents(selectedDirectory!);
          },
          () async {
            await startClone();
          },
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: getBackButton(
          context,
          () => Navigator.of(context).canPop() ? Navigator.pop(context) : null,
        ),
        title: Text(
          t.cloneRepo,
          style: TextStyle(color: primaryLight, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: spaceMD),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  !loadingRepos && repoList.isEmpty
                      ? SizedBox.shrink()
                      : Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: secondaryDark,
                              borderRadius: BorderRadius.only(
                                topLeft: cornerRadiusMD,
                                bottomLeft: cornerRadiusSM,
                                topRight: cornerRadiusMD,
                                bottomRight: cornerRadiusSM,
                              ),
                            ),
                            margin: EdgeInsets.only(
                              top: spaceLG,
                              bottom: spaceLG,
                            ),
                            padding: EdgeInsets.all(spaceMD),
                            child: ShaderMask(
                              shaderCallback: (Rect rect) {
                                return LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    atTop ? Colors.transparent : Colors.black,
                                    Colors.transparent,
                                    Colors.transparent,
                                    atBottom
                                        ? Colors.transparent
                                        : Colors.black,
                                  ],
                                  stops: [0.0, 0.1, 0.9, 1.0],
                                ).createShader(rect);
                              },
                              blendMode: BlendMode.dstOut,
                              child: AnimatedListView(
                                items: repoList,
                                controller: _controller,
                                isSameItem: (a, b) => a.$2 == b.$2,
                                itemBuilder: (BuildContext context, int index) {
                                  final repo = repoList[index];
                                  return Container(
                                    key: Key(repo.$2),
                                    width: double.infinity,
                                    margin: EdgeInsets.only(bottom: spaceMD),
                                    child: TextButton.icon(
                                      onPressed: () => cloneRepository(repo.$2),
                                      style: ButtonStyle(
                                        alignment: Alignment.centerLeft,
                                        backgroundColor: WidgetStatePropertyAll(
                                          tertiaryDark,
                                        ),
                                        padding: WidgetStatePropertyAll(
                                          EdgeInsets.only(
                                            right: spaceMD,
                                            top: spaceSM,
                                            bottom: spaceSM,
                                            left: spaceXS,
                                          ),
                                        ),
                                        shape: WidgetStatePropertyAll(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.all(
                                              cornerRadiusMD,
                                            ),
                                            side: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                      iconAlignment: IconAlignment.end,
                                      icon: FaIcon(
                                        FontAwesomeIcons.solidCircleDown,
                                        color: primaryPositive,
                                        size: textXL,
                                      ),
                                      label: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.only(left: spaceXS),
                                        child: Text(
                                          repo.$1,
                                          maxLines: 1,
                                          style: TextStyle(
                                            overflow: TextOverflow.ellipsis,
                                            color: primaryLight,
                                            fontSize: textLG,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                  SizedBox(height: spaceLG),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cloneUrlController,
                            maxLines: 1,
                            style: TextStyle(
                              color: primaryLight,
                              decoration: TextDecoration.none,
                              decorationThickness: 0,
                              fontSize: textLG,
                            ),
                            decoration: InputDecoration(
                              hintText: t.gitRepoUrlHint,
                              hintStyle: TextStyle(
                                color: secondaryLight,
                                fontSize: textLG,
                              ),
                              fillColor: secondaryDark,
                              filled: true,
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(cornerRadiusMD),
                                borderSide: BorderSide.none,
                              ),
                              isCollapsed: true,
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: spaceMD,
                                vertical: spaceSM,
                              ),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        SizedBox(width: spaceMD),
                        TextButton.icon(
                          onPressed: cloneUrlController.text.isEmpty
                              ? null
                              : () async {
                                  final isValid = validateGitRepoUrl(
                                    await uiSettingsManager.getGitProvider() ==
                                        GitProvider.SSH,
                                    cloneUrlController.text,
                                  );
                                  if (isValid) {
                                    cloneRepository(cloneUrlController.text);
                                  } else {
                                    RepoUrlInvalid.showDialog(
                                      context,
                                      () => cloneRepository(
                                        cloneUrlController.text,
                                      ),
                                    );
                                  }
                                },
                          style: ButtonStyle(
                            alignment: Alignment.center,
                            backgroundColor: WidgetStatePropertyAll(
                              secondaryDark,
                            ),
                            padding: WidgetStatePropertyAll(
                              EdgeInsets.symmetric(
                                horizontal: spaceMD,
                                vertical: 0,
                              ),
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(cornerRadiusMD),
                                side: BorderSide.none,
                              ),
                            ),
                          ),
                          icon: FaIcon(
                            FontAwesomeIcons.solidCircleDown,
                            color: cloneUrlController.text.isEmpty
                                ? secondaryPositive
                                : primaryPositive,
                            size: textLG,
                          ),
                          label: Padding(
                            padding: EdgeInsets.only(left: spaceXS),
                            child: Text(
                              t.clone.toUpperCase(),
                              style: TextStyle(
                                color: cloneUrlController.text.isEmpty
                                    ? tertiaryLight
                                    : primaryLight,
                                fontSize: textMD,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spaceXXL),
                ],
              ),
            ),
            Column(
              children: [
                Container(height: 2, color: secondaryDark),
                SizedBox(height: spaceXXL),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          iconAlignment: IconAlignment.end,
                          onPressed: () async {
                            String? selectedDirectory;
                            if (await requestStoragePerm()) {
                              selectedDirectory = await pickDirectory();
                            }
                            if (selectedDirectory == null) return;

                            if (!mounted) return;
                            await setGitDirPathGetSubmodules(
                              context,
                              selectedDirectory,
                            );
                            await repoManager.setOnboardingStep(4);

                            Navigator.of(context).canPop()
                                ? Navigator.pop(context)
                                : null;

                            await onboardingController?.show();
                          },
                          style: ButtonStyle(
                            alignment: Alignment.center,
                            backgroundColor: WidgetStatePropertyAll(
                              secondaryDark,
                            ),
                            padding: WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: spaceMD),
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(cornerRadiusMD),
                                side: BorderSide.none,
                              ),
                            ),
                          ),
                          icon: FaIcon(
                            FontAwesomeIcons.solidFolderOpen,
                            color: primaryLight,
                            size: textMD,
                          ),
                          label: Container(
                            width: double.infinity,
                            padding: EdgeInsets.only(left: spaceXS),
                            child: Text(
                              t.iHaveALocalRepository.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: primaryLight,
                                fontSize: textMD,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: spaceXXL),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Route createCloneRepoMainRoute() {
  return PageRouteBuilder(
    settings: const RouteSettings(name: clone_repo_main),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const CloneRepoMain(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.ease;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
