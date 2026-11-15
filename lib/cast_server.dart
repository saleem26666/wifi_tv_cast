import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

typedef FrameCallback = void Function(Uint8List jpegBytes);
typedef StatusCallback = void Function(String message);

/// Local WiFi HTTPS + WebSocket server.
/// Laptop must open https://<phone-ip>:port/ (Chrome needs HTTPS for screen share).
class CastServer {
  HttpServer? _server;
  final Set<WebSocket> _sockets = {};
  FrameCallback? onFrame;
  StatusCallback? onStatus;
  int port;

  CastServer({this.port = 8443});

  bool get isRunning => _server != null;
  bool get isSecure => true;

  Future<SecurityContext> _securityContext() async {
    final cert = await rootBundle.load('assets/certs/cert.pem');
    final key = await rootBundle.load('assets/certs/key.pem');
    final context = SecurityContext();
    context.useCertificateChainBytes(cert.buffer.asUint8List());
    context.usePrivateKeyBytes(key.buffer.asUint8List());
    return context;
  }

  Future<void> start() async {
    await stop();
    final html = await rootBundle.loadString('assets/sender/index.html');
    final context = await _securityContext();
    _server = await HttpServer.bindSecure(
      InternetAddress.anyIPv4,
      port,
      context,
    );
    onStatus?.call('Listening on HTTPS port $port');
    _server!.listen((request) async {
      try {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _sockets.add(socket);
          onStatus?.call('Laptop connected');
          socket.listen(
            (data) {
              if (data is List<int>) {
                onFrame?.call(Uint8List.fromList(data));
              } else if (data is Uint8List) {
                onFrame?.call(data);
              }
            },
            onDone: () {
              _sockets.remove(socket);
              onStatus?.call('Laptop disconnected');
            },
            onError: (_) {
              _sockets.remove(socket);
              onStatus?.call('Laptop disconnected');
            },
            cancelOnError: true,
          );
          return;
        }

        final path = request.uri.path;
        if (path == '/' || path == '/index.html') {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write(html);
          await request.response.close();
          return;
        }

        request.response
          ..statusCode = 404
          ..write('Not found');
        await request.response.close();
      } catch (e) {
        onStatus?.call('Server error: $e');
        try {
          await request.response.close();
        } catch (_) {}
      }
    });
  }

  Future<void> stop() async {
    for (final s in _sockets.toList()) {
      try {
        await s.close();
      } catch (_) {}
    }
    _sockets.clear();
    await _server?.close(force: true);
    _server = null;
  }
}
