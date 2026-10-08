import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../widgets/common.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  Future<void> _submit() async {
    await ref.read(authProvider.notifier).login(_email.text, _password.text);
    final s = ref.read(authProvider);
    if (s.hasError && mounted) showError(context, s.error!);
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).isLoading;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AutofillGroup(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.elevator, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text('HTL Técnicos',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                const Text('Ingresa con tu cuenta de técnico de campo',
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                      labelText: 'Correo', prefixIcon: Icon(Icons.mail_outline)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: loading ? null : _submit,
                  child: loading
                      ? const SizedBox(
                          width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Ingresar'),
                ),
                if (AppConfig.useMock) ...[
                  const SizedBox(height: 16),
                  const Text('Modo demostración: cualquier correo y contraseña funcionan.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
