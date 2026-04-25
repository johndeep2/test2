import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/track_point.dart';
import '../models/app_settings.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = FlutterBackgroundService();

  bool isTracking = false;
  int totalPoints = 0;
  int segmentCount = 0;
  int currentSegPts = 0;
  int ptsPerSeg = 20;
  double totalDistance = 0;
  double accuracy = 0;
  double speed = 0;
  double lat = 0, lng = 0;

  List<Segment> segments = [];
  AppSettings settings = AppSettings();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _listenToService();
  }

  Future<void> _loadSettings() async {
    settings = await AppSettings.load();
    setState(() { ptsPerSeg = settings.pointsPerSegment; });
  }

  void _listenToService() {
    _service.on('locationUpdate').listen((data) {
      if (data == null || !mounted) return;
      setState(() {
        lat = data['lat'] ?? 0;
        lng = data['lng'] ?? 0;
        accuracy = data['accuracy'] ?? 0;
        speed = data['speed'] ?? 0;
        totalPoints = data['totalPoints'] ?? 0;
        totalDistance = (data['totalDistance'] ?? 0).toDouble();
        segmentCount = data['segmentCount'] ?? 0;
        currentSegPts = data['currentSegPts'] ?? 0;
        ptsPerSeg = data['ptsPerSeg'] ?? ptsPerSeg;
      });
    });

    _service.on('segmentDone').listen((data) {
      if (data == null || !mounted) return;
      final seg = Segment(
        index: data['segmentIndex'],
        points: (data['points'] as List)
            .map((p) => TrackPoint.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
        googleMapsUrl: data['url'],
        createdAt: DateTime.now(),
      );
      setState(() { segments.add(seg); });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Segment ${seg.index + 1} hoàn thành! (${seg.points.length} điểm)'),
        backgroundColor: const Color(0xFF2EA043),
        duration: const Duration(seconds: 3),
      ));
    });
  }

  Future<void> _startTracking() async {
    // Kiểm tra quyền GPS
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      _showPermissionDialog();
      return;
    }

    await WakelockPlus.enable();
    await _service.startService();
    setState(() { isTracking = true; });
  }

  void _stopTracking() {
    _service.invoke('stop');
    WakelockPlus.disable();
    setState(() { isTracking = false; });
  }

  void _clearAll() {
    if (isTracking) _stopTracking();
    setState(() {
      segments.clear();
      totalPoints = 0; segmentCount = 0;
      currentSegPts = 0; totalDistance = 0;
      accuracy = 0; speed = 0;
    });
  }

  void _showPermissionDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      title: const Text('Cần quyền GPS', style: TextStyle(color: Colors.white)),
      content: const Text(
        'Vào Settings → Apps → GPS Tracker → Permissions → Location → "Allow all the time"',
        style: TextStyle(color: Color(0xFF8B949E)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        TextButton(
          onPressed: () { Geolocator.openAppSettings(); Navigator.pop(context); },
          child: const Text('Mở Settings', style: TextStyle(color: Color(0xFF2EA043))),
        ),
      ],
    ));
  }

  String _formatDist(double m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(2)} km';
    return '${m.toStringAsFixed(0)} m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('GPS Tracker', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(
              isTracking
                ? 'Đang ghi... Seg $segmentCount  ($currentSegPts/$ptsPerSeg điểm)'
                : 'Nhấn Bắt đầu để ghi đường đi',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
            ),
          ],
        ),
        actions: [
          // Tracking indicator
          if (isTracking)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: const _PulseDot(),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(context,
                MaterialPageRoute(builder: (_) => SettingsScreen(settings: settings)));
              await _loadSettings();
              if (isTracking) {
                _service.invoke('updateSettings', {
                  'minDist': settings.minDistanceMeters,
                  'maxAcc': settings.maxAccuracyMeters,
                  'ptsPerSeg': settings.pointsPerSegment,
                });
              }
            },
          ),
        ],
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF30363D)),
        ),
      ),
      body: Column(children: [
        // Stats
        _StatsRow(
          totalPoints: totalPoints,
          segmentCount: segmentCount,
          totalDistance: _formatDist(totalDistance),
          accuracy: accuracy,
          speed: speed,
          lat: lat, lng: lng,
          settings: settings,
        ),

        // Segments list
        Expanded(
          child: segments.isEmpty
            ? _EmptyState(isTracking: isTracking)
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: segments.length,
                itemBuilder: (_, i) => _SegmentCard(
                  segment: segments[i],
                  settings: settings,
                ),
              ),
        ),

        // Controls
        _ControlBar(
          isTracking: isTracking,
          onStart: _startTracking,
          onStop: _stopTracking,
          onClear: _clearAll,
        ),
      ]),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => FadeTransition(
    opacity: _ctrl,
    child: Container(width: 10, height: 10,
      decoration: const BoxDecoration(color: Color(0xFF3FB950), shape: BoxShape.circle)),
  );
}

