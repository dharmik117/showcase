import 'dart:convert';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:sarjan_gate/extensions/sized_box.dart';
import 'package:sarjan_gate/repos/visitor_repo.dart';
import 'package:sarjan_gate/services/services.dart';

import '../main.dart';
import '../values/app_urls.dart';
import '../views/visitor/approve_reject_visitor.dart';

Map<String, dynamic>? _selectedData;

class NotificationServices {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  VisitorRepo visitorRepo = VisitorRepo();

  // String? visitorId = '';
  // String? visitorName = '';
  // String? visitorImage = '';

  //Request user permission
  void requestNotificationPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
        sound: true,
        announcement: true,
        alert: true,
        criticalAlert: true,
        provisional: true,
        badge: true);

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('----- Notification Permission Granted -----');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint(
          '----- Notification Permission Granted With Provisional -----');
    } else {
      Future.delayed(
        const Duration(seconds: 1),
        () {
          AppSettings.openAppSettings(type: AppSettingsType.notification);
        },
      );
    }
  }

  //Get Firebase token
  Future<String> getDeviceToken() async {
    NotificationSettings settings = await messaging.requestPermission(
        sound: true,
        announcement: true,
        alert: true,
        criticalAlert: true,
        provisional: true,
        badge: true);

    try {
      String? apnToken = await messaging.getAPNSToken();
      String? token = await messaging.getToken();
      //String? apnToken = await messaging.getAPNSToken();
      //debugPrint('------ Device Token ----- $token');
      debugPrint('------ APN Token ----- $apnToken');
      debugPrint('------ App Token ----- $token');
      return token!;
    } catch (e, s) {
      debugPrint(e.toString());
      debugPrint(s.toString());
    }
    return 'Error';
  }

  //Init local notification
  void initLocalNotification(
      {required BuildContext context, required RemoteMessage message}) async {
    var androidInitSetting =
        const AndroidInitializationSettings('@mipmap/ic_launcher');

    var iosInitSetting = const DarwinInitializationSettings(
      requestSoundPermission: true,
      defaultPresentAlert: true,
      requestAlertPermission: true,
      requestProvisionalPermission: true,
      requestCriticalPermission: true,
      requestBadgePermission: true,
    );

    var initSetting = InitializationSettings(
        iOS: iosInitSetting, android: androidInitSetting);

    AndroidNotificationChannel channel = const AndroidNotificationChannel(
      'sarjan-home-channel-custom', // Channel ID
      'custom channel', // Channel name
      importance: Importance.high,
      showBadge: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('longsound'),
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSetting,
      onDidReceiveNotificationResponse: (NotificationResponse res) {
        if (res.actionId != null) {
          if (res.actionId == '1') {
            debugPrint('Approved Tapped');
            //Action Page Redirection
            approveOrRejectVisitor(
                action: '1',
                isPop: false,
                visitorId: message.data['visitor_id']);
            flutterLocalNotificationsPlugin.cancelAll();
          }
          if (res.actionId == '2') {
            debugPrint('Rejected Tapped');
            //Action Page Redirection
            approveOrRejectVisitor(
                action: '2',
                isPop: false,
                visitorId: message.data['visitor_id']);
            flutterLocalNotificationsPlugin.cancelAll();
          }
          // all button click code is here
        } else {
          handleMessage(context: context, message: message);
        }
      },
    );

    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
    } else {
      debugPrint('Failed to resolve Android plugin.');
    }
  }

  //firebase init
  void firebaseInit({required BuildContext context}) {
    try {
      FirebaseMessaging.onMessage.listen((message) {
        if (Platform.isIOS) {
          iosForegroundMessage();
        }

        _selectedData = message.data;

        if (Platform.isAndroid) {
          initLocalNotification(context: context, message: message);
          // handleMessage(context: context, message: message);

          debugPrint('DATAAAAA IS ${_selectedData!}');

          if (message.data.isNotEmpty) {
            List<dynamic> actionList = jsonDecode(_selectedData!['action']);

            if (actionList.isNotEmpty) {
              showAdvanceNotification();
            } else {
              showSimpleNotification();
            }
          }
        }
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  //background & terminated state
  Future<void> setupMessage({required BuildContext context}) async {
    //background state

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      handleMessage(context: context, message: message);
    });

    //terminated state
    FirebaseMessaging.instance.getInitialMessage().then(
      (RemoteMessage? message) {
        if (message != null && message.data.isNotEmpty) {
          handleMessage(context: context, message: message);
        }
      },
    );
  }

  // handle all the messages
  Future<void> handleMessage(
      {required BuildContext context, required RemoteMessage message}) async {
    //all navigation code will be operated from here

    _selectedData = message.data;

    final NotificationAppLaunchDetails? details =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

    debugPrint('APP LAUNCH DETAILS ${details?.didNotificationLaunchApp}');

    if (details != null && details.didNotificationLaunchApp == false) {
      // Ensure it is only handled once

    }
    if (_selectedData!.isNotEmpty) {
      Future.delayed(
        const Duration(seconds: 1),
            () {
          showFullScreenBottomSheet(
              visitorId: _selectedData!['visitor_id'].toString(),
              isPop: true,
              image:
              '${_selectedData!['path']}/${_selectedData!['visitor_image']}',
              name: _selectedData!['visitor_name'].toString());
          flutterLocalNotificationsPlugin.cancelAll();
        },
      );
    }
    debugPrint('Message Data${_selectedData!}');
  }

  void iosForegroundMessage() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      sound: true,
      badge: true,
    );
  }

  //show notification
  Future<void> showSimpleNotification() async {
    debugPrint('Simple notification displayed');
    AndroidNotificationChannel channel = const AndroidNotificationChannel(
        'sarjan-home-channel', 'Channel for common sound',
        importance: Importance.defaultImportance,
        playSound: true,
        sound: null // custom sound for android
        );

    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
            'sarjan-home-channel', 'Channel for common sound',
            channelDescription: channel.description.toString(),
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            sound: null // custom sound for android,
            );

    DarwinNotificationDetails iosNotificationDetails =
        const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails, iOS: iosNotificationDetails);

    //show notification here
    Future.delayed(
      Duration.zero,
      () {
        flutterLocalNotificationsPlugin.show(
            int.parse(_selectedData!['title']),
            _selectedData!['title'],
            _selectedData!['body'],
            notificationDetails);
      },
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> showAdvanceNotification() async {
    debugPrint('Advance notification displayed');

    AndroidNotificationChannel channel = const AndroidNotificationChannel(
        'sarjan-home-channel-custom', 'Channel for custom sound',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(
            'longsound') // custom sound for android
        );

    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
            'sarjan-home-channel-custom', 'Channel for custom sound',
            channelDescription: channel.description.toString(),
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            actions: [
              const AndroidNotificationAction(
                '1',
                'Accept',
                cancelNotification: true,
                showsUserInterface: true,
              ),
              const AndroidNotificationAction(
                '2',
                'Reject',
                cancelNotification: true,
                showsUserInterface: true,
              ), // if you want to put a button in notification
            ],
            sound: const RawResourceAndroidNotificationSound(
                'longsound') // custom sound for android,
            );

    DarwinNotificationDetails iosNotificationDetails =
        const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails, iOS: iosNotificationDetails);

    //show notification here
    Future.delayed(
      Duration.zero,
      () {
        flutterLocalNotificationsPlugin.show(
            int.parse(_selectedData!['visitor_id']),
            _selectedData!['title'].toString(),
            _selectedData!['body'],
            notificationDetails);
      },
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

// void showNotificationDialog({
//   required BuildContext context,
//   required String userName,
//   required String userImage,
// }) {
//   showCupertinoModalPopup(
//     context: context,
//     filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3, tileMode: TileMode.decal),
//     barrierColor: Colors.black12,
//     barrierDismissible: false,
//     builder: (context) => Center(
//       child: Material(
//         borderRadius: BorderRadius.circular(12.sp),
//         child: Container(
//           height: 40.h,
//           width: 60.w,
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(12.sp),
//           ),
//           child: Column(
//             children: [
//               Align(
//                 alignment: Alignment.bottomRight,
//                 child: IconButton(
//                   onPressed: () {
//                     debugPrint(
//                         'IMAGE IS ${AppUrls.baseImageUrl}${visitorImage!}');
//                     Services.back(context);
//                   },
//                   icon: const Icon(
//                     Icons.close,
//                     color: Colors.red,
//                   ),
//                 ),
//               ),
//               2.sbh,
//               CircleAvatar(
//                 radius: 25.sp,
//                 backgroundImage:
//                     NetworkImage('${AppUrls.baseImageUrl}${visitorImage!}'),
//               ),
//               1.sbh,
//               Text(
//                 userName,
//                 style:
//                     TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
//               ),
//               1.sbh,
//               const Text('Has entered gate. Please check'),
//               2.sbh,
//               Expanded(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     ElevatedButton(
//                       onPressed: () {
//                         approveOrRejectVisitor(
//                             action: '1', isPop: true, context: context);
//                       },
//                       style: ButtonStyle(
//                           backgroundColor:
//                               Colors.green.toMaterialStateProperty()),
//                       child: const Text('Approve'),
//                     ),
//                     ElevatedButton(
//                       onPressed: () {
//                         approveOrRejectVisitor(
//                             action: '2', isPop: true, context: context);
//                       },
//                       style: ButtonStyle(
//                           backgroundColor:
//                               Colors.red.toMaterialStateProperty()),
//                       child: const Text('Deny'),
//                     ),
//                   ],
//                 ),
//               ),
//               1.sbh,
//             ],
//           ),
//         ),
//       ),
//     ),
//   );
// }
}

