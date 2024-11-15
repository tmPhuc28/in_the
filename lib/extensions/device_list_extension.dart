import 'package:flutter/material.dart';
import '../models/printer_device.dart';
import '../enums/connection_state.dart';

extension DeviceListItemX on PrinterDevice {
  Widget buildLeadingIcon() {
    final isActive = isConnected ||
        connectionState == PrinterConnectionState.connecting ||
        connectionState == PrinterConnectionState.disconnecting;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade100 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.print,
        color: isActive ? Colors.green : Colors.grey,
      ),
    );
  }

  Widget buildTitle() {
    final isActive = isConnected ||
        connectionState == PrinterConnectionState.connecting ||
        connectionState == PrinterConnectionState.disconnecting;

    return Text(
      name,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: isActive ? Colors.green : null,
      ),
    );
  }

  Widget buildSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          address,
          style: const TextStyle(fontSize: 13),
        ),
        if (lastConnectedTime != null && !isConnected) ...[
          const SizedBox(height: 2),
          Text(
            'Kết nối lần cuối: ${_formatLastConnected(lastConnectedTime!)}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget? buildConnectionStatus() {
    // Show status for all states except idle
    if (connectionState == PrinterConnectionState.idle && !isConnected) {
      return null;
    }

    final color = _getStatusColor();
    final text = _getStatusText();
    final showSpinner = connectionState == PrinterConnectionState.connecting ||
        connectionState == PrinterConnectionState.disconnecting;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner) ...[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatLastConnected(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Vừa xong';
    if (difference.inHours < 1) return '${difference.inMinutes} phút trước';
    if (difference.inDays < 1) return '${difference.inHours} giờ trước';
    if (difference.inDays < 30) return '${difference.inDays} ngày trước';

    return '${time.day}/${time.month}/${time.year}';
  }

  Color _getStatusColor() {
    switch (connectionState) {
      case PrinterConnectionState.connecting:
        return Colors.blue;
      case PrinterConnectionState.connected:
        return Colors.green;
      case PrinterConnectionState.disconnecting:
        return Colors.red;
      case PrinterConnectionState.disabled:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (connectionState) {
      case PrinterConnectionState.connecting:
        return 'Đang kết nối...';
      case PrinterConnectionState.connected:
        return 'Đã kết nối';
      case PrinterConnectionState.disconnecting:
        return 'Đang ngắt kết nối...';
      case PrinterConnectionState.disabled:
        return 'Đã tắt';
      default:
        return isConnected ? 'Đã kết nối' : '';
    }
  }
}
