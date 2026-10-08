import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/providers.dart';
import 'core/session_store.dart';
import 'core/sync_queue.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_PE');

  final queue = SyncQueue(ApiClient(SessionStore()));
  await queue.init();

  runApp(ProviderScope(
    overrides: [syncQueueProvider.overrideWithValue(queue)],
    child: const HtlApp(),
  ));
}
