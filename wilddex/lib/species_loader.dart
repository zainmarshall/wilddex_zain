import 'data/app_data.dart';
import 'data/app_data_store.dart';

Future<AppData> loadAppData() async {
  return AppDataStore.loadAppData();
}
