import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/bluetooth_controller.dart';
import '../../models/printer_device.dart';

class BluetoothDevicesList extends StatefulWidget {
  final VoidCallback onDeviceSelected;

  const BluetoothDevicesList({
    super.key,
    required this.onDeviceSelected,
  });

  @override
  State<BluetoothDevicesList> createState() => _BluetoothDevicesListState();
}

class _BluetoothDevicesListState extends State<BluetoothDevicesList> {
  @override
  void initState() {
    super.initState();
    // Start scanning when list is shown
    Future.delayed(Duration.zero, () {
      final controller = context.read<BluetoothController>();
      if (controller.isBluetoothEnabled) {
        controller.scanForDevices();
      }
    });
  }

  Widget _buildBluetoothDisabled(BluetoothController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bluetooth_disabled_rounded,
              size: 40,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Bluetooth chưa được bật',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Vui lòng bật Bluetooth để kết nối với máy in',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  controller.enableBluetooth();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bluetooth, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Bật Bluetooth',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(BuildContext context, PrinterDevice device) {
    final bluetoothController = context.read<BluetoothController>();
    final isConnected = bluetoothController.connectedPrinter?.id == device.id;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isConnected ? Colors.green.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.print,
          color: isConnected ? Colors.green : Colors.grey,
        ),
      ),
      title: Text(
        device.name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isConnected ? Colors.green : null,
        ),
      ),
      subtitle: Text(
        device.id,
        style: const TextStyle(fontSize: 13),
      ),
      trailing: isConnected
          ? Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.shade200,
          ),
        ),
        child: const Text(
          'Đã kết nối',
          style: TextStyle(
            color: Colors.green,
            fontSize: 12,
          ),
        ),
      )
          : null,
      onTap: () async {
        try {
          await bluetoothController.connectToPrinter(device);
          widget.onDeviceSelected();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi kết nối: $e')),
            );
          }
        }
      },
    );
  }

  Widget _buildDeviceList(BluetoothController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Thiết bị có sẵn',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (controller.isScanning)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: controller.scanForDevices,
                  tooltip: 'Làm mới danh sách',
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: controller.availableDevices.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.print_disabled_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    controller.isScanning
                        ? 'Đang tìm kiếm thiết bị...'
                        : 'Không tìm thấy thiết bị nào',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                  if (!controller.isScanning) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Nhấn làm mới để tìm kiếm lại',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            )
                : ListView.separated(
              itemCount: controller.availableDevices.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final device = controller.availableDevices[index];
                return _buildDeviceItem(context, device);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothController>(
      builder: (context, controller, _) {
        if (!controller.isBluetoothEnabled) {
          return _buildBluetoothDisabled(controller);
        }
        return _buildDeviceList(controller);
      },
    );
  }
}