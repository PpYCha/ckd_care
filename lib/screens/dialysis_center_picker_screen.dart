import 'package:flutter/material.dart';
import 'package:ckd_care/data/dialysis_repository.dart';
import 'package:ckd_care/models/dialysis_center.dart';
import 'package:ckd_care/theme/app_theme.dart';

/// Picks one accredited dialysis center via region -> province -> list, and
/// pops with the chosen [DialysisCenter]. Used to fill the schedule's clinic.
class DialysisCenterPickerScreen extends StatefulWidget {
  const DialysisCenterPickerScreen({super.key});
  @override
  State<DialysisCenterPickerScreen> createState() =>
      _DialysisCenterPickerScreenState();
}

class _DialysisCenterPickerScreenState
    extends State<DialysisCenterPickerScreen> {
  final _repo = DialysisRepository();
  bool _loading = true;
  bool _loadFailed = false;
  String? _region;
  String? _province;

  @override
  void initState() {
    super.initState();
    _repo.load().then((_) {
      if (mounted) setState(() => _loading = false);
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadFailed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Choose a center')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load the dialysis center list.',
                style: text.bodyLarge, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final provinces =
        _region == null ? const <String>[] : _repo.provincesIn(_region!);
    final centers = (_region != null && _province != null)
        ? _repo.centersIn(_region!, _province!)
        : const <DialysisCenter>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a center')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text('Pick your dialysis center from the accredited list.',
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _region,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Region', border: OutlineInputBorder()),
            items: [
              for (final r in _repo.regions)
                DropdownMenuItem(
                    value: r, child: Text(r, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() {
              _region = v;
              _province = null;
            }),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _province,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Province / City', border: OutlineInputBorder()),
            items: [
              for (final p in provinces)
                DropdownMenuItem(
                    value: p, child: Text(p, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: _region == null
                ? null
                : (v) => setState(() => _province = v),
          ),
          const SizedBox(height: 20),
          if (_region == null)
            _hint(text, 'Choose a region to begin.')
          else if (_province == null)
            _hint(text, 'Choose a province or city to see centers.')
          else if (centers.isEmpty)
            _hint(text, 'No accredited centers listed for this area.')
          else
            for (final c in centers) _PickRow(center: c),
        ],
      ),
    );
  }

  Widget _hint(TextTheme text, String msg) => Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Center(child: Text(msg, style: text.bodyMedium)),
      );
}

class _PickRow extends StatelessWidget {
  const _PickRow({required this.center});
  final DialysisCenter center;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () => Navigator.pop(context, center),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: AppColors.dialysis.withValues(alpha: 0.15),
              shape: BoxShape.circle),
          child: const Icon(Icons.local_hospital_rounded,
              color: AppColors.dialysis, size: 22),
        ),
        title: Text(center.name, style: text.titleMedium),
        subtitle: center.address.isEmpty
            ? null
            : Text(center.address, style: text.labelMedium),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      ),
    );
  }
}
