import 'dart:convert';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:sarjan_gate/extensions/sized_box.dart';
import 'package:sarjan_gate/main.dart';
import 'package:sarjan_gate/services/services.dart';
import 'package:sarjan_gate/values/app_urls.dart';
import 'package:sarjan_gate/views/visitor/approve_reject_visitor.dart';

import '../views/bottom_pages/home_page.dart';

class NotificationServices {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  String? visitorId = '';
  String? visitorName = '';
  String? visitorImage = '';

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  void requestNotificationPermission() async {
    NotificationSettings settings = await messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('user granted permission');
      }
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      if (kDebugMode) {
        print('user granted provisional permission');
      }
    } else {
      // AppSettings.openNotificationSettings();
      debugPrint('user denied permission');
    }
  }

  void firebaseInit(BuildContext context) async {
    FirebaseMessaging.onMessage.listen((message) {
      FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('Notification Data: ${message.data}');

      try {
        if (message.data.isEmpty) {
          // 🔴 Empty data: Use DEFAULT SOUND
          sendSimpleNotification(message: message);
        } else {
          // 🟢 Non-empty data: Use CUSTOM SOUND
          List<dynamic> data = jsonDecode(message.data['action']);
          initLocalNotification();

          if (data.isEmpty) {
            sendSimpleNotification(message: message);
          } else {
            setNotificationData(
                newVisitorID: message.data['visitor_id'].toString(),
                newVisitorImage:
                    '${message.data['path']}${'/'}${message.data['visitor_image']}',
                newVisitorName: message.data['visitor_name'].toString());
            sendNotification(context: context, message: message);
          }
        }
      } catch (e, s) {
        debugPrint('Error: $e\n$s');
      }
    });
  }

  Future<void> sendNotification({
    required BuildContext context,
    required RemoteMessage message,
  }) async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'custom_sound_channel', // Unique channel ID for custom sound
      'Custom Sound Notifications',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
          'longsound'), // 🟢 Your custom sound
    );

    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      channel.id,
      channel.name,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound(
          'longsound'), // Custom sound
    );

    NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await _flutterLocalNotificationsPlugin.show(
      1,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
    );
  }

  Future<void> showNotificationWithSound(RemoteMessage message) async {
    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'sarjan_gate_channel',
      'Sarjan Gate Notifications',
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('longsound'),
    );

    // Create notification details
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channel.id,
      channel.name,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: channel.sound,
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    // Show notification
    await _flutterLocalNotificationsPlugin.show(
      1,
      message.notification?.title,
      message.notification?.body,
      details,
    );
  }

  Future<void> showNotificationWithoutSound(RemoteMessage message) async {
    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'sarjan_gate_channel',
      'Sarjan Gate Notifications',
      importance: Importance.high,
      playSound: true,
    );

    // Create notification details
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channel.id,
      channel.name,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    // Show notification
    await _flutterLocalNotificationsPlugin.show(
      1,
      message.notification?.title,
      message.notification?.body,
      details,
    );
  }

  Future<String> getDeviceToken() async {
    String? token = await messaging.getToken();
    return token!;
  }

  void isTokenRefresh() async {
    messaging.onTokenRefresh.listen((event) {
      event.toString();
      if (kDebugMode) {
        print('refresh');
      }
    });
  }

  Future<void> sendSimpleNotification({required RemoteMessage message}) async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'default_channel', // Unique channel ID for default sound
      'Default Notifications',
      importance: Importance.defaultImportance,
      playSound: true, // System sound will play
    );

    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      channel.id,
      channel.name,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      sound: null, // 🔴 Explicitly set to null for default sound
    );

    NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await _flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
    );
  }

  void initLocalNotification() async {
    var androidInitializationSettings =
        const AndroidInitializationSettings('@mipmap/ic_launcher');

    InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse payload) {
        handleButtonClick(
            payload: payload, context: navigatorKey.currentContext!);
      },
    );
  }

  Future<void> setUpInteractMessage(BuildContext context) async {
    // When app is terminated

    RemoteMessage? initMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initMessage != null) {
      setNotificationData(
          newVisitorID: initMessage.data['visitor_id'].toString(),
          newVisitorImage:
              '${initMessage.data['path']}${'/'}${initMessage.data['visitor_image']}',
          newVisitorName: initMessage.data['visitor_name'].toString());

      Future.delayed(
        const Duration(seconds: 4),
        () {
          showNotificationDialog(
            context: navigatorKey.currentState!.context,
            userName: visitorName!,
            userImage: visitorImage!,
          );
        },
      );
    }

    //When app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((event) {
      setNotificationData(
          newVisitorID: event.data['visitor_id'].toString(),
          newVisitorImage:
              '${event.data['path']}${'/'}${event.data['visitor_image']}',
          newVisitorName: event.data['visitor_name'].toString());

      List<dynamic> data = jsonDecode(event.data['action']);

      if (homeScreenContext.mounted && data.isNotEmpty) {
        showNotificationDialog(
            context: homeScreenContext,
            userName: visitorName!,
            userImage: visitorImage!);
      }
      _flutterLocalNotificationsPlugin.cancelAll();
    });
  }

  void handleButtonClick(
      {required NotificationResponse payload, required BuildContext context}) {
    switch (payload.actionId) {
      case "accept":
        approveOrRejectVisitor(action: '1', isPop: false);
        _flutterLocalNotificationsPlugin.cancelAll();
        break;

      case "decline":
        approveOrRejectVisitor(action: '2', isPop: false);
        _flutterLocalNotificationsPlugin.cancelAll();
        break;

      default:
        showNotificationDialog(
            context: homeScreenContext,
            userName: visitorName!,
            userImage: visitorImage!);

        _flutterLocalNotificationsPlugin.cancelAll();
    }
  }

  Future<void> approveOrRejectVisitor(
      {required String action, required bool isPop}) async {
    Map<String, dynamic> data = {
      'visitor_id': visitorId!,
      'status': action,
    };

    try {
      Map<String, dynamic> response =
          await visitorRepo.approveOrRejectVisitor(data);

      if (response['isSuccess'] == true) {
        Fluttertoast.showToast(msg: response['message']);
        if (isPop) {
          Services.back(homeScreenContext);
        }
      } else {
        Fluttertoast.showToast(msg: response['message']);
        if (isPop) {
          Services.back(homeScreenContext);
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    }
  }

  void setNotificationData({
    required String newVisitorID,
    required String newVisitorName,
    required String newVisitorImage,
  }) {
    visitorId = newVisitorID;
    visitorName = newVisitorName;
    visitorImage = newVisitorImage;
  }

  void showNotificationDialog({
    required BuildContext context,
    required String userName,
    required String userImage,
  }) {
    showCupertinoModalPopup(
      context: context,
      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3, tileMode: TileMode.decal),
      barrierColor: Colors.black12,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Material(
          borderRadius: BorderRadius.circular(12.sp),
          child: Container(
            height: 40.h,
            width: 60.w,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.sp),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.bottomRight,
                  child: IconButton(
                    onPressed: () {
                      debugPrint(
                          'IMAGE IS ${AppUrls.baseImageUrl}${visitorImage!}');
                      Services.back(context);
                    },
                    icon: const Icon(
                      Icons.close,
                      color: Colors.red,
                    ),
                  ),
                ),
                2.sbh,
                CircleAvatar(
                  radius: 25.sp,
                  backgroundImage:
                      NetworkImage('${AppUrls.baseImageUrl}${visitorImage!}'),
                ),
                1.sbh,
                Text(
                  userName,
                  style:
                      TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                ),
                1.sbh,
                const Text('Has entered gate. Please check'),
                2.sbh,
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          approveOrRejectVisitor(action: '1', isPop: true);
                        },
                        style: ButtonStyle(
                            backgroundColor:
                                Colors.green.toMaterialStateProperty()),
                        child: const Text('Approve'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          approveOrRejectVisitor(action: '2', isPop: true);
                        },
                        style: ButtonStyle(
                            backgroundColor:
                                Colors.red.toMaterialStateProperty()),
                        child: const Text('Deny'),
                      ),
                    ],
                  ),
                ),
                1.sbh,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
