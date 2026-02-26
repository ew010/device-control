import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const RemoteControlApp());
}

class RemoteControlApp extends StatelessWidget {
  const RemoteControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cross Device Control',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A6C74)),
      ),
      home: const RoleSelectPage(),
    );
  }
}

class RoleSelectPage extends StatelessWidget {
  const RoleSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('跨设备控制工具')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              '一台设备作为“被控端”(Agent)，另一台设备作为“控制端”(Controller) 连接后发送控制指令。',
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _RoleCard(
                    title: '被控端',
                    subtitle: '启动监听，接收控制命令',
                    icon: Icons.phonelink_setup,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AgentPage(),
                        ),
                      );
                    },
                  ),
                  _RoleCard(
                    title: '控制端',
                    subtitle: '连接远端并发送触控/文本',
                    icon: Icons.control_camera,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ControllerPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Text(
              '提示：iPad 对“控制其他设备”能力受系统限制，本项目默认提供安全协议层与事件通道。',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 36),
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }
}

class AgentPage extends StatefulWidget {
  const AgentPage({super.key});

  @override
  State<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends State<AgentPage> {
  final AgentServer _server = AgentServer();
  final TextEditingController _portController = TextEditingController(
    text: '8888',
  );
  final TextEditingController _pairCodeController = TextEditingController(
    text: AgentServer.generatePairCode(),
  );

  @override
  void dispose() {
    _portController.dispose();
    _pairCodeController.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _toggleServer() async {
    if (_server.running) {
      await _server.stop();
      setState(() {});
      return;
    }
    final int? port = int.tryParse(_portController.text);
    if (port == null || port < 1 || port > 65535) {
      _showSnack('端口无效');
      return;
    }
    final pairCode = _pairCodeController.text.trim();
    if (pairCode.length < 4) {
      _showSnack('配对码至少 4 位');
      return;
    }
    try {
      await _server.start(port, pairCode: pairCode);
      setState(() {});
    } catch (e) {
      _showSnack('启动失败: $e');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('被控端')),
      body: AnimatedBuilder(
        animation: _server,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '端口'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _pairCodeController,
                        decoration: const InputDecoration(labelText: '配对码'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _toggleServer,
                      child: Text(_server.running ? '停止' : '启动'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('状态: ${_server.running ? '运行中' : '未启动'}'),
                if (_server.running)
                  Text(
                    '连接地址: ${_server.addresses.map((e) => 'ws://$e:${_server.port}').join('  |  ')}',
                  ),
                const SizedBox(height: 8),
                Text('连接设备数: ${_server.clientCount}'),
                Text('已授权设备数: ${_server.authorizedClientCount}'),
                const SizedBox(height: 16),
                const Text('最近命令:'),
                const SizedBox(height: 8),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      reverse: true,
                      itemCount: _server.logs.length,
                      itemBuilder: (context, index) {
                        final log =
                            _server.logs[_server.logs.length - 1 - index];
                        return ListTile(dense: true, title: Text(log));
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key});

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> {
  final ControllerClient _client = ControllerClient();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: '8888',
  );
  final TextEditingController _pairCodeController = TextEditingController();
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _pairCodeController.dispose();
    _textController.dispose();
    _client.dispose();
    super.dispose();
  }

  Future<void> _connectOrDisconnect() async {
    if (_client.connected) {
      await _client.disconnect();
      setState(() {});
      return;
    }

    final host = _hostController.text.trim();
    final int? port = int.tryParse(_portController.text);
    final pairCode = _pairCodeController.text.trim();
    if (host.isEmpty || port == null || pairCode.isEmpty) {
      _showSnack('请输入被控端IP、端口和配对码');
      return;
    }

    try {
      await _client.connect(host: host, port: port, pairCode: pairCode);
      setState(() {});
    } catch (e) {
      _showSnack('连接失败: $e');
    }
  }

  void _sendText() {
    final text = _textController.text;
    if (text.isEmpty) {
      return;
    }
    _client.sendCommand({'type': 'command', 'command': 'text', 'text': text});
    _textController.clear();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('控制端')),
      body: AnimatedBuilder(
        animation: _client,
        builder: (context, _) {
          final state = _client.lastState;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _hostController,
                        decoration: const InputDecoration(labelText: '被控端IP'),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '端口'),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _pairCodeController,
                        decoration: const InputDecoration(labelText: '配对码'),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _connectOrDisconnect,
                      child: Text(_client.connected ? '断开' : '连接'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('连接状态: ${_client.connected ? '已连接' : '未连接'}'),
                Text('鉴权状态: ${_client.authenticated ? '已授权' : '未授权'}'),
                Text('会话信息: ${_client.sessionMessage}'),
                const SizedBox(height: 12),
                Expanded(
                  child: RemoteSurface(
                    state: state,
                    onTap: (point) {
                      _client.sendCommand({
                        'type': 'command',
                        'command': 'tap',
                        'x': point.dx,
                        'y': point.dy,
                      });
                    },
                    onDrag: (from, to) {
                      _client.sendCommand({
                        'type': 'command',
                        'command': 'drag',
                        'fromX': from.dx,
                        'fromY': from.dy,
                        'toX': to.dx,
                        'toY': to.dy,
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          labelText: '发送文本命令',
                          hintText: '例如: 打开设置',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _sendText,
                      child: const Text('发送'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '最后回传: ${state?.lastCommand ?? '-'} ${state != null ? '@(${state.cursor.dx.toStringAsFixed(2)}, ${state.cursor.dy.toStringAsFixed(2)})' : ''}',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class RemoteSurface extends StatefulWidget {
  const RemoteSurface({
    super.key,
    required this.state,
    required this.onTap,
    required this.onDrag,
  });

  final RemoteState? state;
  final ValueChanged<Offset> onTap;
  final void Function(Offset from, Offset to) onDrag;

  @override
  State<RemoteSurface> createState() => _RemoteSurfaceState();
}

class _RemoteSurfaceState extends State<RemoteSurface> {
  Offset? _dragStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (details) {
            widget.onTap(
              _toNormalized(details.localPosition, constraints.biggest),
            );
          },
          onPanStart: (details) {
            _dragStart = _toNormalized(
              details.localPosition,
              constraints.biggest,
            );
          },
          onPanEnd: (_) {
            _dragStart = null;
          },
          onPanUpdate: (details) {
            final from = _dragStart;
            if (from == null) {
              return;
            }
            final to = _toNormalized(
              details.localPosition,
              constraints.biggest,
            );
            widget.onDrag(from, to);
          },
          child: CustomPaint(
            painter: _RemotePainter(widget.state),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  Offset _toNormalized(Offset local, Size size) {
    final x = (local.dx / max(size.width, 1)).clamp(0.0, 1.0);
    final y = (local.dy / max(size.height, 1)).clamp(0.0, 1.0);
    return Offset(x, y);
  }
}

class _RemotePainter extends CustomPainter {
  const _RemotePainter(this.state);

  final RemoteState? state;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFECFEFF), Color(0xFFE0F2F1), Color(0xFFEAF4FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final grid = Paint()
      ..color = const Color(0xFF99AAB5)
      ..strokeWidth = 0.6;
    for (int i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final cursor = state?.cursor ?? const Offset(0.5, 0.5);
    final p = Offset(cursor.dx * size.width, cursor.dy * size.height);

    final pointer = Paint()..color = const Color(0xFF0A6C74);
    canvas.drawCircle(p, 18, pointer..color = const Color(0x330A6C74));
    canvas.drawCircle(p, 9, pointer..color = const Color(0xFF0A6C74));

    final textPainter = TextPainter(
      text: TextSpan(
        text: state?.lastCommand ?? '等待命令',
        style: const TextStyle(color: Colors.black87, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 24);

    textPainter.paint(canvas, const Offset(12, 12));
  }

  @override
  bool shouldRepaint(covariant _RemotePainter oldDelegate) =>
      oldDelegate.state != state;
}

class ControllerClient extends ChangeNotifier {
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  RemoteState? lastState;
  bool authenticated = false;
  String sessionMessage = '未连接';

  bool get connected => _socket != null;

  Future<void> connect({
    required String host,
    required int port,
    required String pairCode,
  }) async {
    await disconnect();
    final socket = await WebSocket.connect('ws://$host:$port');
    _socket = socket;
    authenticated = false;
    sessionMessage = '连接成功，等待鉴权';
    _subscription = socket.listen(
      _onMessage,
      onError: (_) => disconnect(),
      onDone: () => disconnect(),
      cancelOnError: true,
    );
    sendCommand({
      'type': 'hello',
      'device': Platform.operatingSystem,
      'pairCode': pairCode,
    });
    notifyListeners();
  }

  void sendCommand(Map<String, dynamic> command) {
    if (command['type'] == 'command' && !authenticated) {
      sessionMessage = '未鉴权，命令已拦截';
      notifyListeners();
      return;
    }
    _socket?.add(jsonEncode(command));
  }

  void _onMessage(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      if (map['type'] == 'state') {
        lastState = RemoteState.fromJson(map);
        notifyListeners();
      } else if (map['type'] == 'auth_ok') {
        authenticated = true;
        sessionMessage = '鉴权成功';
        notifyListeners();
      } else if (map['type'] == 'auth_error') {
        authenticated = false;
        sessionMessage = map['message'] as String? ?? '鉴权失败';
        notifyListeners();
        unawaited(disconnect());
      }
    } catch (_) {
      // Ignore malformed payloads to keep session alive.
    }
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    authenticated = false;
    sessionMessage = '连接已断开';
    await _subscription?.cancel();
    _subscription = null;
    await socket?.close();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(disconnect());
    super.dispose();
  }
}

class AgentServer extends ChangeNotifier {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final Set<WebSocket> _authorizedClients = {};
  final List<String> logs = [];
  String _pairCode = '';
  RemoteState _state = const RemoteState(
    cursor: Offset(0.5, 0.5),
    lastCommand: 'idle',
  );

  bool get running => _server != null;
  int get clientCount => _clients.length;
  int get authorizedClientCount => _authorizedClients.length;
  int get port => _server?.port ?? 0;
  String get pairCode => _pairCode;

  List<String> get addresses {
    final base = <String>{'127.0.0.1'};
    for (final interface in _interfaces) {
      for (final addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4) {
          base.add(addr.address);
        }
      }
    }
    return base.toList()..sort();
  }

  List<NetworkInterface> _interfaces = [];

  static String generatePairCode() {
    final n = Random().nextInt(900000) + 100000;
    return '$n';
  }

  Future<void> start(int port, {required String pairCode}) async {
    _interfaces = await NetworkInterface.list();
    _pairCode = pairCode;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_onRequest);
    _appendLog('Server started on port $port with pairing enabled');
    notifyListeners();
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;

    for (final c in List<WebSocket>.from(_clients)) {
      await c.close();
    }
    _clients.clear();
    _authorizedClients.clear();
    await server?.close(force: true);
    _appendLog('Server stopped');
    notifyListeners();
  }

  void _onRequest(HttpRequest request) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then(_handleClient);
      return;
    }

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.text
      ..write('phonecontrol-agent-ok')
      ..close();
  }

  void _handleClient(WebSocket socket) {
    _clients.add(socket);
    _appendLog('Client connected (${_clients.length}), waiting auth');
    notifyListeners();

    socket.listen(
      (raw) => _onClientMessage(socket, raw),
      onDone: () {
        _clients.remove(socket);
        _authorizedClients.remove(socket);
        _appendLog('Client disconnected (${_clients.length})');
        notifyListeners();
      },
      onError: (_) {
        _clients.remove(socket);
        _authorizedClients.remove(socket);
        notifyListeners();
      },
      cancelOnError: true,
    );
  }

  void _onClientMessage(WebSocket socket, dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      if (data['type'] == 'command') {
        if (!_authorizedClients.contains(socket)) {
          socket.add(jsonEncode({'type': 'auth_error', 'message': '未授权的命令请求'}));
          _appendLog('Blocked command from unauthorized client');
          return;
        }
        _applyCommand(data);
      } else if (data['type'] == 'hello') {
        final incomingCode = (data['pairCode'] as String? ?? '').trim();
        if (incomingCode != _pairCode) {
          socket.add(
            jsonEncode({'type': 'auth_error', 'message': '配对码错误，连接已拒绝'}),
          );
          _appendLog('Auth failed for ${data['device'] ?? 'unknown'}');
          unawaited(
            socket.close(WebSocketStatus.policyViolation, 'auth-failed'),
          );
          return;
        }
        _authorizedClients.add(socket);
        socket.add(jsonEncode({'type': 'auth_ok'}));
        _appendLog('Auth success from ${data['device'] ?? 'unknown'}');
        _emitState(to: socket);
      }
    } catch (_) {
      _appendLog('Invalid payload ignored');
    }
    notifyListeners();
  }

  void _applyCommand(Map<String, dynamic> data) {
    final command = data['command'] as String? ?? 'unknown';
    switch (command) {
      case 'tap':
        _state = RemoteState(
          cursor: Offset(_toDouble(data['x']), _toDouble(data['y'])),
          lastCommand: 'tap',
        );
      case 'drag':
        _state = RemoteState(
          cursor: Offset(_toDouble(data['toX']), _toDouble(data['toY'])),
          lastCommand: 'drag',
        );
      case 'text':
        _state = RemoteState(
          cursor: _state.cursor,
          lastCommand: 'text: ${(data['text'] as String? ?? '').trim()}',
        );
      default:
        _state = RemoteState(cursor: _state.cursor, lastCommand: command);
    }
    _appendLog('cmd: ${_state.lastCommand} @ ${_state.cursor}');
    _emitState();
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble().clamp(0.0, 1.0);
    }
    return 0.0;
  }

  void _emitState({WebSocket? to}) {
    final payload = jsonEncode(_state.toJson());
    if (to != null) {
      if (!_authorizedClients.contains(to)) {
        return;
      }
      to.add(payload);
      return;
    }
    for (final client in _authorizedClients) {
      client.add(payload);
    }
  }

  void _appendLog(String log) {
    logs.add('[${DateTime.now().toIso8601String()}] $log');
    if (logs.length > 200) {
      logs.removeRange(0, logs.length - 200);
    }
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}

class RemoteState {
  const RemoteState({required this.cursor, required this.lastCommand});

  final Offset cursor;
  final String lastCommand;

  Map<String, dynamic> toJson() => {
    'type': 'state',
    'x': cursor.dx,
    'y': cursor.dy,
    'lastCommand': lastCommand,
    'ts': DateTime.now().millisecondsSinceEpoch,
  };

  factory RemoteState.fromJson(Map<String, dynamic> json) {
    return RemoteState(
      cursor: Offset(
        (json['x'] as num? ?? 0.5).toDouble().clamp(0.0, 1.0),
        (json['y'] as num? ?? 0.5).toDouble().clamp(0.0, 1.0),
      ),
      lastCommand: json['lastCommand'] as String? ?? 'unknown',
    );
  }
}
