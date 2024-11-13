import 'package:get_it/get_it.dart';
import '../services/app_lifecycle_service.dart';
import '../services/bluetooth_service.dart';
import '../services/print_service.dart';
import '../services/storage_service.dart';
import '../controllers/bluetooth_controller.dart';
import '../controllers/print_controller.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Services
  getIt.registerLazySingleton<AppLifecycleService>(() => AppLifecycleService(),);
  getIt.registerLazySingleton<StorageService>(() => StorageService());
  getIt.registerLazySingleton<BluetoothService>(() => BluetoothService());
  getIt.registerLazySingleton<PrintService>(() => PrintService());

  // Controllers
  getIt.registerLazySingleton<BluetoothController>(
        () => BluetoothController(
      bluetoothService: getIt<BluetoothService>(),
      storageService: getIt<StorageService>(),
      lifecycleService: getIt<AppLifecycleService>(),
    ),
  );

  getIt.registerLazySingleton<PrintController>(
        () => PrintController(
      printService: getIt<PrintService>(),
      bluetoothController: getIt<BluetoothController>(),
    ),
  );
}