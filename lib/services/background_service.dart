import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/track_point.dart';
import '../models/app_settings.dart';

// Khởi tạo background service
Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'gps_tracker_channel',
      initialNotificationTitle: 'GPS Tracker',
      initialNotificationContent: 'Đang chạy nền...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

// Entry point của background service (chạy isolate riêng)
@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final settings = await AppSettings.load();

  List<TrackPoint> currentSegment = [];
  List<List<TrackPoint>> allSegments = [];
  Position? lastPosition;
  double totalDistance = 0;
  int totalPoints = 0;
  bool isRunning = true;

  // Lắng nghe lệnh dừng từ UI
  service.on('stop').listen((_) {
    isRunning = false;
    // Seal segment cuối nếu còn điểm
    if (currentSegment.length >= 2) {
      _sealSegment(currentSegment, allSegments, service, totalPoints, totalDistance);
    }
    service.stopSelf();
  });

  // Lắng nghe cập nhật settings từ UI
  service.on('updateSettings').listen((data) async {
    if (data == null) return;
    settings.minDistanceMeters = data['minDist'] ?? settings.minDistanceMeters;
    settings.maxAccuracyMeters = data['maxAcc'] ?? settings.maxAccuracyMeters;
    settings.pointsPerSegment = data['ptsPerSeg'] ?? settings.pointsPerSegment;
    await settings.save();
  });

  // Bắt đầu stream GPS
  final locationStream = Geolocator.getPositionStream(
    locationSettings: AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: settings.minDistanceMeters.toInt(), // OS lọc sơ bộ
      intervalDuration: const Duration(seconds: 2),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: 'GPS Tracker đang ghi đường đi',
        notificationTitle: 'GPS Tracker',
        enableWakeLock: true, // Giữ CPU hoạt động
      ),
    ),
  );

  await for (final position in locationStream) {
    if (!isRunning) break;

    // Lọc 1: Bỏ qua nếu GPS không đủ chính xác
    if (position.accuracy > settings.maxAccuracyMeters) continue;

    // Lọc 2: Bỏ qua tốc độ vô lý (> 250 km/h)
    if (position.speed > 69.4) continue;

    // Lọc 3: Kiểm tra khoảng cách thực
    if (lastPosition != null) {
      final dist = Geolocator.distanceBetween(
        lastPosition!.latitude, lastPosition!.longitude,
        position.latitude, position.longitude,
      );
      if (dist < settings.minDistanceMeters) continue;
      totalDistance += dist;
    }

    final point = TrackPoint(
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      speedKmh: position.speed * 3.6,
      time: DateTime.now(),
    );

    currentSegment.add(point);
    lastPosition = position;
    totalPoints++;

    // Update notification
    service.invoke('setAsForeground');

    // Gửi data về UI
    service.invoke('locationUpdate', {
      'lat': point.lat,
      'lng': point.lng,
      'accuracy': point.accuracy,
      'speed': point.speedKmh,
      'totalPoints': totalPoints,
      'totalDistance': totalDistance,
      'segmentCount': allSegments.length + 1,
      'currentSegPts': currentSegment.length,
      'ptsPerSeg': settings.pointsPerSegment,
    });

    // Auto seal segment
    if (currentSegment.length >= settings.pointsPerSegment) {
      _sealSegment(currentSegment, allSegments, service, totalPoints, totalDistance);
      currentSegment = [];
      lastPosition = null; // Segment mới bắt đầu độc lập
    }
  }
}

void _sealSegment(
  List<TrackPoint> pts,
  List<List<TrackPoint>> allSegments,
  ServiceInstance service,
  int totalPoints,
  double totalDistance,
) {
  final sealed = List<TrackPoint>.from(pts);
  allSegments.add(sealed);
  final url = Segment.buildUrl(sealed);

  service.invoke('segmentDone', {
    'segmentIndex': allSegments.length - 1,
    'pointCount': sealed.length,
    'url': url,
    'points': sealed.map((p) => p.toJson()).toList(),
  });
}
