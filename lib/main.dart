import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'cast_server.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);
  runApp(const TvWifiCastApp());
}

class TvWifiCastApp extends StatelessWidget {
  const TvWifiCastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TV WiFi Cast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D9CF0),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _server = CastServer(port: 8443);
  String? _ip;
  String _status = 'Tap Start receiver';
  bool _running = false;
  bool _casting = false;
  Uint8List? _frame;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _refreshIp();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _server.stop();
    super.dispose();
  }

  Future<void> _refreshIp() async {
    String? ip;
    try {
      for (final iface in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      )) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final v = addr.address;
          // Prefer common LAN ranges.
          if (v.startsWith('192.168.') ||
              v.startsWith('10.') ||
              RegExp(r'^172\.(1[6-9]|2\d|3[0-1])\.').hasMatch(v)) {
            ip = v;
            break;
          }
          ip ??= v;
        }
        if (ip != null &&
            (ip.startsWith('192.168.') || ip.startsWith('10.'))) {
          break;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _ip = ip);
  }

  Future<void> _start() async {
    await _refreshIp();
    _server.onStatus = (msg) {
      if (!mounted) return;
      setState(() {
        _status = msg;
        if (msg.toLowerCase().contains('disconnected')) {
          _casting = false;
        }
      });
    };
    _server.onFrame = (bytes) {
      if (!mounted) return;
      final now = DateTime.now();
      // Drop frames if UI is busy (keep ~12 fps display).
      if (now.difference(_lastFrameAt).inMilliseconds < 70) return;
      _lastFrameAt = now;
      setState(() {
        _frame = bytes;
        _casting = true;
        _status = 'Casting from laptop…';
      });
    };
    try {
      await _server.start();
      await WakelockPlus.enable();
      if (!mounted) return;
      setState(() {
        _running = true;
        _status = 'Waiting for laptop…';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _status = 'Start fail: $e';
      });
    }
  }

  Future<void> _stop() async {
    await _server.stop();
    await WakelockPlus.disable();
    if (!mounted) return;
    setState(() {
      _running = false;
      _casting = false;
      _frame = null;
      _status = 'Stopped';
    });
  }

  String get _url {
    final ip = _ip ?? '…';
    return 'https://$ip:8443';
  }

  @override
  Widget build(BuildContext context) {
    if (_casting && _frame != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              minScale: 1,
              maxScale: 3,
              child: Center(
                child: Image.memory(
                  _frame!,
                  gaplessPlayback: true,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: FilledButton.tonal(
                onPressed: _stop,
                child: const Text('Stop cast'),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F1419), Color(0xFF1A2A40), Color(0xFF0F1419)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 700;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _brandBlock()),
                            const SizedBox(width: 28),
                            Expanded(child: _stepsBlock()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _brandBlock(),
                            const SizedBox(height: 22),
                            _stepsBlock(),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _brandBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TV WiFi Cast',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Colors.white.withValues(alpha: 0.96),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Laptop screen → TV / phone over same WiFi',
          style: TextStyle(
            fontSize: 16,
            height: 1.35,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Open this HTTPS address on your laptop (Chrome / Edge)',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                _url,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7EC8FF),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _status,
                style: TextStyle(
                  fontSize: 14,
                  color: _running
                      ? const Color(0xFF3DD68C)
                      : Colors.white.withValues(alpha: 0.65),
                ),
              ),
              if (_ip == null) ...[
                const SizedBox(height: 8),
                Text(
                  'No WiFi IP found — connect this device to WiFi (not mobile data).',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade200,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _running ? null : _start,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: const Color(0xFF3D9CF0),
                  foregroundColor: const Color(0xFF041018),
                ),
                child: const Text('Start receiver'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _running ? _stop : _refreshIp,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: Text(_running ? 'Stop' : 'Refresh IP'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepsBlock() {
    const steps = [
      ('1', 'Install this free app on Android TV (or phone). Tap Start receiver.'),
      ('2', 'Laptop + TV on the same WiFi.'),
      ('3', 'On laptop run: wifi_tv_cast\\laptop_sender\\Start_Full_Screen_Cast.bat'),
      ('4', 'Type the IP shown above — full laptop screen appears on TV (no paid trial).'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Android TV / phone — free full screen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 12),
        for (final s in steps) ...[
          _step(s.$1, s.$2),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        Text(
          'Works on Android TV boxes/sticks (the device Chrome shows as AndroidTV). Not for Samsung Tizen TVs. No subscription — keep using the laptop sender for full desktop.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _step(String n, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF3D9CF0).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            n,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF7EC8FF),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ),
      ],
    );
  }
}
