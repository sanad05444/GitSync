import 'dart:convert';
import 'package:GitSync/api/logger.dart';

import '../../manager/auth/git_provider_manager.dart';
import '../../../constant/secrets.dart';
import 'package:http/http.dart' as http;
import 'package:oauth2_client/oauth2_client.dart';

class GiteaManager extends GitProviderManager {
  static const String _domain = "gitea.com";

  GiteaManager();

  bool get oAuthSupport => true;

  @override
  Future<(String, String, String)?> launchOAuthFlow() async {
    OAuth2Client giteaClient = OAuth2Client(
      authorizeUrl: 'https://gitea.com/login/oauth/authorize',
      tokenUrl: 'https://gitea.com/login/oauth/access_token',
      redirectUri: 'gitsync://auth',
      customUriScheme: 'gitsync',
    );
    final response = await giteaClient.getTokenWithAuthCodeFlow(
      clientId: giteaClientId,
      clientSecret: giteaClientSecret,
    );
    if (response.accessToken == null) return null;

    final usernameAndEmail = await getUsernameAndEmail(response.accessToken!);
    if (usernameAndEmail == null) return null;

    return (usernameAndEmail.$1, usernameAndEmail.$2, response.accessToken!);
  }

  @override
  Future<(String, String)?> getUsernameAndEmail(String accessToken) async {
    final response = await http.get(
      Uri.parse("https://$_domain/api/v1/user"),
      headers: {
        "Accept": "application/json",
        "Authorization": "token $accessToken",
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      return (jsonData["login"] as String, jsonData["email"] as String);
    }

    return null;
  }

  @override
  Future<void> getRepos(
    String accessToken,
    Function(List<(String, String)>) updateCallback,
    Function(Function()?) nextPageCallback,
  ) async {
    await _getReposRequest(
      accessToken,
      "https://$_domain/api/v1/user/repos",
      updateCallback,
      nextPageCallback,
    );
  }

  Future<void> _getReposRequest(
    String accessToken,
    String url,
    Function(List<(String, String)>) updateCallback,
    Function(Function()?) nextPageCallback,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Accept": "application/json",
          "Authorization": "token $accessToken",
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonArray = json.decode(response.body);
        final List<(String, String)> repoList = jsonArray
            .map((repo) => ("${repo["name"]}", "${repo["clone_url"]}"))
            .toList();

        updateCallback(repoList);

        final String? linkHeader = response.headers["link"];
        if (linkHeader != null) {
          final match = RegExp(r'<([^>]+)>; rel="next"').firstMatch(linkHeader);
          final String? nextLink = match?.group(1);
          if (nextLink != null) {
            nextPageCallback(
              () => _getReposRequest(
                accessToken,
                nextLink,
                updateCallback,
                nextPageCallback,
              ),
            );
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
