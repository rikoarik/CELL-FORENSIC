import 'package:cell_forensic/core/database/local_store.dart';
import 'package:cell_forensic/core/database/shared_preferences_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SharedPreferences backend survives reopen', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = await SharedPreferencesStorageBackend.open();
    final db = LocalDatabase(backend);

    db.transaction((txn) {
      txn.put('groups', 'g1', {'id': 'g1', 'name': 'Mawar'});
    });
    await backend.flush();

    final reopened = await SharedPreferencesStorageBackend.open();
    final again = LocalDatabase(reopened);
    expect(again.read('groups', 'g1')?['name'], 'Mawar');
  });
}
