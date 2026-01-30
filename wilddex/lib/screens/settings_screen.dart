import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_data.dart';
import '../utils/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
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
            ],
          );
        },
      ),
    );
  }
}
