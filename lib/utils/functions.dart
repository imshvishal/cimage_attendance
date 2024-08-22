import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:cimage_attendance/utils/constants.dart';

void showSnackBar(BuildContext context, String message, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      backgroundColor: color,
      content: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

Future<void> navigateToWebView({required String url}) async {
  ChromeSafariBrowser browser = ChromeSafariBrowser();
  await browser.open(url: WebUri(url));
}

void displayDeveloperInfoDialogBox(BuildContext context) {
  var developer =
      jsonDecode(FirebaseRemoteConfig.instance.getString("developer"));
  showDialog(
    context: context,
    builder: ((context) {
      return AlertDialog(
        contentTextStyle: const TextStyle(color: primaryColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(width: 2, color: primaryColor),
              ),
              child: Column(
                children: [
                  TextButton(
                    child: Text(
                      developer["name"],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: primaryColor,
                          fontSize: 26,
                          fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      await navigateToWebView(
                        url: developer['socials'][0]['url'].toString().trim(),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: (developer['socials'] as List).map((social) {
                        return GestureDetector(
                          onTap: (() {
                            navigateToWebView(
                                url: social['url'].toString().trim());
                          }),
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor: Colors.transparent,
                            backgroundImage:
                                NetworkImage(social['image'].toString().trim()),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                ],
              ),
            ),
            Column(
              children: developer["notes"].length == 0
                  ? []
                  : [
                      const SizedBox(height: 10),
                      const Text(
                        "NOTES FROM THE DEVELOPER",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          decorationStyle: TextDecorationStyle.solid,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 50,
                        width: 200,
                        child: ListView.builder(
                          itemBuilder: (builder, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                developer['notes'][index],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 7),
                              ),
                            );
                          },
                          itemCount: developer['notes'].length,
                        ),
                      )
                    ],
            )
          ],
        ),
      );
    }),
  );
}
