import 'package:flutter/material.dart';

/// Prompts for a fluid amount in mL. Required + must be a whole number > 0.
/// Returns the amount, or null if cancelled.
Future<int?> showFluidAmountDialog(BuildContext context,
    {required String title, int? initial}) {
  final controller = TextEditingController(text: initial?.toString() ?? '');
  final formKey = GlobalKey<FormState>();
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Amount (mL) *', hintText: 'Required'),
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            if (n == null) return 'Enter a whole number';
            if (n <= 0) return 'Must be greater than 0';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, int.parse(controller.text.trim()));
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
