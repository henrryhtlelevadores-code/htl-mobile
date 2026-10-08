import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../data/models.dart';

/// Copia local de las OTs descargadas (lista y detalle completo) para poder
/// abrirlas y trabajarlas sin señal. Cada cambio del técnico se guarda aquí
/// al instante, así sobrevive aunque se cierre la app.
class OfflineStore {
  Directory? _dir;

  Future<Directory> _root() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    _dir = Directory('${base.path}/offline');
    await _dir!.create(recursive: true);
    return _dir!;
  }

  Future<File> _file(String name) async => File('${(await _root()).path}/$name.json');

  Future<void> saveList(List<WorkOrderSummary> list) async {
    await (await _file('work_orders'))
        .writeAsString(jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<List<WorkOrderSummary>?> loadList() async {
    final f = await _file('work_orders');
    if (!await f.exists()) return null;
    return (jsonDecode(await f.readAsString()) as List)
        .map((e) => WorkOrderSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveDetail(WorkOrderDetail o) async {
    await (await _file('wo_${o.id}')).writeAsString(jsonEncode(o.toJson()));
  }

  Future<WorkOrderDetail?> loadDetail(String id) async {
    final f = await _file('wo_$id');
    if (!await f.exists()) return null;
    return WorkOrderDetail.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
  }

  Future<void> clear() async {
    final d = await _root();
    if (await d.exists()) await d.delete(recursive: true);
    _dir = null;
  }
}
