import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/bluetooth_controller.dart';
import 'controllers/print_controller.dart';
import 'di/service_locator.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => getIt<BluetoothController>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<PrintController>(),
        ),
      ],
      child: const CardPrinterApp(),
    );
  }
}