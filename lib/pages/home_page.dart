// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cimage_attendance/services/attendance_services.dart';
import 'package:cimage_attendance/utils/constants.dart';
import 'package:cimage_attendance/utils/functions.dart';

class HomePage extends StatefulWidget {
  final String title;
  final String url;
  const HomePage({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String _title = "";
  double _progress = 0;
  late InAppWebViewController? _webController;
  final Connectivity _connectivity = Connectivity();
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  String email = "";
  String password = "";
  late AnimationController _animationController;
  PackageInfo? appInfo;
  var latestApp =
      jsonDecode(FirebaseRemoteConfig.instance.getString("latest_app"));

  @override
  void dispose() {
    if (_webController != null) {
      _webController!.dispose();
    }
    _animationController.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  void initState() {
    initConnectivity();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    SharedPreferences.getInstance().then((prefs) {
      var data = prefs.getStringList("cimage_credentials");
      if (data != null) {
        email = data[0];
        password = data[1];
      }
    });
    super.initState();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      setState(() {
        _connectionStatus = result;
      });
    });
  }

  Future<void> initConnectivity() async {
    late List<ConnectivityResult> result;
    try {
      result = await _connectivity.checkConnectivity();
    } on PlatformException {
      return;
    }
    if (!mounted) {
      return Future.value(null);
    }
    appInfo = await PackageInfo.fromPlatform();
    setState(() {
      appInfo = appInfo;
      _connectionStatus = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return (appInfo != null && appInfo!.version != latestApp["version"])
        ? UpdateAvailableWidget(update: latestApp)
        : Scaffold(
            extendBody: true,
            appBar: AppBar(
              // centerTitle: true,
              leading: Padding(
                padding: const EdgeInsets.all(12),
                child: InkWell(
                  onTap: () async {
                    await _webController!.loadUrl(
                      urlRequest: URLRequest(
                        url: WebUri("$baseUrl/user-student/attendance"),
                      ),
                    );
                  },
                  child: Container(
                    decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                        image: DecorationImage(
                            image: NetworkImage(
                                "https://cimage.in/CIMAGE_Profile_Pic_Web.jpg"))),
                  ),
                ),
              ),
              actions: [
                RotationTransition(
                  turns: _animationController,
                  child: IconButton(
                    tooltip: "Refresh Widget!",
                    icon: const Icon(
                      Icons.refresh_rounded,
                    ),
                    onPressed: () async {
                      bool? widgetPinSupported =
                          await HomeWidget.isRequestPinWidgetSupported();
                      int widgetCount =
                          (await HomeWidget.getInstalledWidgets()).length;
                      if (widgetPinSupported != null &&
                          widgetPinSupported &&
                          widgetCount == 0) {
                        await HomeWidget.requestPinWidget(
                            androidName: androidName);
                      }
                      _animationController.repeat();
                      try {
                        await AttendanceServices.getAttendance(email, password);
                        showSnackBar(context,
                            "Widget data has been refrehshed!", Colors.green);
                      } on AttendanceException catch (e) {
                        showSnackBar(context, e.toString(), Colors.red);
                      } on Exception catch (e, s) {
                        FlutterError.reportError(
                            FlutterErrorDetails(exception: e, stack: s));
                        showSnackBar(
                            context,
                            "Something went wrong! Error has been reported! Please wait for an update. Thank you 🙏",
                            Colors.red);
                      }
                      _animationController.reset();
                    },
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem(
                        onTap: () {
                          displayDeveloperInfoDialogBox(context);
                        },
                        child: const ListTile(
                          leading: Icon(Icons.info_outline_rounded),
                          title: Text("Developer"),
                        ),
                      ),
                      PopupMenuItem(
                        onTap: () async {
                          email = "";
                          password = "";
                          await CookieManager.instance()
                              .deleteCookies(url: WebUri(baseUrl));
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          prefs.remove("cimage_credentials");
                          await _webController!.reload();
                        },
                        child: const ListTile(
                          leading: Icon(
                            Icons.logout,
                            color: secondaryColor,
                          ),
                          title: Text("Logout"),
                          textColor: secondaryColor,
                        ),
                      )
                    ];
                  },
                ),
              ],
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text.rich(
                    TextSpan(
                      text: "C",
                      style: TextStyle(
                          color: secondaryColor, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                            text: "IMAGE",
                            style: TextStyle(color: primaryColor))
                      ],
                    ),
                  ),
                  Text(
                    _title != "" ? _title : widget.title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  )
                ],
              ),
              // centerTitle: true,
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
            floatingActionButton:
                _connectionStatus.contains(ConnectivityResult.none)
                    ? null
                    : Container(
                        margin: const EdgeInsets.only(top: 15),
                        decoration: BoxDecoration(
                            color: primaryColor,
                            border: Border.all(
                              width: 2,
                              color: tertiaryColor,
                            ),
                            borderRadius: BorderRadius.circular(50)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: "Back",
                              onPressed: () async {
                                if (await _webController!.canGoBack()) {
                                  await _webController!.goBack();
                                }
                              },
                              icon: Icon(
                                Icons.arrow_circle_left_rounded,
                                color: tertiaryColor,
                              ),
                            ),
                            IconButton(
                              tooltip: "Reload",
                              onPressed: () async {
                                await _webController!.reload();
                              },
                              icon: Icon(
                                Icons.restart_alt_rounded,
                                color: tertiaryColor,
                              ),
                            ),
                            IconButton(
                              tooltip: "Forward",
                              onPressed: () async {
                                if (await _webController!.canGoForward()) {
                                  await _webController!.goForward();
                                }
                              },
                              icon: Icon(
                                Icons.arrow_circle_right_rounded,
                                color: tertiaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
            body: _connectionStatus.contains(ConnectivityResult.none)
                ? const NoInternet()
                : Column(
                    children: [
                      SizedBox(
                        height: 2,
                        child: LinearProgressIndicator(
                          backgroundColor:
                              Theme.of(context).scaffoldBackgroundColor,
                          color: primaryColor,
                          value: _progress < 1 ? _progress : 0,
                        ),
                      ),
                      Expanded(
                        child: InAppWebView(
                          initialSettings: InAppWebViewSettings(
                              preferredContentMode:
                                  UserPreferredContentMode.DESKTOP),
                          initialUrlRequest:
                              URLRequest(url: WebUri(widget.url)),
                          onWebViewCreated: ((controller) {
                            _webController = controller;
                            _webController!.addJavaScriptHandler(
                                handlerName: "loginFormSubmission",
                                callback: (data) async {
                                  email =
                                      data[0]["email"].toString().toLowerCase();
                                  password = data[0]["password"];
                                  try {
                                    await AttendanceServices.getAttendance(
                                        email, password);
                                    showSnackBar(
                                      context,
                                      "Login Successful! Attendance has been updated on widget! 😊",
                                      Colors.green,
                                    );
                                    SharedPreferences prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setStringList(
                                        "cimage_credentials",
                                        [email, password]);
                                  } catch (e) {
                                    showSnackBar(
                                        context, e.toString(), Colors.red);
                                  }
                                  await _webController!.loadUrl(
                                    urlRequest: URLRequest(
                                      url: WebUri(
                                          "$baseUrl/user-student/attendance"),
                                    ),
                                  );
                                });
                          }),
                          onLoadStop: (controller, url) async {
                            await controller.evaluateJavascript(source: """
                              var navbar = document.getElementById('navbar');
                              navbar.hidden = true;
                            """);
                            if (url!.path.startsWith("/login")) {
                              await controller.evaluateJavascript(source: """
                                document.querySelector("#login-box > div > div.widget-main > form").addEventListener('submit', function(event) {
                                  var loginBtn = document.querySelector("#login-box > div > div.widget-main > form > fieldset > div.clearfix > button");
                                  loginBtn.disabled = true;
                                  loginBtn.textContent = "Please Wait.."
                                  event.preventDefault();
                                  var formData = new FormData(event.target);
                                  var data = {};
                                  formData.forEach(function(value, key){
                                    data[key] = value;
                                  });
                                  window.flutter_inappwebview.callHandler('loginFormSubmission', data);
                                });
                              """);
                            } else {
                              await controller.evaluateJavascript(source: """
                          var meta = document.createElement('meta');
                          meta.name = 'viewport';
                          meta.content = 'width=1024';
                          document.getElementsByTagName('head')[0].appendChild(meta);
                          var loginData = document.createElement('div');
                          loginData.id = 'login-data';
                          loginData.innerHTML = "<center><h1>Logged in as: <b>${email.split(".")[0].toTitleCase()}</b></h1></center>;";
                          document.body.prepend(loginData);
                        """);
                            }
                            if (url.path == ("/user-student/attendance")) {
                              await controller.evaluateJavascript(source: """
                          var search = document.querySelector("#dynamic-table_filter > label > input");
                          if (search) {
                            search.value = '${DateFormat("MMM").format(DateTime.now())}';
                            search.dispatchEvent(new Event("input"));
                          } else {
                            console.error("Search input not found");
                          }
                          """);
                            }
                          },
                          onProgressChanged: ((controller, progress) {
                            setState(() {
                              _progress = progress / 100;
                            });
                          }),
                          onTitleChanged: ((controller, title) {
                            setState(() {
                              _title = title!;
                            });
                          }),
                        ),
                      ),
                    ],
                  ),
          );
  }
}

// ignore: must_be_immutable
class UpdateAvailableWidget extends StatelessWidget {
  var update;
  UpdateAvailableWidget({
    Key? key,
    required this.update,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text.rich(
                TextSpan(
                  text: "C",
                  style: TextStyle(
                      color: secondaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 40),
                  children: [
                    TextSpan(
                        text: "IMAGE", style: TextStyle(color: primaryColor))
                  ],
                ),
              ),
              const Icon(
                Icons.update,
                color: primaryColor,
                size: 80,
              ),
              const SizedBox(
                height: 20,
              ),
              Text(
                "${update["prompt"]["title"]}",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(
                height: 20,
              ),
              Text(
                "${update["prompt"]["description"]}",
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
              ),
              const SizedBox(
                height: 20,
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Theme.of(context).scaffoldBackgroundColor),
                onPressed: () async {
                  navigateToWebView(
                    url: update["prompt"]["url"],
                  );
                },
                child: const Text("Update"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class NoInternet extends StatelessWidget {
  const NoInternet({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.signal_wifi_connected_no_internet_4_rounded,
              color: secondaryColor,
              size: 40,
            ),
            Text(
              "No Internet!",
              style: TextStyle(fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
    );
  }
}
