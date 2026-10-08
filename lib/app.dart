import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'features/auth/login_screen.dart';
import 'features/closing/close_work_order_screen.dart';
import 'features/execution/elevator_screen.dart';
import 'features/execution/work_order_screen.dart';
import 'features/findings/findings_screen.dart';
import 'features/findings/photos_screen.dart';
import 'features/safety/safety_screen.dart';
import 'features/tasks/tasks_screen.dart';
import 'features/work_orders/work_orders_screen.dart';

/// Rutas del flujo del técnico:
///
///   /login
///   /                                  Mis órdenes de trabajo
///   /ot/:id                            Revisar OT e "Iniciar trabajo"
///   /ot/:id/eq/:eid                    Resumen del equipo (pasos)
///   /ot/:id/eq/:eid/safety             1. Checklist de seguridad -> Aprobar
///   /ot/:id/eq/:eid/tasks              2. Tareas -> Aprobar por tarea o módulo
///   /ot/:id/eq/:eid/photos             3. Fotos (mínimo 4 en PREV/CORR)
///   /ot/:id/eq/:eid/findings           4. Hallazgos: nota, foto y audio
///   /ot/:id/close                      Cierre con firma del cliente
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AsyncValue<Object?>>(const AsyncLoading());
  ref.listen(authProvider, (_, next) => auth.value = next, fireImmediately: true);

  return GoRouter(
    refreshListenable: auth,
    redirect: (context, state) {
      final a = auth.value;
      if (a.isLoading && !a.hasValue) return null;
      final loggedIn = a.value != null;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn && !atLogin) return '/login';
      if (loggedIn && atLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/',
        builder: (_, _) => const WorkOrdersScreen(),
        routes: [
          GoRoute(
            path: 'ot/:id',
            builder: (_, s) => WorkOrderScreen(workOrderId: s.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'close',
                builder: (_, s) =>
                    CloseWorkOrderScreen(workOrderId: s.pathParameters['id']!),
              ),
              GoRoute(
                path: 'eq/:eid',
                builder: (_, s) => ElevatorScreen(
                    workOrderId: s.pathParameters['id']!,
                    elevatorId: s.pathParameters['eid']!),
                routes: [
                  GoRoute(
                    path: 'safety',
                    builder: (_, s) => SafetyScreen(
                        workOrderId: s.pathParameters['id']!,
                        elevatorId: s.pathParameters['eid']!),
                  ),
                  GoRoute(
                    path: 'tasks',
                    builder: (_, s) => TasksScreen(
                        workOrderId: s.pathParameters['id']!,
                        elevatorId: s.pathParameters['eid']!),
                  ),
                  GoRoute(
                    path: 'photos',
                    builder: (_, s) => PhotosScreen(
                        workOrderId: s.pathParameters['id']!,
                        elevatorId: s.pathParameters['eid']!),
                  ),
                  GoRoute(
                    path: 'findings',
                    builder: (_, s) => FindingsScreen(
                        workOrderId: s.pathParameters['id']!,
                        elevatorId: s.pathParameters['eid']!),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class HtlApp extends ConsumerWidget {
  const HtlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const brand = Color(0xFF1E3A8A);
    return MaterialApp.router(
      title: 'HTL Técnicos',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brand),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.dark),
        useMaterial3: true,
      ),
    );
  }
}
