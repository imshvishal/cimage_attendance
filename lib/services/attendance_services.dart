import 'dart:convert';

import 'package:cimage_attendance/firebase_options.dart';
import 'package:cimage_attendance/services/firebase_services.dart';
import 'package:cimage_attendance/utils/constants.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:home_widget/home_widget.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceException implements Exception {
  final String message;
  const AttendanceException(this.message);

  @override
  String toString() {
    return "AttendanceException: $message";
  }
}

extension StringCasingExtension on String {
  String toCapitalized() =>
      length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
  String toTitleCase() => replaceAll(RegExp(' +'), ' ')
      .split(' ')
      .map((str) => str.toCapitalized())
      .join(' ');
}

extension on Cookie {
  String toNameString() {
    return "$name=$value";
  }
}

String androidName = "AttendanceWidget";
String baseUrl = "https://cimagecollege.in";

@pragma("vm:entry-point")
void bgDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'attendance':
        return await AttendanceServices.taskAttendance();
      default:
        return false;
    }
  });
}

class AttendanceServices {
  static var dio = Dio(
    BaseOptions(
        baseUrl: baseUrl,
        followRedirects: true,
        validateStatus: (status) {
          return true;
        }),
  );

  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        bgDispatcher,
        isInDebugMode: kDebugMode,
      );
      await Workmanager().registerPeriodicTask(
        'attendance',
        'attendance',
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 1),
        frequency: const Duration(hours: 1),
        initialDelay: const Duration(seconds: 10),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (e) {}
  }

  static Future<bool> taskAttendance() async {
    await FirebaseServices.initialize();
    var prefs = await SharedPreferences.getInstance();
    var data = prefs.getStringList("cimage_credentials");
    var widgetCount = (await HomeWidget.getInstalledWidgets()).length;
    if (widgetCount == 0) return false;
    var email = "";
    var password = "";
    if (data != null) {
      email = data[0].toLowerCase();
      password = data[1];
    }
    late String errorMsg;
    try {
      PackageInfo appInfo = await PackageInfo.fromPlatform();
      bool bgAttendanceActive =
          FirebaseRemoteConfig.instance.getBool("bg_attendance_active");
      var latestApp =
          jsonDecode(FirebaseRemoteConfig.instance.getString("latest_app"));
      if (!bgAttendanceActive) {
        throw const AttendanceException(
            "Background task is disabled by the developer! Will be back soon. Thank you 🙏");
      } else if (latestApp["version"] != appInfo.version) {
        throw const AttendanceException(
            "Update available! Please update the app. Thank you 🙏");
      } else {
        await getAttendance(email, password);
        return true;
      }
    } on AttendanceException catch (e) {
      errorMsg = e.message;
    } on Exception catch (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      errorMsg =
          "Something went wrong! Error has been reported. Wait for an update! 🥲";
    }
    await HomeWidget.renderFlutterWidget(
        AttendanceErrorWidget(message: errorMsg),
        logicalSize: const Size(400, 350),
        pixelRatio: 2,
        key: "attendance_widget_image");
    await HomeWidget.updateWidget(androidName: androidName);
    return false;
  }

  static Future<String> getLoginSessionToken(
      String email, String password) async {
    // Cookie? cookie = await CookieManager.instance()
    //     .getCookie(url: WebUri(baseUrl), name: "cimage_session");
    // if (cookie != null &&
    //     cookie.expiresDate != null &&
    //     cookie.expiresDate! > DateTime.now().millisecondsSinceEpoch) {
    //   return cookie.toNameString();
    // } else {
    var res = await dio.get("/login");
    var doc = parse(res.data);
    var token = doc.querySelector("input[name='_token']")!.attributes['value']!;
    var cookieStr = res.headers["set-cookie"]!.last.split(";").first;
    res = await dio.post("/login",
        data: {"_token": token, "email": email, "password": password},
        options: Options(headers: {'Cookie': cookieStr}));
    var newCookie = res.headers["set-cookie"]!
        .firstWhere((str) => str.startsWith("cimage_session"))
        .split(";")
        .first
        .split("=");
    await CookieManager.instance().setCookie(
        url: WebUri(baseUrl),
        name: newCookie[0],
        value: newCookie[1],
        maxAge: const Duration(hours: 3).inSeconds);
    Cookie? cookie = await CookieManager.instance()
        .getCookie(url: WebUri(baseUrl), name: "cimage_session");
    return cookie!.toNameString();
    // }
    // return cookie!.toNameString();
  }

  static Future<String> getAttendance(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      throw const AttendanceException("Please login to continue! 🤷‍♂️");
    }
    DateTime now = DateTime.now();
    String cookie = await getLoginSessionToken(email, password);
    int sessionPresent = 0, sessionAbsent = 0;
    int monthPresent = 0, monthAbsent = 0;
    List<String> todaysClasses = [];
    var res = await dio.get(
        "/user-student/attendance/attendance_percent_summary",
        options: Options(headers: {'cookie': cookie}));
    if (res.realUri.path.startsWith("/login")) {
      throw const AttendanceException(
          "Please login with valid credentials to continue! 🤷‍♂️");
    }
    var doc = parse(res.data);
    var data = doc
        .querySelectorAll("tr")
        .last
        .text
        .split("\n")
        .map((dt) => dt.trim())
        .where((dt) => dt.isNotEmpty)
        .toList();
    sessionPresent = int.parse(data[3]);
    sessionAbsent = int.parse(data[4]);
    res = await dio.get("/user-student/attendance",
        options: Options(headers: {'cookie': cookie}));
    doc = parse(res.data);
    var rows = doc.querySelectorAll("tr");

    List<String> ths = rows[3]
        .text
        .split("\n")
        .map((th) => th.trim().toLowerCase())
        .where((th) => th.isNotEmpty)
        .toList();
    int dateIndex = ths.indexOf(now.day.toString());
    int monthIndex = ths.indexOf("month");
    int yearIndex = ths.indexOf("year");
    for (var row in rows.reversed) {
      var rowData = row.text
          .split("\n")
          .map((data) => data.trim())
          .where((data) => data.isNotEmpty)
          .toList();
      var month = rowData[monthIndex].toLowerCase();
      var year = int.parse(rowData[yearIndex]);
      String ch = rowData[dateIndex];
      if (month.contains(DateFormat("MMMM").format(now).toLowerCase()) &&
          year == now.year) {
        monthPresent += rowData.where((el) => el == 'P').length;
        monthAbsent += rowData.where((el) => el == 'A').length;
        if (['P', 'A', 'N/A'].contains(ch)) {
          todaysClasses.add(rowData[dateIndex]);
        }
      } else {
        break;
      }
    }
    // for (var row in rows.reversed.toList().sublist(0, rows.length - 4)) {
    //   var rowData = row.text
    //       .split("\n")
    //       .map((data) => data.trim())
    //       .where((data) => data.isNotEmpty)
    //       .toList();
    //   var month = rowData[monthIndex].toLowerCase();
    //   var year = int.parse(rowData[yearIndex]);
    //   if (DateFormat("MMM yyyy")
    //       .parse("${month.substring(0, 3).toCapitalized()} $year")
    //       .isBefore(DateTime(2024, 6))) break;
    //   print(rowData);
    //   rowData.asMap().forEach((index, text) {
    //     String ch = text.trim();
    //     if (['P', 'A', 'N/A'].contains(ch) &&
    //         year == now.year &&
    //         month.contains(DateFormat("MMM").format(now).toLowerCase())) {
    //       if (ch == 'P') {
    //         monthPresent += 1;
    //       } else if (ch == 'A') {
    //         monthAbsent += 1;
    //       }
    //       if (index == dateIndex) {
    //         todaysClasses.add(ch);
    //       }
    //     }
    //     if (ch == "P") {
    //       sessionPresent += 1;
    //     } else if (ch == "A") {
    //       sessionAbsent += 1;
    //     }
    //   });
    // }
    // var present = 20, absent = 2000;

    String imagePath = await HomeWidget.renderFlutterWidget(
      AttendanceWidget(
        email: email,
        present: sessionPresent,
        absent: sessionAbsent,
        todaysClass: todaysClasses,
      ),
      key: "attendance_widget_image",
      logicalSize: const Size(400, 350),
      pixelRatio: 2,
    );
    HomeWidget.updateWidget(androidName: androidName);
    String month = DateFormat('MM-yy').format(now);
    Map<Object, Object> attendanceData = {
      "total": {
        "present": sessionPresent,
        "absent": sessionAbsent,
      },
      "month": {
        month: {
          "present": monthPresent,
          "absent": monthAbsent,
        },
      },
      "day": {
        "${now.day}-$month": todaysClasses,
      },
      "updated": now,
    };
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      DocumentSnapshot document =
          await FirebaseFirestore.instance.collection("users").doc(email).get();
      if (document.exists) {
        await document.reference.update({"attendance": attendanceData});
      } else {
        await document.reference.set({"attendance": attendanceData});
      }
      // ignore: empty_catches
    } on Exception {}
    return imagePath;
  }
}

