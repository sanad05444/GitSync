import 'dart:io';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:GitSync/api/manager/auth/gitlab_manager.dart';
import 'package:oauth2_client/github_oauth2_client.dart';
import 'package:oauth2_client/oauth2_client.dart';
import '../../manager/auth/gitea_manager.dart';
import '../../manager/auth/github_manager.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../constant/icons.dart';
import '../../../type/git_provider.dart';

class GitProviderManager {
  // ignore: non_constant_identifier_names
  static Map<GitProvider, FaIcon> GitProviderIconsMap = {
    GitProvider.GITHUB: Platform.isIOS
        ? FaIcon(FontAwesomeIcons.gitAlt, size: textLG, color: primaryLight)
        : FaIcon(FontAwesomeIcons.github, size: textMD, color: primaryLight),
    GitProvider.GITEA: Platform.isIOS
        ? FaIcon(FontAwesomeIcons.gitAlt, size: textLG, color: primaryLight)
        : FaIcon(gitea_logo, size: textMD, color: giteaGreen),
    GitProvider.GITLAB: Platform.isIOS
        ? FaIcon(FontAwesomeIcons.gitAlt, size: textLG, color: primaryLight)
        : FaIcon(gitlab_logo, size: textMD, color: gitlabOrange),
    GitProvider.HTTPS: FaIcon(FontAwesomeIcons.lock, size: textMD, color: primaryLight),
    GitProvider.SSH: FaIcon(FontAwesomeIcons.terminal, size: textMD, color: primaryLight),
  };

  static GitProviderManager? getGitProviderManager(GitProvider provider) {
    return switch (provider) {
      GitProvider.GITHUB => GithubManager(),
      GitProvider.GITEA => GiteaManager(),
      GitProvider.GITLAB => GitlabManager(),
      GitProvider.HTTPS => null,
      GitProvider.SSH => null,
    };
  }

  OAuth2Client getOauthClient() => GitHubOAuth2Client(redirectUri: 'gitsync://auth', customUriScheme: 'gitsync');

  Future<String?> getToken(String token, Future<void> Function(String, String) setAccessRefreshToken) async {
    return null;
  }

  Future<(String, String, String)?> launchOAuthFlow() async {
    return null;
  }

  Future<(String, String)?> getUsernameAndEmail(String accessToken) async {
    return null;
  }

  Future<void> getRepos(String accessToken, Function(List<(String, String)>) updateCallback, Function(Function()?) nextPageCallback) async {}
}
