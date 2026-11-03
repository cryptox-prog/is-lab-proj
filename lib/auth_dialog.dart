import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_controller.dart';

class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key, required this.controller});
  final AuthController controller;
  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  @override
  void dispose() {
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = widget.controller;
    final success = auth.configured
        ? await auth.verifyPin(_pin.text)
        : await auth.setPin(_pin.text, _confirmation.text);
    _pin.clear();
    _confirmation.clear();
    if (success && mounted) Navigator.of(context).pop(true);
  }

  Widget _field(TextEditingController controller, String label) => TextField(
    controller: controller,
    obscureText: true,
    enableSuggestions: false,
    autocorrect: false,
    keyboardType: TextInputType.number,
    maxLength: 64,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: label, counterText: ''),
    onSubmitted: (_) {
      if (!widget.controller.busy) _submit();
    },
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final auth = widget.controller;
      return AlertDialog(
        title: Text(auth.configured ? 'Unlock content' : 'Create PIN'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(_pin, auth.configured ? 'PIN' : 'PIN (at least 6 digits)'),
              if (!auth.configured) _field(_confirmation, 'Confirm PIN'),
              if (auth.error != null)
                Text(
                  auth.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: auth.busy || !auth.initialized ? null : _submit,
            child: Text(
              auth.busy
                  ? 'Checking...'
                  : auth.configured
                  ? 'Unlock'
                  : 'Save PIN',
            ),
          ),
        ],
      );
    },
  );
}
