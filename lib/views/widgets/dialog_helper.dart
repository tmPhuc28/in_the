import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DialogHelper {
  static Future<bool> showExitConfirmDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) {
            if (!didPop) {
              SystemNavigator.pop();
            }
          },
          child: AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.exit_to_app, color: Colors.orange),
                SizedBox(width: 12),
                Text(
                  'Xác nhận thoát',
                  style: TextStyle(fontSize: 20),
                ),
              ],
            ),
            content: const Text(
              'Bạn có chắc muốn thoát ứng dụng?',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Hủy',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              ElevatedButton(
                onPressed: () => SystemNavigator.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Thoát',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      },
    );

    return result ?? false;
  }
}