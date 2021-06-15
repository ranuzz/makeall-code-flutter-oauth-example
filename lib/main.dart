import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

import 'package:url_launcher/url_launcher.dart';

/// GLOBALS
String APP_CLIENT_ID = '*************';
String REDIRECT_URI = '*************';
/// GLOBALS

/// HELPERS FUNCTIONS
Future<void> redditGetAccessCode() async {
  Uri authorizationUrl = Uri.parse('https://www.reddit.com/api/v1/authorize.compact?client_id=${APP_CLIENT_ID}&response_type=code&state=RANDOM_STRING&redirect_uri=${REDIRECT_URI}&duration=permanent&scope=read');

  developer.log(authorizationUrl.toString());
  if (await canLaunch(authorizationUrl.toString())) {
    await launch(authorizationUrl.toString());
  } else {
    developer.log('cant launch URL');
  }
}

String extractAuthorisationCodeFromQuery(String query) {
  List<String> queryList = query.split('&');

  for (String q in queryList) {
    List<String> qval = q.split('=');

    if (qval.length > 1 && qval.first.toLowerCase() == 'code') {
      return qval[1];
    }
  }
  return '';
}

String getRedditBasicAuthHeader() {
  var basicAuthStr = APP_CLIENT_ID+":";
  var bytes = utf8.encode(basicAuthStr);
  var base64Str = base64.encode(bytes);
  return base64Str;
}

Future<void> setRedditAccessTokenFromCode(String code) async {
  String basicAuth = getRedditBasicAuthHeader();
  var headers = {
    HttpHeaders.authorizationHeader: 'Basic $basicAuth',
  };

  try {
    final response = await http.post(
        Uri.parse('https://www.reddit.com/api/v1/access_token'),
        headers: headers,
        encoding: Encoding.getByName('utf-8'),
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': REDIRECT_URI
        }
    );
    if (response.statusCode == 200) {
      try {
        var responseJson = jsonDecode(response.body);
        await setRedditAccessCode(responseJson['access_token']);
        await setRedditRefreshToken(responseJson['refresh_token']);
      } catch (e) {
        developer.log(
            'redditGetAccessTokenFromCode :: Not able to parse Token',
            error: e);
      }
    } else if (response.statusCode == 401) {
      developer.log('Reddit API Token Revoked ${response.statusCode}');
    } else {
      developer.log('Reddit API Get failed ${response.statusCode}');
    }
  } catch (e) {
    developer.log(
        'redditGetAccessTokenFromCode :: Not able to get Token',
        error: e);
  }
}

/// HELPERS FUNCTIONS

/// Saving Key-Value
Future<void> setRedditAuthorisationCode(String code) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('reddit_oauth_code', code);
}

Future<void> setRedditRefreshToken(String token) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('reddit_refresh_token', token);
}

Future<void > setRedditAccessCode(String code) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('reddit_access_code', code);
}

/// Saving Key-Value

/// Reddit Login Button
class RedditLogin extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        ElevatedButton(
          onPressed: () async {
            await redditGetAccessCode();
          },
          child: Text("Connect Reddit"),
        ),
      ],
    );
  }
}
/// Reddit Login Button

/// REDIRECT HANDLER
class RedditRedirectView extends StatefulWidget {

  static const name = "RedditRedirectView";
  // Same as reddit app redirect URI path
  // confirm !
  static const routeName = "/oauth";

  final String query;

  RedditRedirectView({required this.query});

  @override
  _RedditRedirectView createState() {
    return _RedditRedirectView();
  }
}

class _RedditRedirectView extends State<RedditRedirectView> {

  List<Widget> _children = [
    CircularProgressIndicator()
  ];

  List<Widget> getSuccessChildren(BuildContext context) {
    return [Text('All Done')];
  }

  List<Widget> getFailureChildren(BuildContext context) {
    return [Text('Failed')];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text('title')
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _children,
          ),
        )
    );
  }

  @override
  void initState() {
    super.initState();
    String code = extractAuthorisationCodeFromQuery(this.widget.query);
    setRedditAuthorisationCode(code)
        .then((value) => {
      setRedditAccessTokenFromCode(code)
          .then((value) => {
        setState(() {
          _children = getSuccessChildren(context);
        })
      })
          .catchError((onError) => {
        setState(() {
          _children = getFailureChildren(context);
        })
      })
    });
  }

  @override
  void dispose() {
    super.dispose();
  }
}
/// REDIRECT HANDLER


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo | Oauth Reddit',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
      onGenerateRoute: (settings) {
        developer.log('Current Route : ${settings.name}');

        Uri uri = Uri.parse(settings.name.toString());
        switch(uri.path) {
          case RedditRedirectView.routeName:
            {
              String query = uri.query;
              return MaterialPageRoute(
                  builder: (context) =>
                      RedditRedirectView(query: query,)
              );
            }
        }

        switch(settings.name) {
              default:
                return MaterialPageRoute(
                    builder: (context) =>
                    MyHomePage(title: 'title')
                );
          }
      }
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RedditLogin()
          ],
        ),
      )
    );
  }
}
