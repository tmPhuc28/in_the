import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import '../models/card_info.dart';

class PrintService {

  final Paint _whitePaint = Paint()..color = Colors.white;
  final Map<String, TextStyle> _textStyleCache = {};

  TextStyle _getCachedTextStyle(double fontSize, FontWeight weight) {
    final key = '${fontSize}_${weight.index}';
    return _textStyleCache[key] ??= TextStyle(
      fontSize: fontSize,
      fontWeight: weight,
      color: Colors.black,
    );
  }

  Future<Uint8List> createPreviewImage({required CardInfo cardInfo, bool withQR = false,}) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    // Store information
    const storeName = "CỬA HÀNG HOÀNG DIỆU";
    const storePhone = "0987-390-432";
    const storeAddress = "Chợ Nhà Ngang, Hòa Chánh, UMT, KG";

    final now = DateTime.now();
    final formattedDate =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} '
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    // Draw background once
    canvas.drawRect(const Rect.fromLTWH(0, 0, 400, 600), _whitePaint);

    // Create and draw text elements
    double y = 5;

    // Header
    y = _drawCenteredText(canvas, storeName, 28, FontWeight.bold, y);
    y = _drawCenteredText(canvas, storePhone, 23, FontWeight.w600, y + 5);
    y = _drawCenteredText(canvas, storeAddress, 22, FontWeight.normal, y + 5);
    y = _drawText(canvas, 'Thời gian:', formattedDate, 23, FontWeight.w600, y + 5);

    y = _drawSeparatorLine(canvas, y + 10);

    // Card information
    y = _drawText(canvas, 'Nhà mạng:', cardInfo.provider, 28, FontWeight.bold, y + 5);
    y = _drawText(canvas, 'Mệnh giá:', cardInfo.denomination, 28, FontWeight.bold, y + 5);
    y = _drawText(canvas, 'Số seri:', cardInfo.serialNumber, 28, FontWeight.bold, y + 5);
    y = _drawCenteredText(canvas, 'Mã nạp:', 28, FontWeight.normal, y + 5);
    y = _drawCenteredText(canvas, cardInfo.rechargeCode, 35, FontWeight.bold, y + 5);

    if (withQR) {
      y = await _drawQRCode(
        canvas,
        'tel:*100*${cardInfo.rechargeCode.replaceAll(' ', '')}#',
        y + 5,
      );
      y = _drawCenteredText(canvas, 'Quét mã QR để nạp thẻ', 20, FontWeight.normal, y + 5);
    }

    // Footer
    y = _drawSeparatorLine(canvas, y + 10);
    y = _drawCenteredText(canvas, 'Cảm ơn quý khách', 20, FontWeight.w500, y + 10);

    final picture = recorder.endRecording();
    final img = await picture.toImage(400, y.toInt());
    final byteData = await img.toByteData(format: ImageByteFormat.png);

    if (byteData == null) throw Exception('Failed to generate image');
    return byteData.buffer.asUint8List();
  }

  double _drawCenteredText(Canvas canvas, String text, double fontSize, FontWeight weight, double y) {
    final textPainter = _createTextPainter(text, fontSize, weight, TextAlign.center);
    textPainter.layout(maxWidth: 380);
    textPainter.paint(canvas, Offset((400 - textPainter.width) / 2, y));
    return y + textPainter.height;
  }

  double _drawText(Canvas canvas, String label, String text, double fontSize, FontWeight weight, double y) {
    final labelPainter = _createTextPainter(label, fontSize, FontWeight.normal, TextAlign.left);
    labelPainter.layout(maxWidth: 380);
    labelPainter.paint(canvas, Offset(10, y));

    final textPainter = _createTextPainter(text, fontSize, weight, TextAlign.right);
    textPainter.layout(maxWidth: 380);
    textPainter.paint(canvas, Offset(400 - textPainter.width - 10, y));

    return y + textPainter.height;
  }

  Future<double> _drawQRCode(Canvas canvas, String data, double y) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );

    const qrSize = 85.0;
    final qrOffset = Offset((400 - qrSize) / 2, y);
    canvas.save();
    canvas.translate(qrOffset.dx, qrOffset.dy);
    qrPainter.paint(canvas, const Size(qrSize, qrSize));
    canvas.restore();

    return y + qrSize;
  }

  double _drawSeparatorLine(Canvas canvas, double y) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;
    canvas.drawLine(Offset(10, y), Offset(390, y), paint);
    return y;
  }

  TextPainter _createTextPainter(String text, double fontSize, FontWeight weight, TextAlign align) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: _getCachedTextStyle(fontSize, weight),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    );
  }

  List<LineText> createPrintData(Uint8List imageData) {
    try {
      final List<LineText> list = [];

      // Thêm hình ảnh
      list.add(LineText(
        type: LineText.TYPE_IMAGE,
        content: base64Encode(imageData),
        width: 380, // Điều chỉnh độ rộng phù hợp với máy in
        height: imageData.length * 380 ~/ imageData.length, // Tự động tính độ cao để giữ tỷ lệ
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));

      return list;
    } catch (e) {
      debugPrint('Error creating print data: $e');
      rethrow;
    }
  }
}