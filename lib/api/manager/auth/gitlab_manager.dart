import 'dart:convert';
import 'package:GitSync/api/helper.dart';
import 'package:GitSync/api/logger.dart';

import '../../manager/auth/git_provider_manager.dart';
import '../../../constant/secrets.dart';
import 'package:oauth2_client/oauth2_client.dart';

class GitlabManager extends GitProviderManager {
  static const String _domain = "gitlab.com";

  GitlabManager();

  bool get oAuthSupport => true;

  get clientId => gitlabClientId;
  get clientSecret => gitlabClientSecret;
  get scopes => ["read_user", "read_api", "read_repository", "write_repository"];

  OAuth2Client get oauthClient => OAuth2Client(
    authorizeUrl: 'https://gitlab.com/oauth/authorize',
    tokenUrl: 'https://gitlab.com/oauth/token',
    redirectUri: 'gitsync://auth',
    customUriScheme: 'gitsync',
  );

  @override
  Future<(String, String)?> getUsernameAndEmail(String accessToken) async {
    final response = await httpGet(Uri.parse("https://$_domain/api/v4/user"), headers: {"Authorization": "Bearer $accessToken"});

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      return (jsonData["username"] as String, jsonData["email"] as String);
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
    await _getReposRequest(
      accessToken,
      "https://$_domain/api/v4/projects?membership=true&per_page=100",
      searchString == ""
          ? updateCallback
          : (list) => updateCallback(list.where((item) => item.$1.toLowerCase().contains(searchString.toLowerCase())).toList()),
      searchString == "" ? nextPageCallback : (_) => {},
    );
  }

  Future<void> _getReposRequest(
    String accessToken,
    String url,
    Function(List<(String, String)>) updateCallback,
    Function(Function()?) nextPageCallback,
  ) async {
    try {
      final response = await httpGet(Uri.parse(url), headers: {"Authorization": "Bearer $accessToken"});

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
