// home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/bluetooth_controller.dart';
import '../../controllers/print_controller.dart';
import '../../utils/device_info_helper.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/dialog_helper.dart';
import '../widgets/preview_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _cardInputController = TextEditingController();
  int _backButtonPressCount = 0;
  DateTime? _lastBackPressTime;

  void _resetForm() {
    setState(() {
      _cardInputController.clear();
      Provider.of<PrintController>(context, listen: false);
    });
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      _backButtonPressCount = 1;
      _resetForm();
      return false;
    }

    _backButtonPressCount++;
    if (_backButtonPressCount >= 2) {
      final shouldExit = await DialogHelper.showExitConfirmDialog(context);
      if (shouldExit) {
        return true;
      }
      _backButtonPressCount = 0;
    }
    return false;
  }

  Future<void> _showPreview() async {

    final printController = context.read<PrintController>();

    // Validate và tạo preview
    final previewImage = await printController.createPreview(
      context,
      _cardInputController.text,
    );

    // Chỉ hiển thị preview nếu tạo thành công
    if (mounted && previewImage != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        builder: (context) => PreviewBottomSheet(
          cardText: _cardInputController.text,
          onClose: () => Navigator.pop(context),
        ),
      ).then((_) {
        // Cleanup sau khi đóng preview
        final bluetoothController = context.read<BluetoothController>();
        bluetoothController.lifecycleService.setPreviewState(false);
        if (bluetoothController.isConnected) {
          bluetoothController.disconnectPrinter(temporary: false);
        }
      });
    }
  }

  PreferredSize _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(110),
      child: Consumer<BluetoothController>(
        builder: (context, controller, _) {
          final lastPrinter = controller.connectedPrinter ?? controller.lastKnownPrinter;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                )
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title Bar - Simplified with only centered title
                  SizedBox(
                    height: 56,
                    child: Center(
                      child: Text(
                        'In thẻ cào',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),

                  // Printer Info Bar or Bluetooth Enable Button
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: controller.isBluetoothEnabled
                          ? (controller.isConnected ? Colors.green.shade50 : Colors.grey.shade50)
                          : Colors.orange.shade50,
                      border: Border(
                        top: BorderSide(
                          color: controller.isBluetoothEnabled
                              ? (controller.isConnected ? Colors.green.shade100 : Colors.grey.shade200)
                              : Colors.orange.shade100,
                        ),
                      ),
                    ),
                    child: !controller.isBluetoothEnabled
                    // Bluetooth Enable Button
                        ? Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.shade200,
                            ),
                          ),
                          child: Icon(
                            Icons.bluetooth_disabled_rounded,
                            size: 20,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bluetooth chưa được bật',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                              Text(
                                'Bật Bluetooth để kết nối máy in',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => controller.enableBluetooth(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.orange.shade700,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: Colors.orange.shade200,
                              ),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bluetooth, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Bật',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                    // Printer Info
                        : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: controller.isConnected
                                  ? Colors.green.shade200
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Icon(
                            Icons.print_rounded,
                            size: 20,
                            color: controller.isConnected
                                ? Colors.green.shade600
                                : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DeviceInfoHelper.buildDeviceInfo(lastPrinter, controller.isConnected),
                        ),
                        if (controller.isConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.green.shade200,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: Colors.green.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Sẵn sàng',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _cardInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BluetoothController, PrintController>(
      builder: (context, bluetoothController, printController, _) {
        return PopScope(
            canPop: false,
            onPopInvoked: (bool didPop) async {
          if (didPop) return;
          final shouldPop = await _onWillPop();
          if (shouldPop) {
            if (context.mounted) {
              Navigator.pop(context);
            }
          }
        },
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: _buildAppBar(context),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Main Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // QR Option
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.qr_code,
                                size: 20,
                                color: Colors.blue[600],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'In kèm mã QR',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Cho phép quét mã nạp tiền nhanh',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        value: printController.printWithQR,
                        onChanged: (value) => printController.toggleQR(value),
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Provider Selection
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nhà mạng',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (final provider in ['Viettel', 'Vinaphone', 'Mobifone'])
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: provider != 'Mobifone' ? 8 : 0,
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () => printController.setProvider(provider),
                                      style: ElevatedButton.styleFrom(
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        backgroundColor: printController.selectedProvider == provider
                                            ? Colors.blue[50]
                                            : Colors.white,
                                        foregroundColor: printController.selectedProvider == provider
                                            ? Colors.blue[700]
                                            : Colors.grey[600],
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: BorderSide(
                                            color: printController.selectedProvider == provider
                                                ? Colors.blue[200]!
                                                : Colors.grey[200]!,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        provider,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Denomination Selection
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mệnh giá',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 3,
                            children: printController.availableDenominations
                                .map((value) => ElevatedButton(
                              onPressed: () => printController.setDenomination(value),
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: printController.selectedDenomination == value
                                    ? Colors.blue[50]
                                    : Colors.white,
                                foregroundColor: printController.selectedDenomination == value
                                    ? Colors.blue[700]
                                    : Colors.grey[600],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: printController.selectedDenomination == value
                                        ? Colors.blue[200]!
                                        : Colors.grey[200]!,
                                  ),
                                ),
                              ),
                              child: Text(
                                value,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ))
                                .toList(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Card Input
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thông tin thẻ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _cardInputController,
                            decoration: InputDecoration(
                              hintText: 'Mã thẻ: xxxxxx\nSerial: xxxxxx',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.blue[400]!),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            maxLines: 3,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Preview Button
                      ElevatedButton(
                        onPressed: _showPreview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Xem trước và In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}