class AttendanceErrorWidget extends StatelessWidget {
  final String message;
  const AttendanceErrorWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            const Text.rich(
              TextSpan(
                text: "C",
                style: TextStyle(color: secondaryColor, fontSize: 40),
                children: [
                  TextSpan(
                    text: "IMAGE",
                    style: TextStyle(color: primaryColor),
                  )
                ],
              ),
            ),
            Text(
              DateFormat("hh:mm aa | dd MMMM yyyy").format(DateTime.now()),
              style: TextStyle(color: Colors.orange.shade800),
            ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: must_be_immutable
class AttendanceWidget extends StatelessWidget {
  final String email;
  final int present;
  final int absent;
  final int total;
  List<String> todaysClass;
  late double percentage;
  AttendanceWidget({
    super.key,
    required this.email,
    required this.present,
    required this.absent,
    this.todaysClass = const [],
  }) : total = present + absent {
    percentage = present / total * 100;
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(),
      child: SizedBox(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text.rich(
                    TextSpan(
                      text: "C",
                      style: TextStyle(color: secondaryColor, fontSize: 40),
                      children: [
                        TextSpan(
                          text: "IMAGE",
                          style: TextStyle(color: primaryColor),
                        )
                      ],
                    ),
                  ),
                  Text(
                    DateFormat("hh:mm aa | dd MMMM yyyy")
                        .format(DateTime.now()),
                    style: TextStyle(color: Colors.orange.shade800),
                  ),
                  Text(
                    email.split(".")[0].toTitleCase(),
                    style: const TextStyle(color: secondaryColor),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text.rich(
                            TextSpan(
                              text: "Present: ",
                              style: const TextStyle(color: Colors.grey),
                              children: [
                                TextSpan(
                                    text: present.toString(),
                                    style: const TextStyle(color: primaryColor))
                              ],
                            ),
                            style: const TextStyle(
                              fontSize: 30,
                            ),
                          ),
                          Text.rich(
                            TextSpan(
                              text: "Absent: ",
                              style: const TextStyle(color: Colors.grey),
                              children: [
                                TextSpan(
                                    text: absent.toString(),
                                    style:
                                        const TextStyle(color: secondaryColor))
                              ],
                            ),
                            style: const TextStyle(fontSize: 30),
                          ),
                          Text.rich(
                            TextSpan(
                              text: "Total: ",
                              style: const TextStyle(color: Colors.grey),
                              children: [
                                TextSpan(
                                    text: (total).toString(),
                                    style: const TextStyle(color: primaryColor))
                              ],
                            ),
                            style: const TextStyle(fontSize: 30),
                          ),
                          Text.rich(
                            TextSpan(
                              text: "%age: ",
                              style: const TextStyle(color: Colors.grey),
                              children: [
                                TextSpan(
                                    text: "${percentage.toStringAsFixed(2)}%",
                                    style: TextStyle(
                                        color: percentage >= 75
                                            ? Colors.green
                                            : secondaryColor))
                              ],
                            ),
                            style: const TextStyle(fontSize: 30),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                value: percentage,
                                color: primaryColor,
                                title: "${percentage.toStringAsFixed(2)}%",
                                titleStyle: const TextStyle(fontSize: 10),
                                badgeWidget: const CircleAvatar(
                                  radius: 15,
                                  backgroundColor: primaryColor,
                                  child: Text("P"),
                                ),
                                badgePositionPercentageOffset: 1.2,
                              ),
                              PieChartSectionData(
                                value: 100 - percentage,
                                color: secondaryColor,
                                title:
                                    "${(100 - percentage).toStringAsFixed(2)}%",
                                titleStyle: const TextStyle(fontSize: 10),
                                badgeWidget: const CircleAvatar(
                                  radius: 15,
                                  backgroundColor: secondaryColor,
                                  child: Text("A"),
                                ),
                                badgePositionPercentageOffset: 1.2,
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: Text(
                      "Today's Classes",
                      style: TextStyle(
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                  todaysClass.isEmpty
                      ? const Text(
                          "No Classes Yet! 🤷‍♂️",
                          style: TextStyle(color: primaryColor, fontSize: 20),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: todaysClass.map(
                            (status) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: CircleAvatar(
                                  backgroundColor: status == 'P'
                                      ? primaryColor
                                      : secondaryColor,
                                  radius: 15,
                                  child: Text(status),
                                ),
                              );
                            },
                          ).toList(),
                        )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
