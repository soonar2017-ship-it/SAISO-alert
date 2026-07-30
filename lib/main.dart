import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geographic Alert App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AlertHomePage(),
    );
  }
}

class AlertHomePage extends StatefulWidget {
  const AlertHomePage({super.key});

  @override
  State<AlertHomePage> createState() => _AlertHomePageState();
}

class _AlertHomePageState extends State<AlertHomePage> {
  String _statusMessage = "Initializing app...";
  String _fcmToken = "";
  // ضع هنا رابط سيرفرك الفعلي أو رابط الـ IP لكي يتصل به التطبيق
  final String serverUrl = "http://YOUR_SERVER_IP:5000/register_device";

  @override
  void initState() {
    super.initState();
    _setupFCMAndLocation();
  }

  Future<void> _setupFCMAndLocation() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        setState(() => _statusMessage = "Notification permission granted.");
      } else {
        setState(() => _statusMessage = "Notification permission declined.");
        return;
      }

      String? token = await messaging.getToken();
      setState(() {
        _fcmToken = token ?? "Failed to get token";
      });

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _statusMessage = "Location permissions are denied");
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _sendDataToServer(position.latitude, position.longitude);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(message.notification!.title ?? "Emergency Alert"),
              content: Text(message.notification!.body ?? ""),
              actions: [
                TextButton(
                  child: const Text("OK"),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        }
      });

    } catch (e) {
      setState(() => _statusMessage = "Error: $e");
    }
  }

  Future<void> _sendDataToServer(double lat, double lon) async {
    try {
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "device_name": "My Android Phone",
          "fcm_token": _fcmToken,
          "latitude": lat,
          "longitude": lon,
        }),
      );

      if (response.statusCode == 200) {
        setState(() => _statusMessage = "Device registered & location sent successfully!");
      } else {
        setState(() => _statusMessage = "Failed to sync with server.");
      }
    } catch (e) {
      setState(() => _statusMessage = "Server connection error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geographic Alert Client')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_active, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            const Text("FCM Token:", style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(_fcmToken, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
