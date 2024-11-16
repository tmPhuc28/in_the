import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/bluetooth_controller.dart';
import '../../di/service_locator.dart';
import '../../models/printer_device.dart';
import '../../services/storage_service.dart';
import 'custom_snackbar.dart';


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
  final StorageService _storageService = getIt<StorageService>();

  @override
  void initState() {
    super.initState();
    // Start scanning when list is shown
    Future.delayed(Duration.zero, () {
      if(!mounted) return;
      final controller = context.read<BluetoothController>();
      if (controller.isBluetoothEnabled) {
        controller.scanForDevices();
      }
    });
  }

  Future<void> _showRenameDialog(PrinterDevice device) async {
    final TextEditingController nameController = TextEditingController(text: device.name);
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên thiết bị'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Tên thiết bị',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập tên thiết bị';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context);
                await _renamePrinter(device, nameController.text.trim());
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _renamePrinter(PrinterDevice device, String newName) async {
    try {
      await _storageService.renamePrinter(device.id, newName);

      if (mounted) {
        final controller = context.read<BluetoothController>();
        await controller.refreshPrinterInfo();

        CustomSnackbar.showSuccess(
          context,
          'Đã đổi tên thành công',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Không thể đổi tên thiết bị: $e',
        );
      }
    }
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            'Vui lòng bật Bluetooth để kết nối với máy in',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildStatusIndicator({required Color color, required String text, required bool showSpinner,}) {
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

  Widget? _buildStatusContainer(PrinterDevice device, BluetoothController controller) {
    if (controller.isDeviceConnecting(device.id)) {
      return _buildStatusIndicator(
        color: Colors.blue,
        text: 'Đang kết nối...',
        showSpinner: true,
      );
    } else if (controller.isDeviceDisconnecting(device.id)) {
      return _buildStatusIndicator(
        color: Colors.red,
        text: 'Đang ngắt kết nối...',
        showSpinner: true,
      );
    } else if (controller.isDeviceConnected(device.id)) {
      return _buildStatusIndicator(
        color: Colors.green,
        text: 'Đã kết nối',
        showSpinner: false,
      );
    }
    return null;
  }

  Widget _buildDeviceItem(BuildContext context, PrinterDevice device, BluetoothController controller) {
    final isProcessing = controller.processingDeviceId == device.id;
    final isConnected = controller.isDeviceConnected(device.id);

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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        device.address,
        style: const TextStyle(fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Menu cho thiết bị đã lưu
          if (device.lastConnectedTime != null)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: isProcessing ? null : () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Đổi tên'),
                        onTap: () {
                          Navigator.pop(context);
                          _showRenameDialog(device);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          if (_buildStatusContainer(device, controller) != null)
            _buildStatusContainer(device, controller)!,
        ],
      ),
      onTap: isProcessing ? null : () async {
        try {
          await controller.connectToPrinter(device);
          if (mounted && controller.isDeviceConnected(device.id)) {
            widget.onDeviceSelected();
          }
        } catch (e) {
          if (mounted) {
            CustomSnackbar.showError(
              context,
              'Không thể kết nối: ${e.toString()}',
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                    controller.isScanning ? 'Đang tìm kiếm thiết bị...' : 'Không tìm thấy thiết bị nào',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!controller.isScanning) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Nhấn làm mới để tìm kiếm lại',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                return _buildDeviceItem(context, device, controller);
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