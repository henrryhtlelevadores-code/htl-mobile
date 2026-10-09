import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  Future<void> _submit() async {
    await ref.read(authProvider.notifier).login(AppConfig.emailFor(_username.text), _password.text);
    final s = ref.read(authProvider);
    if (s.hasError && mounted) showError(context, s.error!);
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authProvider).isLoading;
    final colors = AppColors.of(context);
    return Scaffold(
      body: Column(children: [
        // Cabecera azul con el mismo degradado que el login del portal web.
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0055AA), AppColors.primary, Color(0xFF003D7A)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('HTL',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                const SizedBox(height: 20),
                const Text('Técnico de Campo',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.15)),
                const SizedBox(height: 6),
                Text('Órdenes, checklist y evidencias, incluso sin señal.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
              ]),
            ),
          ),
        ),
        Expanded(
          child: SafeArea(
            top: false,
            child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: AutofillGroup(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Iniciar sesión', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Ingresa con tu cuenta de técnico de campo',
                    style: TextStyle(fontSize: 13, color: colors.mutedForeground)),
                const SizedBox(height: 24),
                TextField(
                  controller: _username,
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: InputDecoration(
                    labelText: 'Usuario',
                    hintText: 'jperez',
                    prefixIcon: const Icon(Icons.person_outline),
                    // Solo se escribe lo que va antes de la @; el dominio se
                    // ve siempre, no solo al enfocar el campo.
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Text('@${AppConfig.emailDomain}',
                          style: TextStyle(color: colors.mutedForeground, fontSize: 13)),
                    ),
                    suffixIconConstraints: const BoxConstraints(minHeight: 0, minWidth: 0),
                  ),
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
                  const Text('Modo demostración: cualquier usuario y contraseña funcionan.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                ],
                const SizedBox(height: 40),
                const FortexCredit(),
              ]),
            ),
          ),
            ),
          ),
        ),
      ]),
    );
  }
}