FlutterLocalNotificationsPlugin flutterLocalNotificationsPluginBg =
    FlutterLocalNotificationsPlugin();

@pragma("vm:entry-point")
Future<dynamic> myBackgroundMessageHandler(RemoteMessage message) async {

  _selectedData = message.data;
  showNotificationBg();
}

Future<void> showNotificationBg() async {
  debugPrint('BG Message Received ${_selectedData!}');

  List<dynamic> actionList = jsonDecode(_selectedData!['action']);

  if (actionList.isEmpty) {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'default-sound-channel-bg',
      'This channel is used for default sound for background',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.notification,
      fullScreenIntent: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPluginBg.show(
      int.parse(_selectedData!['visitor_id']),
      _selectedData!['title'],
      _selectedData!['body'],
      notificationDetails,
    );
  } else {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'custom-sound-channel-bg',
      'This channel is used for custom sound for background',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      fullScreenIntent: true,
      // actions: [
      //   AndroidNotificationAction(
      //     '1',
      //     'Accept',
      //     cancelNotification: true,
      //     showsUserInterface: true,
      //   ),
      //   AndroidNotificationAction(
      //     '2',
      //     'Reject',
      //     cancelNotification: true,
      //     showsUserInterface: true,
      //   ), // if you want to put a button in notification
      // ],
      sound: RawResourceAndroidNotificationSound(
          'longsound'), // custom sound for android
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPluginBg.show(
        3, _selectedData!['title'], _selectedData!['body'], notificationDetails,
        payload: jsonEncode(_selectedData!));
  }
}

