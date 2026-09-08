import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ckd_care/models/health_profile.dart';
import 'package:ckd_care/providers/health_profile_provider.dart';

class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key});
  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  late HealthProfile _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<HealthProfileProvider>().profile;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await context.read<HealthProfileProvider>().save(_draft);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Health profile')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
          'Optional. Used to tailor general food guidance — it is not medical '
          'advice, and your care team\'s instructions always take priority.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 20),
        Text('CKD stage', style: text.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ChoiceChip(
            label: const Text('Not sure'),
            selected: _draft.ckdStage == null,
            onSelected: (_) => setState(() => _draft = HealthProfile(
                  dialysisStatus: _draft.dialysisStatus,
                  diabetes: _draft.diabetes,
                  elevatedPotassium: _draft.elevatedPotassium,
                  elevatedPhosphorus: _draft.elevatedPhosphorus,
                  fluidRestriction: _draft.fluidRestriction,
                )),
          ),
          for (final st in CkdStage.values)
            ChoiceChip(
              label: Text(st.label),
              selected: _draft.ckdStage == st,
              onSelected: (_) =>
                  setState(() => _draft = _draft.copyWith(ckdStage: st)),
            ),
        ]),
        const SizedBox(height: 20),
        Text('Dialysis', style: text.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final d in DialysisStatus.values)
            ChoiceChip(
              label: Text(d.label),
              selected: _draft.dialysisStatus == d,
              onSelected: (_) =>
                  setState(() => _draft = _draft.copyWith(dialysisStatus: d)),
            ),
        ]),
        const SizedBox(height: 12),
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Diabetes'),
          value: _draft.diabetes,
          onChanged: (v) => setState(() => _draft = _draft.copyWith(diabetes: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Elevated potassium (per recent labs)'),
          value: _draft.elevatedPotassium,
          onChanged: (v) =>
              setState(() => _draft = _draft.copyWith(elevatedPotassium: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Elevated phosphorus (per recent labs)'),
          value: _draft.elevatedPhosphorus,
          onChanged: (v) =>
              setState(() => _draft = _draft.copyWith(elevatedPhosphorus: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('On a fluid restriction'),
          value: _draft.fluidRestriction,
          onChanged: (v) =>
              setState(() => _draft = _draft.copyWith(fluidRestriction: v)),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _save, child: const Text('Save profile')),
      ]),
    );
  }
}
