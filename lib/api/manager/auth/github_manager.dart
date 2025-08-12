import 'dart:convert';
import 'package:GitSync/api/logger.dart';

import '../../manager/auth/git_provider_manager.dart';
import '../../../constant/secrets.dart';
import 'package:http/http.dart' as http;
import 'package:oauth2_client/github_oauth2_client.dart';
import 'package:oauth2_client/oauth2_client.dart';

class GithubManager extends GitProviderManager {
  static const String _domain = "github.com";

  GithubManager();

  bool get oAuthSupport => true;

  @override
  Future<(String, String)?> launchOAuthFlow() async {
    OAuth2Client ghClient = GitHubOAuth2Client(redirectUri: 'gitsync://auth', customUriScheme: 'gitsync');
    final response = await ghClient.getTokenWithAuthCodeFlow(
      clientId: gitHubClientId,
      clientSecret: gitHubClientSecret,
      scopes: ["repo", "workflow"],
    );
    if (response.accessToken == null) return null;

    final username = await getUsername(response.accessToken!);
    if (username == null) return null;

    return (username, response.accessToken!);
  }

  @override
  Future<String?> getUsername(String accessToken) async {
    final response = await http.get(
      Uri.parse("https://api.$_domain/user"),
      headers: {"Accept": "application/json", "Authorization": "token $accessToken"},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      return jsonData["login"];
    }

    return null;
  }

  @override
  Future<void> getRepos(String accessToken, Function(List<(String, String)>) updateCallback, Function(Function()?) nextPageCallback) async {
    await _getReposRequest(accessToken, "https://api.$_domain/user/repos", updateCallback, nextPageCallback);
  }

  Future<void> _getReposRequest(
    String accessToken,
    String url,
    Function(List<(String, String)>) updateCallback,
    Function(Function()?) nextPageCallback,
  ) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {"Accept": "application/json", "Authorization": "token $accessToken"});

      if (response.statusCode == 200) {
        final List<dynamic> jsonArray = json.decode(response.body);
        final List<(String, String)> repoList = jsonArray.map((repo) => ("${repo["name"]}", "${repo["clone_url"]}")).toList();

        updateCallback(repoList);

        final String? linkHeader = response.headers["link"];
        if (linkHeader != null) {
          final match = RegExp(r'<([^>]+)>; rel="next"').firstMatch(linkHeader);
          final String? nextLink = match?.group(1);
          if (nextLink != null) {
            nextPageCallback(() => _getReposRequest(accessToken, nextLink, updateCallback, nextPageCallback));
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
