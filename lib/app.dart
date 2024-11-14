import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'views/screens/home_screen.dart';

class CardPrinterApp extends StatelessWidget {
  const CardPrinterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'In thẻ',
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);

        final textScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.2,
        );

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: textScaler,
            // Đảm bảo padding an toàn không bị ảnh hưởng
            padding: mediaQuery.padding,
            viewPadding: mediaQuery.viewPadding,
          ),
          child: ScrollConfiguration(
            // Thêm cấu hình scroll mượt hơn
            behavior: ScrollConfiguration.of(context).copyWith(
              physics: const BouncingScrollPhysics(),
              scrollbars: false,
            ),
            child: child!,
          ),
        );
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
        // Cập nhật TextTheme với các giá trị cố định
        textTheme: const TextTheme(
          // Display styles
          displayLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          displaySmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),

          // Heading styles
          headlineLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),

          // Title styles
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),

          // Body styles
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
          bodySmall: TextStyle(fontSize: 12),

          // Label styles
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ).apply(
          // Áp dụng font family và màu sắc mặc định
          fontFamily: 'Roboto',
          bodyColor: Colors.black87,
          displayColor: Colors.black87,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi'),
      ],
      home: const HomeScreen(),
    );
  }
}