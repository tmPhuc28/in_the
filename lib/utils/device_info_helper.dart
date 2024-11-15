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
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} ngày trước';
    }

    return '${lastConnected.day.toString().padLeft(2, '0')}/'
        '${lastConnected.month.toString().padLeft(2, '0')}/'
        '${lastConnected.year}';
  }

  static Widget buildDeviceInfo(PrinterDevice? printer, bool isConnected) {
    if (printer == null) {
      return const Text(
        'Chưa có máy in được lưu',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          printer.name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isConnected ? Colors.green.shade700 : Colors.grey.shade700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (!isConnected && printer.lastConnectedTime != null) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.history, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Kết nối lần cuối: ${formatLastConnected(printer.lastConnectedTime)}',
                  style: TextStyle(
                    fontSize: 10,
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