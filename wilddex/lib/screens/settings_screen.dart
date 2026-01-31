import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_data.dart';
import '../utils/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _localApiController = TextEditingController();

  @override
  void dispose() {
    _localApiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          if (_localApiController.text != settings.localApiHost) {
            _localApiController.text = settings.localApiHost;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                title: const Text('Core Dex'),
                subtitle: Text(
                  'Fewer, more complete species (${appData.coreSpeciesList.length} of ${appData.speciesList.length}).',
                ),
                trailing: Switch(
                  value: settings.useCoreDex,
                  onChanged: (value) => settings.setUseCoreDex(value),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Core Dex hides entries with missing names or minimal data to make the Dex feel more achievable.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              ListTile(
                title: const Text('Use local backend'),
                subtitle: Text(
                  settings.useLocalApi
                      ? 'Local: ${settings.apiBaseUrl}'
                      : 'Cloud: ${settings.apiBaseUrl}',
                ),
                trailing: Switch(
                  value: settings.useLocalApi,
                  onChanged: (value) => settings.setUseLocalApi(value),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _localApiController,
                enabled: settings.useLocalApi,
                decoration: const InputDecoration(
                  labelText: 'Local backend address',
                  hintText: '192.168.0.12:8000',
                ),
                keyboardType: TextInputType.url,
                onChanged: settings.setLocalApiHost,
              ),
              const SizedBox(height: 8),
              const Text(
                'Include port if needed. Use your machine IP when testing on a phone.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              ListTile(
                title: const Text('Use crop model'),
                subtitle: const Text('Faster inference using cropped detections.'),
                trailing: Switch(
                  value: settings.useCropModel,
                  onChanged: (value) => settings.setUseCropModel(value),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
