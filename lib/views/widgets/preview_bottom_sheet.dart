import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/bluetooth_controller.dart';
import '../../controllers/print_controller.dart';
import 'bluetooth_devices_list.dart';
import 'custom_snackbar.dart';
import '../../extensions/printer_status_extension.dart';

class PreviewBottomSheet extends StatefulWidget {
  final String cardText;
  final VoidCallback onClose;

  const PreviewBottomSheet({
    super.key,
    required this.cardText,
    required this.onClose,
  });

  @override
  State<PreviewBottomSheet> createState() => _PreviewBottomSheetState();
}

class _PreviewBottomSheetState extends State<PreviewBottomSheet> {
  final TransformationController _transformationController = TransformationController();
  bool _isPrinting = false;
  Uint8List? _previewImage;
  bool _isGeneratingPreview = false;
  bool _showBluetoothList = false;

  @override
  void initState() {
    super.initState();
    _setupPreview(true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bluetoothController = context.read<BluetoothController>();
      setState(() => _showBluetoothList = !bluetoothController.isBluetoothEnabled);
      _generatePreview(context.read<PrintController>());
    });
  }

  @override
  void dispose() {
    _setupPreview(false);
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _handlePrint(BuildContext context, BluetoothController bluetoothController, PrintController printController) async {
    if (!bluetoothController.isBluetoothEnabled) {
      CustomSnackbar.showWarning(context, 'Vui lòng bật Bluetooth');
      return;
    }

    if (!bluetoothController.isDeviceConnected(bluetoothController.connectedPrinter?.id ?? '')) {
      CustomSnackbar.showWarning(context, 'Vui lòng kết nối máy in');
      setState(() => _showBluetoothList = true);
      return;
    }

    setState(() => _isPrinting = true);

    try {
      final success = await printController.printCard(context, widget.cardText);
      if (success && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _generatePreview(PrintController printController) async {
    if (_isGeneratingPreview) return;

    try {
      setState(() => _isGeneratingPreview = true);

      final imageData = await printController.createPreview(context, widget.cardText);

      if (mounted && imageData != null) {
        setState(() {
          _previewImage = imageData;
        });
      }
    } catch (e) {
      debugPrint('Error generating preview: $e');
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPreview = false);
      }
    }
  }

  Future<void> _setupPreview(bool isOpen) async {
    final bluetoothController = context.read<BluetoothController>();
    bluetoothController.lifecycleService.setPreviewState(isOpen);
    if (isOpen) bluetoothController.reconnectLastPrinter();
  }

  Widget _buildStatusContainer(BluetoothController controller) {
    final status = controller.getPrinterStatus();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status.showSpinner) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(status.foregroundColor),
              ),
            ),
          ] else ...[
            Icon(
              Icons.print,
              size: 18,
              color: status.foregroundColor,
            ),
          ],
          const SizedBox(width: 8),
          Text(
            status.getStatusText(controller.connectedPrinter?.name),
            style: TextStyle(
              color: status.foregroundColor,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (controller.isBluetoothEnabled) ...[
            const SizedBox(width: 4),
            Icon(
              _showBluetoothList
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              size: 18,
              color: status.foregroundColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BluetoothController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              _setupPreview(false);
              widget.onClose();
            },
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[100],
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.all(8),
            ),
          ),
          const Spacer(),
          // Printer Connection Status - Có thể tap để toggle devices list
          InkWell(
            onTap: () {
              // Chỉ cho phép toggle khi bluetooth đã bật
              if (controller.isBluetoothEnabled) {
                setState(() => _showBluetoothList = !_showBluetoothList);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: _buildStatusContainer(controller),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BluetoothController controller) {
    if (!controller.isBluetoothEnabled || _showBluetoothList) {
      return BluetoothDevicesList(
        onDeviceSelected: () {
          if (mounted) {
            setState(() => _showBluetoothList = false);
          }
        },
      );
    }

    if (_isGeneratingPreview) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 16),
            Text('Đang tạo bản xem trước...'),
          ],
        ),
      );
    }

    if (_previewImage == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 48,
                color: Colors.grey[400]
            ),
            const SizedBox(height: 16),
            Text(
              'Không có dữ liệu xem trước',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            _previewImage!,
            fit: BoxFit.contain,
            width: double.infinity,
          ),
        ),
      ),
    );
  }

  Widget _buildPrintButton(BluetoothController controller) {
    final bool canPrint = controller.isBluetoothEnabled &&
        controller.isDeviceConnected(controller.connectedPrinter?.id ?? '') &&
        !_isPrinting;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canPrint
            ? () => _handlePrint(context, controller, context.read<PrintController>())
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          disabledBackgroundColor: Colors.grey[100],
          disabledForegroundColor: Colors.grey[400],
        ),
        child: _isPrinting
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.grey[400]!),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Đang in...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        )
            : const Text(
          'In thẻ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          _setupPreview(false);
        }
      },
      child: Consumer2<BluetoothController, PrintController>(
        builder: (context, bluetoothController, printController, _) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.72,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _buildHeader(bluetoothController),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildContent(bluetoothController),
                  ),
                ),
                if (bluetoothController.isBluetoothEnabled)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: _buildPrintButton(bluetoothController),
                  )
              ],
            ),
          );
        },
      ),
    );
  }
}