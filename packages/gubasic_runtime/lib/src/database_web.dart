import 'database.dart';
import 'database_wasm.dart' deferred as wasm;

GbSqlite createGbSqlite(String? root) => _WebSqlite();

/// SQLite on the web (D126): the WebAssembly build and the code around it
/// are loaded only when a program first opens a database, so that apps
/// that have none stay as they were.
class _WebSqlite implements GbSqlite {
  Future<void>? _loading;

  @override
  String pathOf(String appId, String name) => name;

  @override
  Future<GbSqlDatabase> open(String appId, String name) async {
    try {
      await (_loading ??= wasm.loadLibrary());
    } catch (e) {
      _loading = null;
      throw GbSqlError('the database code could not be loaded: $e');
    }
    return wasm.openDatabase(safeAppId(appId), name);
  }
}
