import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WiDropApp());
}

class WiDropApp extends StatelessWidget {
  const WiDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WiDrop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LinkSenderScreen(),
    );
  }
}

class LinkSenderScreen extends StatefulWidget {
  const LinkSenderScreen({super.key});

  @override
  State<LinkSenderScreen> createState() => _LinkSenderScreenState();
}

class _LinkSenderScreenState extends State<LinkSenderScreen> {
  // Input controllers requested by the user
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _deviceController = TextEditingController();
  final TextEditingController _folderController = TextEditingController();

  // Laptop Server configuration (port 8080 on the same Wi-Fi)
  final TextEditingController _ipController =
      TextEditingController(text: '192.168.1.100');
  final int _serverPort = 8080;

  bool _isLoading = false;
  String? _lastStatusMessage;
  bool _lastStatusSuccess = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceController.text =
          prefs.getString('device_name') ?? 'My Mobile Device';
      _folderController.text =
          prefs.getString('default_folder') ?? 'Downloads';
      _ipController.text =
          prefs.getString('laptop_ip') ?? '192.168.1.100';
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_name', _deviceController.text.trim());
    await prefs.setString('default_folder', _folderController.text.trim());
    await prefs.setString('laptop_ip', _ipController.text.trim());
  }

  // Sends link, device name, and folder to laptop server at port 8080
  Future<void> _sendInformationToLaptop() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final link = _linkController.text.trim();
    final deviceName = _deviceController.text.trim();
    final folder = _folderController.text.trim();
    final laptopIp = _ipController.text.trim();

    // Construct laptop server URL at port 8080
    final uri = Uri.parse('http://$laptopIp:$_serverPort/api/transfer');

    setState(() {
      _isLoading = true;
      _lastStatusMessage = null;
    });

    try {
      await _savePreferences();

      final payload = jsonEncode({
        'link': link,
        'deviceName': deviceName,
        'folder': folder,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Send HTTP POST request with 10 seconds timeout
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: payload,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _lastStatusSuccess = true;
          _lastStatusMessage =
              'Sent successfully to laptop ($laptopIp:$_serverPort)!';
          // Optionally clear link after successful dispatch
          _linkController.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Sent to $folder on $laptopIp!'),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception(
            'Server responded with HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _lastStatusSuccess = false;
        _lastStatusMessage =
            'Failed to connect to laptop at $laptopIp:$_serverPort.\nError: $e';
      });

      if (mounted) {
        _showErrorDialog(laptopIp, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String ip, String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Connection Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Could not reach laptop server at http://$ip:$_serverPort'),
            const SizedBox(height: 12),
            const Text(
              'Quick Checklist:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('• Both devices are on the SAME Wi-Fi network'),
            const Text('• The server script is running on your laptop'),
            const Text('• Laptop firewall allows inbound port 8080 traffic'),
            const Text('• Android usesCleartextTraffic="true" is in AndroidManifest'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Laptop Server IP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the local Wi-Fi IP address of your laptop (e.g. 192.168.1.100). The app connects at port 8080.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Laptop IP Address',
                hintText: '192.168.1.X',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.laptop_mac),
              ),
              keyboardType: TextInputType.datetime,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _savePreferences();
              Navigator.of(ctx).pop();
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _linkController.dispose();
    _deviceController.dispose();
    _folderController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WiDrop Link Sender'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Server Settings',
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Server Target Chip Bar
                InkWell(
                  onTap: _showSettingsDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Target: http://${_ipController.text}:$_serverPort',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.edit,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 1. LINK INPUT BOX
                Text(
                  '1. Link URL',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _linkController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'https://example.com/file.zip',
                    prefixIcon: const Icon(Icons.link),
                    suffixIcon: _linkController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _linkController.clear()),
                          )
                        : null,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a link';
                    }
                    if (!value.trim().startsWith('http://') &&
                        !value.trim().startsWith('https://') &&
                        !value.trim().startsWith('magnet:')) {
                      return 'Must start with http:// or https://';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // 2. DEVICE NAME INPUT BOX
                Text(
                  '2. Device Name',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _deviceController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Milan\'s Phone, Pixel 8',
                    prefixIcon: Icon(Icons.phone_android),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your device name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // 3. WHICH FOLDER INPUT BOX
                Text(
                  '3. Destination Folder on Laptop',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _folderController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Downloads/Movies, Desktop, Music',
                    prefixIcon: Icon(Icons.folder_open),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please specify the destination folder';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Quick folder presets
                Wrap(
                  spacing: 8,
                  children: [
                    'Downloads',
                    'Desktop',
                    'Movies',
                    'Music',
                    'Documents'
                  ].map((folder) {
                    return ActionChip(
                      label: Text(folder, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _folderController.text = folder;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // 4. THE GO BUTTON
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _sendInformationToLaptop,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _isLoading ? 'SENDING...' : 'GO',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Status banner if sent or failed
                if (_lastStatusMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _lastStatusSuccess
                          ? Colors.green.withOpacity(0.12)
                          : Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _lastStatusSuccess
                            ? Colors.green.withOpacity(0.4)
                            : Colors.red.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _lastStatusSuccess
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: _lastStatusSuccess ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _lastStatusMessage!,
                            style: TextStyle(
                              fontSize: 13,
                              color: _lastStatusSuccess
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
