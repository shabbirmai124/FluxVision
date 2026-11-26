import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'vault_models.dart';

typedef DirectoryProvider = Future<Directory> Function();

/// Atomic offline JSON + binary Float32List vault with zero SQL dependencies.
class LocalVaultStorage {
  LocalVaultStorage({DirectoryProvider? rootDirectoryProvider})
      : _rootDirectoryProvider = rootDirectoryProvider ?? getApplicationDocumentsDirectory;

  final DirectoryProvider _rootDirectoryProvider;

  Future<Directory> _vaultDir() async {
    final base = await _rootDirectoryProvider();
    final dir = Directory(p.join(base.path, 'flux_vision'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _gridsDir() async {
    final vault = await _vaultDir();
    final dir = Directory(p.join(vault.path, 'grids'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _baselinesFile() async {
    final vault = await _vaultDir();
    return File(p.join(vault.path, 'baselines.json'));
  }

  Future<File> _sessionsFile() async {
    final vault = await _vaultDir();
    return File(p.join(vault.path, 'sessions.json'));
  }

  Future<File> _gridFile(String sessionId) async {
    final grids = await _gridsDir();
    final safeId = sessionId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return File(p.join(grids.path, 'session_$safeId.bin'));
  }

  Future<List<RoomBaseline>> loadBaselines() async {
    final file = await _baselinesFile();
    if (!await file.exists()) return <RoomBaseline>[];
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return <RoomBaseline>[];
    final decoded = jsonDecode(raw) as List<dynamic>;
    final list = decoded
        .map((item) => RoomBaseline.fromJson(item as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> saveBaseline(RoomBaseline baseline) async {
    final current = await loadBaselines();
    current.removeWhere((b) => b.id == baseline.id);
    current.insert(0, baseline);
    await _atomicWriteString(
      await _baselinesFile(),
      jsonEncode(current.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteBaseline(String id) async {
    final current = await loadBaselines();
    current.removeWhere((b) => b.id == id);
    await _atomicWriteString(
      await _baselinesFile(),
      jsonEncode(current.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<ScanSession>> loadSessions() async {
    final file = await _sessionsFile();
    if (!await file.exists()) return <ScanSession>[];
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return <ScanSession>[];
    final decoded = jsonDecode(raw) as List<dynamic>;
    final list = decoded
        .map((item) => ScanSession.fromJson(item as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<ScanSession?> getSessionById(String id) async {
    final sessions = await loadSessions();
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> saveSession(ScanSession session, Float32List grid) async {
    final gridFile = await _gridFile(session.id);
    final bytes = _encodeFloat32LittleEndian(grid);
    await _atomicWriteBytes(gridFile, bytes);

    final current = await loadSessions();
    current.removeWhere((s) => s.id == session.id);
    current.insert(0, session);
    await _atomicWriteString(
      await _sessionsFile(),
      jsonEncode(current.map((e) => e.toJson()).toList()),
    );
  }

  Future<Float32List> loadSessionGrid(String sessionId, {int expectedSize = 32}) async {
    final gridFile = await _gridFile(sessionId);
    if (!await gridFile.exists()) {
      return Float32List(expectedSize * expectedSize);
    }
    final bytes = await gridFile.readAsBytes();
    return _decodeFloat32LittleEndian(bytes);
  }

  Future<void> deleteSession(String id) async {
    final current = await loadSessions();
    current.removeWhere((s) => s.id == id);
    await _atomicWriteString(
      await _sessionsFile(),
      jsonEncode(current.map((e) => e.toJson()).toList()),
    );
    final gridFile = await _gridFile(id);
    if (await gridFile.exists()) {
      await gridFile.delete();
    }
  }

  Future<String> exportDirPath() async {
    final vault = await _vaultDir();
    final dir = Directory(p.join(vault.path, 'exports'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<void> _atomicWriteString(File target, String content) async {
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await tmp.rename(target.path);
  }

  Future<void> _atomicWriteBytes(File target, Uint8List bytes) async {
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await tmp.rename(target.path);
  }

  static Uint8List _encodeFloat32LittleEndian(Float32List grid) {
    final data = ByteData(grid.length * 4);
    for (int i = 0; i < grid.length; i++) {
      data.setFloat32(i * 4, grid[i], Endian.little);
    }
    return data.buffer.asUint8List();
  }

  static Float32List _decodeFloat32LittleEndian(Uint8List bytes) {
    final count = bytes.length ~/ 4;
    final data = ByteData.sublistView(bytes);
    final result = Float32List(count);
    for (int i = 0; i < count; i++) {
      result[i] = data.getFloat32(i * 4, Endian.little);
    }
    return result;
  }
}
