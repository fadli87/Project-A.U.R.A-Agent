/// aura_network — Network monitoring package for AURA.
///
/// Features:
/// - Cellular signal monitoring (RSRP/RSRQ/SINR/CQI) via Android native bridge
/// - WiFi info (SSID, RSSI, channel, band)
/// - LAN device scanner (ARP + mDNS, local subnet only)
/// - Network tools (ping, DNS lookup, traceroute)
/// - Speed test: Download + Upload Mbps + Ping latency (real-time stream)
/// - Drive test: GPS + cellular logging, auto-stop 4h, CSV/KML export
///
/// Compliance:
/// - Sensitif: cellular + WiFi require ACCESS_FINE_LOCATION + READ_PHONE_STATE
/// - Speed test: mengirim data ke server eksternal — UI wajib tampilkan disclosure
/// - LAN scan: hanya subnet lokal, tidak agresif

library aura_network;

// Models
export 'models/cell_signal_info.dart';
export 'models/wifi_info.dart';
export 'models/lan_device.dart';
export 'models/ping_result.dart';
export 'models/speed_test_result.dart';
export 'models/drive_test_log.dart';

// Services
export 'services/telephony_bridge.dart';
export 'services/wifi_service.dart';
export 'services/lan_scanner.dart';
export 'services/network_tools.dart';
export 'services/speed_test_service.dart';
export 'services/drive_test_manager.dart';

// Providers
export 'providers/network_monitor_provider.dart';
export 'providers/drive_test_provider.dart';

// Widgets
export 'widgets/signal_monitor_card.dart';
export 'widgets/wifi_info_card.dart';
export 'widgets/speed_test_widget.dart';
export 'widgets/lan_devices_list.dart';
export 'widgets/drive_test_controls.dart';
export 'widgets/signal_heatmap_widget.dart';
export 'widgets/network_tools_panel.dart';
