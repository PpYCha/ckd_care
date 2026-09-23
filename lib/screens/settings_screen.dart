import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/health_profile.dart';
import 'package:ckd_care/providers/health_profile_provider.dart';
import 'package:ckd_care/providers/settings_provider.dart';
import 'package:ckd_care/screens/health_profile_screen.dart';
import 'package:ckd_care/screens/dialysis_centers_screen.dart';
import 'package:ckd_care/screens/dialysis_schedule_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().load();
      context.read<HealthProfileProvider>().load();
    });
  }

  Future<void> _editLimit() async {
    final controller = TextEditingController(
      text: context.read<SettingsProvider>().fluidLimitMl?.toString() ?? '',
    );
    final ml = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily fluid limit (mL)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ml != null && ml > 0 && mounted) {
      await context.read<SettingsProvider>().setLimit(ml);
    }
  }

  String _profileSummary(HealthProfile p) {
    if (p == const HealthProfile()) return 'Not set';
    final parts = <String>[
      if (p.ckdStage != null) p.ckdStage!.label,
      if (p.dialysisStatus != DialysisStatus.none) p.dialysisStatus.label,
    ];
    // A profile with only flags set (no stage/dialysis) is still saved.
    return parts.isEmpty ? 'Details saved' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final profile = context.watch<HealthProfileProvider>().profile;
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: const Text('Health profile'),
          subtitle: Text(_profileSummary(profile)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HealthProfileScreen()),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.local_hospital_outlined),
          title: const Text('Dialysis centers'),
          subtitle: const Text('Find accredited clinics by region'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DialysisCentersScreen()),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.event_available_outlined),
          title: const Text('Dialysis schedule'),
          subtitle: const Text('Your sessions and next appointment'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DialysisScheduleScreen()),
          ),
        ),
        const Divider(),
        ListTile(
          title: const Text('Daily fluid limit'),
          subtitle: Text(
            s.fluidLimitMl == null ? 'Not set' : '${s.fluidLimitMl} mL',
          ),
          trailing: const Icon(Icons.edit),
          onTap: _editLimit,
        ),
        SwitchListTile(
          title: const Text('Medicine reminders'),
          value: s.notificationsEnabled,
          onChanged: (v) =>
              context.read<SettingsProvider>().setNotifications(v),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About KidneyTrack'),
          subtitle: const Text('App details and version'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AboutKidneyTrackScreen()),
          ),
        ),
      ],
    );
  }
}

class AboutKidneyTrackScreen extends StatelessWidget {
  const AboutKidneyTrackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About KidneyTrack')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final versionText = info == null
              ? 'Version loading...'
              : 'Version ${info.version} (build ${info.buildNumber})';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: cs.primaryContainer,
                        child: Icon(
                          Icons.health_and_safety_outlined,
                          color: cs.onPrimaryContainer,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('KidneyTrack', style: text.headlineSmall),
                      const SizedBox(height: 4),
                      Text(versionText, style: text.titleSmall),
                      const SizedBox(height: 16),
                      Text(
                        'KidneyTrack is a personal CKD companion for tracking '
                        'fluid intake and output, medicines, dialysis '
                        'schedules, session weights, health profile details, '
                        'food guidance, and dialysis centers.',
                        style: text.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Privacy and care note', style: text.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Your app data is stored locally on this device. '
                        'KidneyTrack supports day-to-day tracking and does '
                        'not replace medical diagnosis, treatment, or advice '
                        'from your doctor or dietitian.',
                        style: text.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
