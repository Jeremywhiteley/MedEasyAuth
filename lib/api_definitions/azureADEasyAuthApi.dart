import 'dart:async';
import 'dart:convert' as convert;

import "package:http/http.dart" as http;
import 'package:simple_auth/simple_auth.dart';

enum AzureADEasyAuthType { aad, microsoftAccount, facebook, google, twitter }

class AzureADEasyAuthApi extends OAuthApi {
  String siteUrl;
  AzureADEasyAuthType authType;
  AzureADEasyAuthApi(String identifier, this.authType, this.siteUrl,
      {String redirectUrl = "http://localhost",
      List<String> scopes,
      http.Client client,
      Converter converter,
      AuthStorage authStorage})
      : super.fromIdAndSecret(identifier, authType.toString(), "native",
            client: client,
            scopes: scopes,
            converter: converter,
            authStorage: authStorage) {
    this.tokenUrl = "$siteUrl/.auth/refresh";
    this.authorizationUrl = "$siteUrl/.auth/login/${fromAuthType(authType)}";
    this.redirectUrl = redirectUrl;
    this.scopesRequired = false;
  }
  @override
  Authenticator getAuthenticator() => AzureADEasyAuthenticator(
      identifier, authType, tokenUrl, authorizationUrl, redirectUrl);

  String fromAuthType(AzureADEasyAuthType type) {
    switch (type) {
      case AzureADEasyAuthType.aad:
        return "aad";
      case AzureADEasyAuthType.microsoftAccount:
        return "microsoftaccount";
      case AzureADEasyAuthType.facebook:
        return "facebook";
      case AzureADEasyAuthType.google:
        return "google";
      case AzureADEasyAuthType.twitter:
        return "twitter";
    }
    return null;
  }

  @override
  Future<Request> authenticateRequest(Request request) async {
    Map<String, String> map = new Map.from(request.headers);
    map["X-ZUMO-AUTH"] = "${currentOauthAccount.token}";
    return request.replace(headers: map);
  }

  @override
  Future<OAuthAccount> getAccountFromAuthCode(
      WebAuthenticator authenticator) async {
    try {
      if (tokenUrl?.isEmpty ?? true) throw new Exception("Invalid tokenURL");
      final account = OAuthAccount(identifier,
          created: DateTime.now().toUtc(),
          expiresIn: new Duration(hours: 1).inSeconds,
          refreshToken: authenticator.authCode,
          scope: authenticator.scope,
          tokenType: "token",
          token: authenticator.authCode);
      return account;
    } catch (Exception) {
      throw Exception;
    }
  }

  @override
  Future<bool> refreshAccount(Account _account) async {
    try {
      var account = _account as OAuthAccount;
      var resp = await httpClient
          .get(tokenUrl, headers: {"X-ZUMO-AUTH": account.token});

      account.expiresIn = new Duration(hours: 1).inSeconds;
      account.created = DateTime.now().toUtc();
      currentAccount = account;
      saveAccountToCache(account);
      return true;
    } catch (Exception) {
      return false;
    }
  }
}

class AzureADEasyAuthenticator extends OAuthAuthenticator {
  AzureADEasyAuthType authType;
  AzureADEasyAuthenticator(String identifier, this.authType, String tokenUrl,
      String baseUrl, String redirectUrl)
      : super(identifier, "clientId", "clientSecret", tokenUrl, baseUrl,
            redirectUrl) {
    authCode = "token";
  }

  @override
  Future<Map<String, dynamic>> getInitialUrlQueryParameters() async {
    var data = {
      "post_login_redirect_url": redirectUrl,
      "session_mode": "token",
    };
    if (authType == AzureADEasyAuthType.google) {
      data["access_type"] = "offline";
    }
    return data;
  }

  @override
  bool checkUrl(Uri url) {
    if (url.hasFragment) {
      final parts = url.fragment.split("=");
      if (parts[0] == "token") {
        final decoded = Uri.decodeComponent(parts[1]);
        final Map<String, dynamic> json = convert.json.decode(decoded);
        final token = json["authenticationToken"];
        foundAuthCode(token);
        return true;
      }
    }
    return super.checkUrl(url);
  }
}
