import 'dart:convert';
import 'package:GitSync/api/logger.dart';
import 'package:GitSync/constant/strings.dart';

import '../../manager/auth/git_provider_manager.dart';
import '../../../constant/secrets.dart';
import 'package:http/http.dart' as http;
import 'package:oauth2_client/oauth2_client.dart';

class GitlabManager extends GitProviderManager {
  static const String _domain = "gitlab.com";

  GitlabManager();

  bool get oAuthSupport => true;

  @override
  OAuth2Client getOauthClient() => OAuth2Client(
    authorizeUrl: 'https://gitlab.com/oauth/authorize',
    tokenUrl: 'https://gitlab.com/oauth/token',
    redirectUri: 'gitsync://auth',
    customUriScheme: 'gitsync',
  );

  @override
  Future<(String, String, String)?> launchOAuthFlow() async {
    OAuth2Client gitlabClient = getOauthClient();
    final response = await gitlabClient.getTokenWithAuthCodeFlow(
      clientId: gitlabClientId,
      clientSecret: gitlabClientSecret,
      scopes: ["read_user", "read_api", "read_repository", "write_repository"],
    );
    if (response.accessToken == null) return null;

    final usernameAndEmail = await getUsernameAndEmail(response.accessToken!);
    if (usernameAndEmail == null) return null;

    return (usernameAndEmail.$1, usernameAndEmail.$2, response.accessToken!);
  }

  @override
  Future<(String, String)?> getUsernameAndEmail(String accessToken) async {
    final response = await http.get(Uri.parse("https://$_domain/api/v4/user"), headers: {"Authorization": "Bearer $accessToken"});

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      return (jsonData["username"] as String, jsonData["email"] as String);
    }

    return null;
  }

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
    final refreshed = await client.refreshToken(refreshToken, clientId: gitlabClientId, clientSecret: gitlabClientSecret);

    if (refreshed.accessToken != null) {
      if (refreshed.accessToken == null || refreshed.refreshToken == null) return null;
      await setAccessRefreshToken(refreshed.accessToken!, refreshed.refreshToken!);
      return refreshed.accessToken;
    }
    return null;
  }

  @override
  Future<void> getRepos(String accessToken, Function(List<(String, String)>) updateCallback, Function(Function()?) nextPageCallback) async {
    await _getReposRequest(accessToken, "https://$_domain/api/v4/projects?membership=true&per_page=100", updateCallback, nextPageCallback);
  }

  Future<void> _getReposRequest(
    String accessToken,
    String url,
    Function(List<(String, String)>) updateCallback,
    Function(Function()?) nextPageCallback,
  ) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {"Authorization": "Bearer $accessToken"});

      if (response.statusCode == 200) {
        final List<dynamic> jsonArray = json.decode(response.body);
        final List<(String, String)> repoList = jsonArray.map((repo) => ("${repo["name"]}", "${repo["http_url_to_repo"]}")).toList();

        updateCallback(repoList);

        final String? nextLink = response.headers["x-next-page"];
        if (nextLink != null && nextLink.isNotEmpty) {
          final nextUrl = Uri.parse(url).replace(queryParameters: {...Uri.parse(url).queryParameters, "page": nextLink}).toString();
          nextPageCallback(() => _getReposRequest(accessToken, nextUrl, updateCallback, nextPageCallback));
        } else {
          nextPageCallback(null);
        }
      }
    } catch (e, st) {
      Logger.logError(LogType.GetRepos, e, st);
    }
  }
}
