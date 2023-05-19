import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const MyApp());
}

Future<String?> requestLocationPermission() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return 'Location services are disabled.';
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return 'Location permissions are denied';
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return 'Location permissions are permanently denied, we cannot request permissions.';
  }

  return null;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hermes',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Hermes Bus Tracking'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool tracking = false;
  Position position = const Position(
      accuracy: 0,
      altitude: 0,
      heading: 0,
      latitude: 0,
      longitude: 0,
      speed: 0,
      speedAccuracy: 0,
      timestamp: null);
  Timer timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
    timer.cancel();
  });
  String trackMessage = '';
  DateTime now = DateTime.parse('0000-00-00 00:00:00.000');
  late Uri server;
  bool validURL = false;

  void trackingService() {
    timer = Timer.periodic(const Duration(milliseconds: 500), (Timer t) async {
      if (!tracking) {
        timer.cancel();
        trackMessage = 'Not currently tracking';
        return;
      }
      String? errormsg = await requestLocationPermission();
      Position newPosition = const Position(
          longitude: 0,
          latitude: 0,
          timestamp: null,
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0);
      setState(() {
        if (position.timestamp == null) trackMessage = 'Getting location...';
      });
      if (errormsg == null) {
        newPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best);
      }
      setState(() {
        if (errormsg != null) {
          trackMessage = errormsg;
        } else {
          position = newPosition;
          trackMessage =
              'Position: ${position.latitude}ºS ${position.longitude}ºW';
          now = position.timestamp?.toLocal() ?? DateTime.now().toLocal();
          uploadService();
        }
      });
    });
    setState(() {
      if (tracking) {
        tracking = false;
        trackMessage = 'Not currently tracking';
        timer.cancel();
      } else {
        tracking = true;
      }
    });
  }

  void uploadService() {
    http.post(
      server,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{
        'latitude': position.latitude,
        'longitude': position.longitude,
        'altitude': position.altitude,
        'accuracy': position.accuracy,
        'heading': position.heading,
        'speed': position.speed,
        'speedAccuracy': position.speedAccuracy,
        'timestamp': position.timestamp?.millisecondsSinceEpoch,
        'hashCode': position.hashCode,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    MobileScannerController cameraController = MobileScannerController();
    String hour = now.hour.toString();
    String minute = now.minute < 10 ? '0${now.minute}' : now.minute.toString();
    String second = now.second < 10 ? '0${now.second}' : now.second.toString();
    String millisecond = now.millisecond < 100
        ? '${now.millisecond}0'
        : now.millisecond < 10
            ? '${now.millisecond}00'
            : now.millisecond.toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Press the map button to start tracking your location',
            ),
            Text(
              tracking ? 'Tracking' : 'Not Tracking',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            TextField(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Server URL',
                errorText: validURL ? null : 'Invalid URL',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () => MobileScanner(
                    // fit: BoxFit.contain,
                    controller: cameraController,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.url != null) {
                          setState(() {
                            server = Uri.parse(barcode.url.toString());
                          });
                        }
                      }
                    },
                  ),
                ),
              ),
              onChanged: (String value) {
                setState(() {
                  if (Uri.tryParse(value) != null) {
                    server = Uri.parse(value);
                    validURL = true;
                  } else {
                    validURL = false;
                  }
                });
              },
              enabled: !tracking,
            ),
            Text(
              trackMessage,
            ),
            Text(
              tracking
                  ? 'Last updated: $hour:$minute:$second.$millisecond'
                  : '',
            ),
            Text(tracking
                ? "Accuracy: ${position.accuracy.toStringAsFixed(3)}m"
                : ''),
            Text(tracking
                ? "Speed: ${position.speed.toStringAsFixed(1)}m/s"
                : ''),
            Text(tracking
                ? "Heading: ${position.heading.toStringAsFixed(3)}º"
                : ''),
            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: validURL ? trackingService : null,
                  child: tracking
                      ? const Text('Stop tracking')
                      : const Text('Start tracking'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
