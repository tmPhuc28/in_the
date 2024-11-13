import 'package:flutter/material.dart';
import '../models/printer_device.dart';

class DeviceInfoHelper {
  static String formatLastConnected(DateTime? lastConnected) {
    if (lastConnected == null) return '';

    final now = DateTime.now();
    final difference = now.difference(lastConnected);

    if (difference.inMinutes < 1) {
      return 'vừa xong';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes phút trước';
    } else if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$hours giờ trước';
    } else if (difference.inDays < 30) {
      final days = difference.inDays;
      return '$days ngày trước';
    } else {
      return '${lastConnected.day.toString().padLeft(2, '0')}/'
          '${lastConnected.month.toString().padLeft(2, '0')}/'
          '${lastConnected.year}';
    }
  }

  static Widget buildDeviceInfo(PrinterDevice? lastPrinter, bool isConnected) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lastPrinter?.name ?? 'Chưa có máy in được lưu',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isConnected ? Colors.green.shade700 : Colors.grey.shade700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (lastPrinter != null && !isConnected) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.history,
                size: 12,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  lastPrinter.lastConnectedTime != null
                      ? 'Kết nối lần cuối: ${formatLastConnected(lastPrinter.lastConnectedTime)}'
                      : 'Chưa có thông tin kết nối',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}