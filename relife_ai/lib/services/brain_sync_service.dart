import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';

class BrainSyncService {
  static final BrainSyncService instance = BrainSyncService._internal();
  BrainSyncService._internal();

  final _supabase = Supabase.instance.client;
  Timer? _syncTimer;
  RealtimeChannel? _productsChannel;
  RealtimeChannel? _donationsChannel;
  RealtimeChannel? _sensorChannel;
  RealtimeChannel? _binsChannel;
  RealtimeChannel? _telemetryChannel;
  String? _currentUserId;

  void startSync(String userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    
    // Initial sync
    _performSync();

    // Re-sync every 3 minutes natively as a fallback
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 3), (_) => _performSync());

    // Listen to real-time events natively
    _productsChannel?.unsubscribe();
    _productsChannel = _supabase.channel('public:products').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'products',
      callback: (payload) => _performSync(),
    ).subscribe();

    _donationsChannel?.unsubscribe();
    _donationsChannel = _supabase.channel('public:donations').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'donations',
      callback: (payload) => _performSync(),
    ).subscribe();

    _sensorChannel?.unsubscribe();
    _sensorChannel = _supabase.channel('public:sensor_logs').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sensor_logs',
      callback: (payload) => _performSync(),
    ).subscribe();

    _binsChannel?.unsubscribe();
    _binsChannel = _supabase.channel('public:storage_bins').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'storage_bins',
      callback: (payload) => _performSync(),
    ).subscribe();

    _telemetryChannel?.unsubscribe();
    _telemetryChannel = _supabase.channel('public:storage_telemetry_logs').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'storage_telemetry_logs',
      callback: (payload) => _performSync(),
    ).subscribe();
  }

  void stopSync() {
    _syncTimer?.cancel();
    _productsChannel?.unsubscribe();
    _donationsChannel?.unsubscribe();
    _sensorChannel?.unsubscribe();
    _binsChannel?.unsubscribe();
    _telemetryChannel?.unsubscribe();
    _currentUserId = null;
  }

  Future<void> _performSync() async {
    if (_currentUserId == null) return;
    try {
      final productsRes = await _supabase.from('products').select().eq('store_owner_id', _currentUserId!);
      final donationsRes = await _supabase.from('donations').select().eq('store_owner_id', _currentUserId!);
      
      // Attempt fetching advanced hardware/log tables safely
      List<dynamic> binsRes = [];
      List<dynamic> sensorLogsRes = [];
      List<dynamic> telemetryRes = [];
      
      try { binsRes = await _supabase.from('storage_bins').select().limit(50); } catch (_) {}
      try { sensorLogsRes = await _supabase.from('sensor_logs').select().order('recorded_at', ascending: false).limit(50); } catch (_) {}
      try { telemetryRes = await _supabase.from('storage_telemetry_logs').select().order('recorded_at', ascending: false).limit(50); } catch (_) {}

      int totalItems = productsRes.length;
      int pendingDonations = donationsRes.where((d) => d['status'] == 'pending' || d['status'] == 'claimed').length;
      int completedDonations = donationsRes.where((d) => d['status'] == 'completed').length;
      
      String masterContext = "--- RELIFE STORE DATABASE SNAPSHOT ---\n";
      masterContext += "Total Unique Products: $totalItems\n";
      masterContext += "Pending/Awaiting Dispatches: $pendingDonations\n";
      masterContext += "Successfully Completed Dispatches: $completedDonations\n\n";
      
      masterContext += "[PRODUCTS TABLE]\n";
      for(var p in productsRes) {
         masterContext += "ID: ${p['id']} - Name: ${p['name']} (Category: ${p['category']}, Qty: ${p['quantity']}, Status: ${p['status']}, StorageNo: ${p['storage_no']}, LifeDays: ${p['shelf_life_days']})\n";
      }
      masterContext += "\n";

      masterContext += "[STORAGE BINS TABLE]\n";
      if (binsRes.isEmpty) masterContext += "No bins recorded.\n";
      for(var b in binsRes) {
         masterContext += "Bin: ${b['bin_no']} - Type: ${b['zone_type']} (Temp Setup: ${b['working_temp']}, Hum Setup: ${b['working_humidity']}, Status: ${b['door_status']})\n";
      }
      masterContext += "\n";

      masterContext += "[RECENT SENSOR LOGS (Products)]\n";
      if (sensorLogsRes.isEmpty) masterContext += "No recent sensor logs.\n";
      for(var s in sensorLogsRes) {
         masterContext += "Log - ProdID: ${s['product_id']} | Temp: ${s['temperature']}°C | Hum: ${s['humidity']}% | Freshness(ML): ${s['freshness_score']} | At: ${s['recorded_at']}\n";
      }
      masterContext += "\n";

      masterContext += "[RECENT TELEMETRY LOGS (Storage Units)]\n";
      if (telemetryRes.isEmpty) masterContext += "No recent telemetry logs.\n";
      for(var t in telemetryRes) {
         masterContext += "Log - BinNo: ${t['bin_no']} | AvgTemp: ${t['avg_temp']}°C | DoorOpens: ${t['door_opens']} | PowerFailures: ${t['power_failures']} | Flags: ${t['hardware_flags']} | Notes: ${t['ai_log_notes']}\n";
      }
      masterContext += "\n";

      masterContext += "--- END SNAPSHOT ---\nInstructions for AI: ALWAYS use the data from these tables directly to answer. If asked about a table, report the information listed above.";

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/brain_cache.txt');
      await file.writeAsString(masterContext);
    } catch (e) {
      // Ignore background errors
    }
  }
}
