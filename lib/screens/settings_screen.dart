import 'package:flutter/material.dart';
import '../models/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  const SettingsScreen({super.key, required this.settings});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double minDist;
  late double maxAcc;
  late int ptsPerSeg;
  late String coordFormat;

  @override void initState() {
    super.initState();
    minDist = widget.settings.minDistanceMeters;
    maxAcc = widget.settings.maxAccuracyMeters;
    ptsPerSeg = widget.settings.pointsPerSegment;
    coordFormat = widget.settings.coordFormat;
  }

  Future<void> _save() async {
    widget.settings.minDistanceMeters = minDist;
    widget.settings.maxAccuracyMeters = maxAcc;
    widget.settings.pointsPerSegment = ptsPerSeg;
    widget.settings.coordFormat = coordFormat;
    await widget.settings.save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Đã lưu cài đặt'),
        backgroundColor: Color(0xFF2EA043),
        duration: Duration(seconds: 2),
      ));
      Navigator.pop(context);
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Cài đặt', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF30363D)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Khoảng cách tối thiểu ──
          _SectionHeader('Ghi điểm mỗi bao nhiêu mét?'),
          _SettingCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Khoảng cách tối thiểu', style: TextStyle(color: Colors.white, fontSize: 14)),
              _Badge('${minDist.toStringAsFixed(0)} m', const Color(0xFF2EA043)),
            ]),
            const SizedBox(height: 4),
            const Text('Chỉ ghi điểm khi di chuyển đủ xa.\nĐi bộ: 10-15m | Xe máy: 20-30m | Ô tô: 30-50m',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, height: 1.5)),
            Slider(
              value: minDist,
              min: 5, max: 100,
              divisions: 19,
              activeColor: const Color(0xFF2EA043),
              inactiveColor: const Color(0xFF30363D),
              label: '${minDist.toStringAsFixed(0)}m',
              onChanged: (v) => setState(() => minDist = v),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
              Text('5m', style: TextStyle(fontSize: 10, color: Color(0xFF8B949E))),
              Text('50m', style: TextStyle(fontSize: 10, color: Color(0xFF8B949E))),
              Text('100m', style: TextStyle(fontSize: 10, color: Color(0xFF8B949E))),
            ]),
          ])),

          const SizedBox(height: 12),

          // ── Độ chính xác GPS ──
          _SectionHeader('Lọc GPS kém chính xác'),
          _SettingCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Bỏ qua nếu sai số GPS >', style: TextStyle(color: Colors.white, fontSize: 14)),
              _Badge('${maxAcc.toStringAsFixed(0)} m', const Color(0xFF8957E5)),
            ]),
            const SizedBox(height: 4),
            const Text('Trong nhà / tòa nhà GPS hay bị sai nhiều.\nGiá trị thấp = chính xác hơn nhưng ít điểm hơn.',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, height: 1.5)),
            Slider(
              value: maxAcc,
              min: 5, max: 100,
              divisions: 19,
              activeColor: const Color(0xFF8957E5),
              inactiveColor: const Color(0xFF30363D),
              label: '${maxAcc.toStringAsFixed(0)}m',
              onChanged: (v) => setState(() => maxAcc = v),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
              Text('5m (chặt)', style: TextStyle(fontSize: 10, color: Color(0xFF8B949E))),
              Text('50m', style: TextStyle(fontSize: 10, color: Color(0xFF8B949E))),
              Text('100m (lỏng)', style: TextStyle(fontSize: 10, color: Color(0xFF8B949E))),
            ]),
          ])),

          const SizedBox(height: 12),

          // ── Số điểm mỗi segment ──
          _SectionHeader('Số điểm mỗi segment (link Google Maps)'),
          _SettingCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Điểm mỗi segment', style: TextStyle(color: Colors.white, fontSize: 14)),
              _Badge('$ptsPerSeg điểm', const Color(0xFF388BFD)),
            ]),
            const SizedBox(height: 4),
            const Text('Google Maps hỗ trợ tối đa 20 điểm/link.\nĐường xa nên để 20 điểm để tạo nhiều segment.',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, height: 1.5)),
            Slider(
              value: ptsPerSeg.toDouble(),
              min: 5, max: 20,
              divisions: 15,
              activeColor: const Color(0xFF388BFD),
              inactiveColor: const Color(0xFF30363D),
              label: '$ptsPerSeg điểm',
              onChanged: (v) => setState(() => ptsPerSeg = v.round()),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
              Text('5 (ngắn)', style: TextStyle(fontSize: 10, color: Color(0xFF8B949E))),
              Text('10', style: TextStyle(fontSize: 10, color: Color(0xFF8B949E))),
              Text('20 (tối đa)', style: TextStyle(fontSize: 10, color: Color(0xFF8B949E))),
            ]),
          ])),

          const SizedBox(height: 12),

          // ── Định dạng tọa độ ──
          _SectionHeader('Định dạng tọa độ hiển thị'),
          _SettingCard(child: Column(children: [
            _FormatOption(
              title: 'Decimal Degrees',
              subtitle: '21.028511, 105.854157',
              value: 'decimal',
              groupValue: coordFormat,
              color: const Color(0xFF2EA043),
              onChanged: (v) => setState(() => coordFormat = v!),
            ),
            const Divider(color: Color(0xFF30363D), height: 1),
            _FormatOption(
              title: 'Degrees Minutes Seconds',
              subtitle: '21°1\'42.6" N, 105°51\'14.9" E',
              value: 'dms',
              groupValue: coordFormat,
              color: const Color(0xFF2EA043),
              onChanged: (v) => setState(() => coordFormat = v!),
            ),
          ])),

          const SizedBox(height: 24),

          // Preset buttons
          _SectionHeader('Cài đặt nhanh theo kiểu di chuyển'),
          Row(children: [
            _PresetBtn('🚶 Đi bộ', () => setState(() { minDist=10; maxAcc=20; ptsPerSeg=20; })),
            const SizedBox(width: 8),
            _PresetBtn('🛵 Xe máy', () => setState(() { minDist=25; maxAcc=30; ptsPerSeg=20; })),
            const SizedBox(width: 8),
            _PresetBtn('🚗 Ô tô', () => setState(() { minDist=50; maxAcc=40; ptsPerSeg=20; })),
          ]),

          const SizedBox(height: 24),

          // Save button
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2EA043),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Lưu cài đặt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E),
      fontWeight: FontWeight.w600, letterSpacing: 0.3)),
  );
}

class _SettingCard extends StatelessWidget {
  final Widget child;
  const _SettingCard({required this.child});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF30363D)),
    ),
    child: child,
  );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
  );
}

class _FormatOption extends StatelessWidget {
  final String title, subtitle, value, groupValue;
  final Color color;
  final ValueChanged<String?> onChanged;
  const _FormatOption({required this.title, required this.subtitle, required this.value,
    required this.groupValue, required this.color, required this.onChanged});
  @override Widget build(BuildContext context) => RadioListTile<String>(
    title: Text(title, style: const TextStyle(fontSize: 13, color: Colors.white)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E), fontFamily: 'monospace')),
    value: value, groupValue: groupValue,
    activeColor: color,
    onChanged: onChanged,
    contentPadding: EdgeInsets.zero,
    dense: true,
  );
}

class _PresetBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PresetBtn(this.label, this.onTap);
  @override Widget build(BuildContext context) => Expanded(child: OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFE6EDF3),
      side: const BorderSide(color: Color(0xFF30363D)),
      padding: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(label, style: const TextStyle(fontSize: 12)),
  ));
}
