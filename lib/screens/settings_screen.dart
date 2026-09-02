import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<SettingsProvider>().load());
  }

  Future<void> _editLimit() async {
    final controller = TextEditingController(
        text: context.read<SettingsProvider>().fluidLimitMl?.toString() ?? '');
    final ml = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily fluid limit (mL)'),
        content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
              child: const Text('Save')),
        ],
      ),
    );
    if (ml != null && ml > 0 && mounted) {
      await context.read<SettingsProvider>().setLimit(ml);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return ListView(children: [
      ListTile(
        title: const Text('Daily fluid limit'),
        subtitle: Text(s.fluidLimitMl == null ? 'Not set' : '${s.fluidLimitMl} mL'),
        trailing: const Icon(Icons.edit),
        onTap: _editLimit,
      ),
      SwitchListTile(
        title: const Text('Medicine reminders'),
        value: s.notificationsEnabled,
        onChanged: (v) => context.read<SettingsProvider>().setNotifications(v),
      ),
    ]);
  }
}
