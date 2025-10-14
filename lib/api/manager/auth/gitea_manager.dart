import 'dart:convert';
import 'package:GitSync/api/helper.dart';
import 'package:GitSync/api/logger.dart';
import 'package:GitSync/constant/strings.dart';

import '../../manager/auth/git_provider_manager.dart';
import '../../../constant/secrets.dart';
import 'package:oauth2_client/oauth2_client.dart';

class GiteaManager extends GitProviderManager {
  static const String _domain = "gitea.com";

  GiteaManager();

  bool get oAuthSupport => true;

  @override
  OAuth2Client getOauthClient() => OAuth2Client(
    authorizeUrl: 'https://gitea.com/login/oauth/authorize',
    tokenUrl: 'https://gitea.com/login/oauth/access_token',
    redirectUri: 'gitsync://auth',
    customUriScheme: 'gitsync',
  );

  @override
  Future<(String, String, String)?> launchOAuthFlow() async {
    OAuth2Client giteaClient = getOauthClient();
    final response = await giteaClient.getTokenWithAuthCodeFlow(clientId: giteaClientId, clientSecret: giteaClientSecret);
    if (response.accessToken == null) return null;

    final usernameAndEmail = await getUsernameAndEmail(response.accessToken!);
    if (usernameAndEmail == null) return null;

    return (usernameAndEmail.$1, usernameAndEmail.$2, "${response.accessToken!}$conflictSeparator${response.refreshToken!}");
  }

  @override
  Future<(String, String)?> getUsernameAndEmail(String accessToken) async {
    final response = await httpGet(
      Uri.parse("https://$_domain/api/v1/user"),
      headers: {"Accept": "application/json", "Authorization": "token $accessToken"},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      return (jsonData["login"] as String, jsonData["email"] as String);
    }

    return null;
  }

  @override
  @override
  Future<String?> getToken(String token, Future<void> Function(String p1, String p2) setAccessRefreshToken) async {
    final tokenParts = token.split(conflictSeparator);
    final accessToken = tokenParts.first;
    final refreshToken = tokenParts.last;

    if (!token.contains(conflictSeparator) || refreshToken.isEmpty) {
      return accessToken;
    }

    if (accessToken.isEmpty || refreshToken.isEmpty) return null;

    final client = getOauthClient();
    final refreshed = await client.refreshToken(refreshToken, clientId: giteaClientId, clientSecret: giteaClientSecret);

    if (refreshed.accessToken != null) {
      if (refreshed.accessToken == null || refreshed.refreshToken == null) return null;
      await setAccessRefreshToken(refreshed.accessToken!, refreshed.refreshToken!);
      return refreshed.accessToken;
    }
    return null;
  }

  @override
  Future<void> getRepos(
    String accessToken,
    String searchString,
    Function(List<(String, String)>) updateCallback,
    Function(Function()?) nextPageCallback,
  ) async {
    await getReposRequest(
      accessToken,
      searchString == "" ? "https://$_domain/api/v1/user/repos" : "https://$_domain/api/v1/user/repos?limit=100",
      searchString == ""
          ? updateCallback
          : (list) => updateCallback(list.where((item) => item.$1.toLowerCase().contains(searchString.toLowerCase())).toList()),
      searchString == "" ? nextPageCallback : (_) => {},
    );
  }

  Future<void> getReposRequest(
    String accessToken,
    String url,
    Function(List<(String, String)>) updateCallback,
    Function(Function()?) nextPageCallback,
  ) async {
    try {
      final response = await httpGet(Uri.parse(url), headers: {"Accept": "application/json", "Authorization": "token $accessToken"});

      if (response.statusCode == 200) {
        final List<dynamic> jsonArray = json.decode(response.body);
        final List<(String, String)> repoList = jsonArray.map((repo) => ("${repo["name"]}", "${repo["clone_url"]}")).toList();

        updateCallback(repoList);

        final String? linkHeader = response.headers["link"];
        if (linkHeader != null) {
          final match = RegExp(r'<([^>]+)>; rel="next"').firstMatch(linkHeader);
          final String? nextLink = match?.group(1);
          if (nextLink != null) {
            nextPageCallback(() => getReposRequest(accessToken, nextLink, updateCallback, nextPageCallback));
          } else {
            nextPageCallback(null);
          }
        } else {
          nextPageCallback(null);
        }
      }
    } catch (e, st) {
      Logger.logError(LogType.GetRepos, e, st);
    }
  }
}
