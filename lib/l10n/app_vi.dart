import 'package:flutter/material.dart';

class AppLocalizationsVi {
  static const AppLocalizationsVi _instance = AppLocalizationsVi._internal();

  factory AppLocalizationsVi() => _instance;

  const AppLocalizationsVi._internal();

  static Map<String, String> get values => {
    // App titles
    'app_title': 'In thẻ cào',

    // Common actions
    'print': 'In thẻ',
    'preview': 'Xem trước',
    'close': 'Đóng',
    'cancel': 'Hủy',
    'confirm': 'Xác nhận',
    'retry': 'Thử lại',

    // Printer related
    'printer_not_connected': 'Chưa kết nối máy in',
    'printer_connected': 'Đã kết nối với %s',
    'select_printer': 'Chọn máy in',
    'searching_devices': 'Đang tìm kiếm...',
    'no_devices_found': 'Không tìm thấy thiết bị',
    'refresh_to_search': 'Nhấn làm mới để tìm kiếm lại',
    'connected': 'Đã kết nối',
    'connection_failed': 'Kết nối thất bại: %s',
    'connection_lost': 'Mất kết nối với máy in',
    'printing_failed': 'In không thành công: %s',
    'print_success': 'In thành công',

    // Bluetooth related
    'bluetooth_disabled': 'Bluetooth chưa được bật',
    'enable_bluetooth': 'Bật Bluetooth',
    'enable_bluetooth_message': 'Vui lòng bật Bluetooth để sử dụng ứng dụng',
    'open_bluetooth_settings': 'Mở cài đặt Bluetooth',

    // Card info form
    'provider': 'Nhà mạng',
    'denomination': 'Mệnh giá',
    'card_code': 'Mã thẻ',
    'serial_number': 'Số seri',
    'recharge_code': 'Mã nạp',
    'print_with_qr': 'In kèm mã QR',
    'enter_card_info': 'Nhập mã nạp và số serial',
    'invalid_card_format': 'Mã thẻ không hợp lệ cho nhà mạng %s',
    'missing_card_info': 'Vui lòng nhập đầy đủ mã nạp và số serial',

    // Store info
    'store_name': 'CỬA HÀNG HOÀNG DIỆU',
    'store_phone': '0987-390-432',
    'store_address': 'Chợ Nhà Ngang, Hòa Chánh, UMT, KG',
    'thank_you': 'Cảm ơn quý khách',
    'scan_qr_to_recharge': 'Quét mã QR để nạp thẻ',
    'time': 'Thời gian',

    // Messages
    'error_occurred': 'Đã xảy ra lỗi',
    'no_preview_data': 'Không có dữ liệu xem trước',
  };

  static String getString(String key) {
    return values[key] ?? key;
  }

  static String getFormattedString(String key, List<String> params) {
    String value = getString(key);
    for (var param in params) {
      value = value.replaceFirst('%s', param);
    }
    return value;
  }
}

// Extension method for easy access
extension AppLocalizationsViExt on BuildContext {
  AppLocalizationsVi get l10n => AppLocalizationsVi();

  String tr(String key) => AppLocalizationsVi.getString(key);

  String trf(String key, List<String> params) =>
      AppLocalizationsVi.getFormattedString(key, params);
}