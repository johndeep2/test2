import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  double minDistanceMeters;   // Khoảng cách tối thiểu giữa 2 điểm
  double maxAccuracyMeters;   // Bỏ qua GPS nếu sai số lớn hơn
  int pointsPerSegment;       // Số điểm mỗi segment
  String coordFormat;         // 'decimal' hoặc 'dms'

  AppSettings({
    this.minDistanceMeters = 15,
    this.maxAccuracyMeters = 25,
    this.pointsPerSegment = 20,
    this.coordFormat = 'decimal',
  });

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      minDistanceMeters: prefs.getDouble('minDist') ?? 15,
      maxAccuracyMeters: prefs.getDouble('maxAcc') ?? 25,
      pointsPerSegment: prefs.getInt('ptsPerSeg') ?? 20,
      coordFormat: prefs.getString('coordFormat') ?? 'decimal',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('minDist', minDistanceMeters);
    await prefs.setDouble('maxAcc', maxAccuracyMeters);
    await prefs.setInt('ptsPerSeg', pointsPerSegment);
    await prefs.setString('coordFormat', coordFormat);
  }

  // Format tọa độ theo cài đặt
  String formatCoord(double lat, double lng) {
    if (coordFormat == 'dms') {
      return '${_toDMS(lat, true)}, ${_toDMS(lng, false)}';
    }
    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  String _toDMS(double value, bool isLat) {
    final dir = isLat ? (value >= 0 ? 'N' : 'S') : (value >= 0 ? 'E' : 'W');
    value = value.abs();
    final deg = value.floor();
    final minFull = (value - deg) * 60;
    final min = minFull.floor();
    final sec = ((minFull - min) * 60).toStringAsFixed(1);
    return '$deg°$min\'$sec" $dir';
  }
}