Future<void> initializeNotificationsBG() async {
  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidInitSettings);

  await flutterLocalNotificationsPluginBg.initialize(
    initSettings,
    onDidReceiveNotificationResponse: onSelectNotificationBg,
  );

  // ✅ Clear any old notifications on app startup to avoid unwanted redirection
  await flutterLocalNotificationsPluginBg.cancelAll();
  await flutterLocalNotificationsPlugin.cancelAll();
}

void onSelectNotificationBg(NotificationResponse notificationResponse) async {
  // await flutterLocalNotificationsPluginBg.cancelAll();
  // await flutterLocalNotificationsPlugin.cancelAll();

  String? payload = notificationResponse.payload;
  _selectedData = jsonDecode(payload!);

  debugPrint('BG Notification Tapped');

  if (notificationResponse.actionId == '1') {
    await Future.delayed(
      const Duration(seconds: 1),
      () {
        showFullScreenBottomSheet(
            visitorId: _selectedData!['visitor_id'].toString(),
            isPop: true,
            image:
                '${_selectedData!['path']}/${_selectedData!['visitor_image']}',
            name: _selectedData!['visitor_name'].toString());
      },
    );
    await flutterLocalNotificationsPluginBg.cancelAll();
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  if (notificationResponse.actionId == '2') {
    await Future.delayed(
      const Duration(seconds: 1),
      () {
        showFullScreenBottomSheet(
            visitorId: _selectedData!['visitor_id'].toString(),
            isPop: true,
            image:
                '${_selectedData!['path']}/${_selectedData!['visitor_image']}',
            name: _selectedData!['visitor_name'].toString());
      },
    );
    await flutterLocalNotificationsPluginBg.cancelAll();
    await flutterLocalNotificationsPlugin.cancelAll();
  } else {
    if (_selectedData!.isNotEmpty) {
      List<dynamic> actionList = jsonDecode(_selectedData!['action']);

      if (actionList.isNotEmpty) {
        debugPrint('3rd Case');
        await Future.delayed(
          const Duration(seconds: 1),
          () {
            showFullScreenBottomSheet(
                visitorId: _selectedData!['visitor_id'].toString(),
                isPop: true,
                image:
                    '${_selectedData!['path']}/${_selectedData!['visitor_image']}',
                name: _selectedData!['visitor_name'].toString());
          },
        );
        debugPrint('Tapped Data $_selectedData');
      }
    }
  }

  await flutterLocalNotificationsPluginBg.cancelAll();
  await flutterLocalNotificationsPlugin.cancelAll();
}

void showFullScreenBottomSheet(
    {required String image,
    required String name,
    required String visitorId,
    required bool isPop}) {
  Services.openBottomSheet(
      navigatorKey.currentContext!,
      SizedBox(
        height: 100.h,
        width: 100.w,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                radius: 25.sp,
                backgroundImage: CachedNetworkImageProvider(
                  '${AppUrls.baseImageUrl}$image',
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    name,
                    style:
                        TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        approveOrRejectVisitor(
                            action: '1', visitorId: visitorId, isPop: true);
                      },
                      style: ButtonStyle(
                          backgroundColor:
                              Colors.green.toMaterialStateProperty()),
                      child: const Text('Approve'),
                    ),
                    5.sbw,
                    ElevatedButton(
                      onPressed: () {
                        approveOrRejectVisitor(
                            action: '2', isPop: true, visitorId: visitorId);
                      },
                      style: ButtonStyle(
                          backgroundColor:
                              Colors.red.toMaterialStateProperty()),
                      child: const Text('Deny'),
                    ),
                  ],
                )
              ],
            )
          ],
        ),
      ));
}

Future<void> approveOrRejectVisitor(
    {required String action,
    required bool isPop,
    required String visitorId}) async {
  Map<String, dynamic> data = {
    'visitor_id': visitorId,
    'status': action,
  };

  debugPrint('API DATA $data');

  try {
    Map<String, dynamic> response =
        await visitorRepo.approveOrRejectVisitor(data);

    if (response['isSuccess'] == true) {
      Fluttertoast.showToast(msg: response['message']);
      if (isPop) {
        Services.back(navigatorKey.currentContext!);
      }
    } else {
      Fluttertoast.showToast(msg: response['message']);
      if (isPop) {
        Services.back(navigatorKey.currentContext!);
      }
    }
  } catch (e) {
    Fluttertoast.showToast(msg: e.toString());
  }
}
