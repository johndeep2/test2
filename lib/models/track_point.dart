class TrackPoint {
  final double lat;
  final double lng;
  final double accuracy;
  final double speedKmh;
  final DateTime time;

  TrackPoint({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.speedKmh,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
    'lat': lat, 'lng': lng,
    'accuracy': accuracy, 'speed': speedKmh,
    'time': time.toIso8601String(),
  };

  factory TrackPoint.fromJson(Map<String, dynamic> j) => TrackPoint(
    lat: j['lat'], lng: j['lng'],
    accuracy: j['accuracy'], speedKmh: j['speed'],
    time: DateTime.parse(j['time']),
  );

  String get coordString => '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
  String get timeString {
    final h = time.hour.toString().padLeft(2,'0');
    final m = time.minute.toString().padLeft(2,'0');
    final s = time.second.toString().padLeft(2,'0');
    return '$h:$m:$s';
  }
}

class Segment {
  final int index;
  final List<TrackPoint> points;
  final String googleMapsUrl;
  final DateTime createdAt;

  Segment({
    required this.index,
    required this.points,
    required this.googleMapsUrl,
    required this.createdAt,
  });

  static String buildUrl(List<TrackPoint> pts) {
    final waypoints = pts.map((p) => p.coordString).join('/');
    return 'https://www.google.com/maps/dir/$waypoints/';
  }
}