class _StatsRow extends StatelessWidget {
  final int totalPoints, segmentCount;
  final String totalDistance;
  final double accuracy, speed, lat, lng;
  final AppSettings settings;

  const _StatsRow({
    required this.totalPoints, required this.segmentCount,
    required this.totalDistance, required this.accuracy,
    required this.speed, required this.lat, required this.lng,
    required this.settings,
  });

  @override Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(children: [
        Row(children: [
          _StatBox('Tổng điểm', '$totalPoints', const Color(0xFF2EA043)),
          const SizedBox(width: 8),
          _StatBox('Segment', '$segmentCount', const Color(0xFF388BFD)),
          const SizedBox(width: 8),
          _StatBox('Quãng đường', totalDistance, const Color(0xFFD29922)),
          const SizedBox(width: 8),
          _StatBox('GPS sai số', accuracy > 0 ? '${accuracy.toStringAsFixed(0)}m' : '—', const Color(0xFF8957E5)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.speed, size: 14, color: Color(0xFF8B949E)),
          const SizedBox(width: 4),
          Text('${speed.toStringAsFixed(1)} km/h', style: const TextStyle(fontSize: 12, color: Color(0xFFE6EDF3))),
          const SizedBox(width: 16),
          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF8B949E)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              lat != 0 ? settings.formatCoord(lat, lng) : 'Chờ tín hiệu GPS...',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E), fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox(this.label, this.value, this.color);
  @override Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF1C2128),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF30363D)),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF8B949E)), textAlign: TextAlign.center),
    ]),
  ));
}

class _EmptyState extends StatelessWidget {
  final bool isTracking;
  const _EmptyState({required this.isTracking});
  @override Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.route, size: 64, color: Color(0xFF30363D)),
      const SizedBox(height: 16),
      Text(
        isTracking ? 'Đang chờ tín hiệu GPS...\nHãy di chuyển để ghi điểm' : 'Nhấn Bắt đầu để ghi đường đi\nMỗi segment = 1 link Google Maps',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 14, height: 1.6),
      ),
    ],
  ));
}

class _SegmentCard extends StatelessWidget {
  final Segment segment;
  final AppSettings settings;
  const _SegmentCard({required this.segment, required this.settings});

  static const List<Color> colors = [
    Color(0xFF2EA043), Color(0xFF388BFD), Color(0xFFD29922),
    Color(0xFF8957E5), Color(0xFF2DD4BF), Color(0xFFDA3633),
  ];

  @override Widget build(BuildContext context) {
    final color = colors[segment.index % colors.length];
    final first = segment.points.first;
    final last = segment.points.last;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('Segment ${segment.index + 1}',
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
            const Spacer(),
            Text('${segment.points.length} điểm',
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
          ]),
        ),

        // From → To
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(children: [
            const Icon(Icons.radio_button_checked, size: 12, color: Color(0xFF3FB950)),
            const SizedBox(width: 6),
            Expanded(child: Text(settings.formatCoord(first.lat, first.lng),
              style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E), fontFamily: 'monospace'))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(children: [
            const Icon(Icons.location_on, size: 12, color: Color(0xFFD29922)),
            const SizedBox(width: 6),
            Expanded(child: Text(settings.formatCoord(last.lat, last.lng),
              style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E), fontFamily: 'monospace'))),
          ]),
        ),

        // Buttons
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF30363D))),
          ),
          child: Row(children: [
            Expanded(child: TextButton.icon(
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('Copy Link', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF8B949E)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: segment.googleMapsUrl));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Đã copy!'), duration: Duration(seconds: 1)));
              },
            )),
            Container(width: 1, height: 36, color: const Color(0xFF30363D)),
            Expanded(child: TextButton.icon(
              icon: const Icon(Icons.map_outlined, size: 14),
              label: const Text('Mở Maps', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF388BFD)),
              onPressed: () async {
                final uri = Uri.parse(segment.googleMapsUrl);
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
            )),
          ]),
        ),
      ]),
    );
  }
}

class _ControlBar extends StatelessWidget {
  final bool isTracking;
  final VoidCallback onStart, onStop, onClear;
  const _ControlBar({required this.isTracking, required this.onStart, required this.onStop, required this.onClear});

  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(children: [
        Expanded(child: ElevatedButton(
          onPressed: isTracking ? null : onStart,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2EA043),
            disabledBackgroundColor: const Color(0xFF1C2128),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('▶  Bắt đầu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        )),
        const SizedBox(width: 10),
        Expanded(child: ElevatedButton(
          onPressed: isTracking ? onStop : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDA3633),
            disabledBackgroundColor: const Color(0xFF1C2128),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('■  Dừng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        )),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: onClear,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1C2128),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFF30363D))),
          ),
          child: const Icon(Icons.delete_outline, color: Color(0xFF8B949E)),
        ),
      ]),
    );
  }
}
