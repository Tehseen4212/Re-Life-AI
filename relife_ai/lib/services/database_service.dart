import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/sensor_log.dart';

class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Globally shared stream cache to prevent Supabase websocket overloading across tabs
  static Stream<List<Product>>? _sharedStoreProductsStream;
  static List<Product>? cachedGlobalProducts;
  static String? _lastStoreOwnerId;
  
  static Stream<List<Map<String, dynamic>>>? _sharedNotificationsStream;
  static List<Map<String, dynamic>>? cachedGlobalNotifications;
  static String? _lastNotificationUserId;

  static void clearStreamCache() {
    _sharedStoreProductsStream = null;
    cachedGlobalProducts = null;
    _lastStoreOwnerId = null;
    _sharedNotificationsStream = null;
    cachedGlobalNotifications = null;
    _lastNotificationUserId = null;
  }

  // Real-time Stream for Products specific to a Store Owner
  Stream<List<Product>> streamStoreProducts(String storeOwnerId) {
    if (_sharedStoreProductsStream == null || _lastStoreOwnerId != storeOwnerId) {
      _lastStoreOwnerId = storeOwnerId;
      _sharedStoreProductsStream = _supabase
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('store_owner_id', storeOwnerId)
          .map((maps) {
            final list = maps.map((map) => Product.fromJson(map)).toList();
            list.sort((a, b) => b.entryDate.compareTo(a.entryDate));
            cachedGlobalProducts = list; // Update sync cache!
            return list;
          }).asBroadcastStream(); // Multiplex to all tabs
    }
    return _sharedStoreProductsStream!;
  }

  // Fast direct fetch to bypass slow WebSocket initialization load times
  Future<List<Product>> getStoreProductsFast(String storeOwnerId) async {
    try {
      final data = await _supabase.from('products').select().eq('store_owner_id', storeOwnerId);
      final list = data.map((e) => Product.fromJson(e)).toList();
      list.sort((a, b) => b.entryDate.compareTo(a.entryDate));
      cachedGlobalProducts = list; // Save for initialData rendering
      return list;
    } catch (_) { return []; }
  }

  // Real-time Stream for Sensor Logs of a specific product
  Stream<List<SensorLog>> streamProductSensorLogs(String productId) {
    return _supabase
        .from('sensor_logs')
        .stream(primaryKey: ['id'])
        .eq('product_id', productId)
        .map((maps) {
           final list = maps.map((map) => SensorLog.fromJson(map)).toList();
           list.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
           return list;
        });
  }

  // Fetch Product internally (Static)
  Future<Product?> getProduct(String id) async {
    try {
      final data = await _supabase.from('products').select().eq('id', id).maybeSingle();
      if (data == null) return null;
      return Product.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  // Stream Single Product (Realtime Sync)
  Stream<Product?> streamProduct(String id) {
    return _supabase.from('products').stream(primaryKey: ['id']).eq('id', id).map((event) {
      if (event.isEmpty) return null;
      return Product.fromJson(event.first);
    });
  }

  // Add new product
  Future<void> addProduct(Map<String, dynamic> productData) async {
    await _supabase.from('products').insert(productData);
  }

  // Update existing product
  Future<void> updateProduct(String id, Map<String, dynamic> updateData) async {
    await _supabase.from('products').update(updateData).eq('id', id);
  }

  // Delete product completely
  Future<void> deleteProduct(String id) async {
    await _supabase.from('products').delete().eq('id', id);
  }

  // Create a Donation / Offer (Store Owner)
  Future<void> createDonation(String productId, String storeOwnerId, {String requestType = 'donation'}) async {
    // 1. Force delete all old/dead requests for this product to prevent duplicate blocking
    try { await _supabase.from('donations').delete().eq('product_id', productId); } catch (_) {}
    
    // 2. Just in case RLS blocked delete, also mark it as revoked so it drops out of pending streams
    try { await _supabase.from('donations').update({'status': 'revoked'}).eq('product_id', productId).inFilter('status', ['pending', 'rejected']); } catch (_) {}

    // 3. Cleanly insert a brand new request
    await _supabase.from('donations').insert({
      'product_id': productId,
      'store_owner_id': storeOwnerId,
      'status': 'pending',
      'request_type': requestType,
    });

    // Update product status based on type
    if (requestType == 'donation') {
      await _supabase.from('products').update({'status': 'donated'}).eq('id', productId);
    } else {
      await _supabase.from('products').update({'status': 'offered'}).eq('id', productId);
    }
  }

  // Revoke Donation/Offer by Store Owner (Cancels the pending request and makes product active)
  Future<void> revokeStoreRequest(String productId) async {
    // Deep wipe: Try to delete first
    try { await _supabase.from('donations').delete().eq('product_id', productId); } catch (_) {}
    // Fallback: If RLS blocked delete, forcefully change status to 'revoked' to hide it from NGO tabs
    try { await _supabase.from('donations').update({'status': 'revoked'}).eq('product_id', productId).inFilter('status', ['pending', 'claimed']); } catch (_) {}
    
    // Reset product status back to active
    await _supabase.from('products').update({'status': 'active'}).eq('id', productId);
  }

  // Stream Pending Donations (NGO View)
  Stream<List<Map<String, dynamic>>> streamPendingDonations() {
    return _supabase
        .from('donations')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at')
        .asyncMap((donations) async {
          if (donations.isEmpty) return [];
          
          final ids = donations.map((d) => d['id'] as String).toList();
          final enriched = await _supabase
            .from('donations')
            .select('*, product:products(*), store:users!store_owner_id(*)')
            .inFilter('id', ids);
          
          return List<Map<String, dynamic>>.from(enriched);
        });
  }

  // Stream Accepted History (NGO View)
  Stream<List<Map<String, dynamic>>> streamDonationHistory(String ngoId) {
    return _supabase
        .from('donations')
        .stream(primaryKey: ['id'])
        .eq('ngo_id', ngoId)
        .order('created_at', ascending: false)
        .asyncMap((donations) async {
          if (donations.isEmpty) return [];
          
          final ids = donations.map((d) => d['id'] as String).toList();
          final enriched = await _supabase
            .from('donations')
            .select('*, product:products(*), store:users!store_owner_id(*)')
            .inFilter('id', ids);
            
          return List<Map<String, dynamic>>.from(enriched);
        });
  }

  // Claim Donation (NGO) - 2 Step verification
  Future<void> claimDonation(String donationId, String productId, String ngoId) async {
    await _supabase.from('donations').update({
      'status': 'claimed',
      'ngo_id': ngoId
    }).eq('id', donationId);
  }

  // Stream All Donation/Offer History (Store View Tracking) - includes active/pending
  Stream<List<Map<String, dynamic>>> streamDonationHistoryForStore(String storeOwnerId) {
    return _supabase
        .from('donations')
        .stream(primaryKey: ['id'])
        .eq('store_owner_id', storeOwnerId)
        .order('created_at', ascending: false)
        .asyncMap((donations) async {
          if (donations.isEmpty) return [];
          
          final ids = donations.map((d) => d['id'] as String).toList();
          final enriched = await _supabase
            .from('donations')
            .select('*, product:products(*), ngo:users!ngo_id(*)')
            .inFilter('id', ids);
            
          return List<Map<String, dynamic>>.from(enriched);
        });
  }

  // Approve/Complete Handover (Store Owner)
  Future<void> approveDonation(String donationId) async {
    await _supabase.from('donations').update({
      'status': 'completed'
    }).eq('id', donationId);
    
    // Also explicitly force product to sold to clear it permanently from active displays if it wasn't already
    final d = await _supabase.from('donations').select('product_id').eq('id', donationId).single();
    await _supabase.from('products').update({'status': 'sold'}).eq('id', d['product_id']);
  }

  // Reject Claim (Store Owner marks as rejected so NGO keeps history, then clones a fresh pending row so others can claim)
  Future<void> rejectDonation(String donationId) async {
    await _supabase.from('donations').update({
      'status': 'rejected'
    }).eq('id', donationId);

    final d = await _supabase.from('donations').select().eq('id', donationId).single();
    await _supabase.from('donations').insert({
      'product_id': d['product_id'],
      'store_owner_id': d['store_owner_id'],
      'status': 'pending',
      'request_type': d['request_type']
    });
  }

  // Cancel Claim (NGO marks as rejected for their own history, then frees up the product)
  Future<void> cancelDonation(String donationId) async {
    await _supabase.from('donations').update({
      'status': 'rejected'
    }).eq('id', donationId);

    final d = await _supabase.from('donations').select().eq('id', donationId).single();
    await _supabase.from('donations').insert({
      'product_id': d['product_id'],
      'store_owner_id': d['store_owner_id'],
      'status': 'pending',
      'request_type': d['request_type']
    });
  }

  // Update User Profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    await _supabase.from('users').update(data).eq('id', userId);
  }

  // Update Product Price
  Future<void> updateProductPrice(String productId, double newPrice) async {
    await _supabase.from('products').update({'price': newPrice}).eq('id', productId);
  }

  Future<void> markProductSold(String productId) async {
    await _supabase.from('products').update({'status': 'sold'}).eq('id', productId);
  }

  // Forcefully update dynamic physics tracking points. Absolute dates shouldn't be overwritten.
  Future<void> updateProductScanOverrides(String productId, double newFreshness) async {
    Map<String, dynamic> payload = {
       'freshness_score': newFreshness,
    };
    await _supabase.from('products').update(payload).eq('id', productId);
  }

  // Upload Local Edge ML Analysis Photos to Storage
  Future<List<String>> uploadAnalysisPhotos(List<File> images) async {
    List<String> urls = [];
    for (int i = 0; i < images.length; i++) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      await _supabase.storage.from('product_scans').upload(fileName, images[i]);
      final url = _supabase.storage.from('product_scans').getPublicUrl(fileName);
      urls.add(url);
    }
    return urls;
  }

  // Save new Manual Local AI Sensor Log Snapshot
  Future<void> addSensorLog(Map<String, dynamic> data) async {
    await _supabase.from('sensor_logs').insert(data);
  }

  // Auto-Cleanup Logic: Deletes sold/donated items after 3 days
  Future<void> cleanupOldData(String userId) async {
    try {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 3)).toIso8601String();

      // 1. Delete associated donations that are completed/rejected and older than 3 days
      // This will also cascade delete the products because of SQL 'on delete cascade'
      final oldDonations = await _supabase
          .from('donations')
          .select('id, product_id')
          .eq('store_owner_id', userId)
          .inFilter('status', ['completed', 'rejected', 'claimed'])
          .lt('created_at', cutoff);
      
      for (var d in oldDonations) {
        await _supabase.from('products').delete().eq('id', d['product_id']);
      }

      // 2. Cleanup manually sold products (without donation record)
      // Since we don't have status_updated_at yet, we check entry_date + status
      await _supabase
          .from('products')
          .delete()
          .eq('store_owner_id', userId)
          .eq('status', 'sold')
          .lt('status_updated_at', cutoff);
    } catch (e) {
      // Silenced cleanup print for production
    }
  }

  // Stream Notifications for a User seamlessly multiplexed
  Stream<List<Map<String, dynamic>>> streamNotifications(String userId) {
    if (_sharedNotificationsStream == null || _lastNotificationUserId != userId) {
      _lastNotificationUserId = userId;
      _sharedNotificationsStream = _supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .map((maps) {
            cachedGlobalNotifications = maps;
            return maps;
          })
          .asBroadcastStream();
    }
    return _sharedNotificationsStream!;
  }

  // Fast direct fetch to bypass slow WebSocket initialization for notifications
  Future<List<Map<String, dynamic>>> getNotificationsFast(String userId) async {
    try {
      final data = await _supabase.from('notifications').select().eq('user_id', userId).order('created_at', ascending: false);
      cachedGlobalNotifications = List<Map<String, dynamic>>.from(data);
      return cachedGlobalNotifications!;
    } catch (_) { return []; }
  }

  // Mark Notification as Read
  Future<void> markNotificationRead(String id) async {
    if (cachedGlobalNotifications != null) {
      final index = cachedGlobalNotifications!.indexWhere((n) => n['id'] == id);
      if (index != -1) {
        cachedGlobalNotifications![index] = {...cachedGlobalNotifications![index], 'is_read': true};
      }
    }
    await _supabase.from('notifications').update({'is_read': true}).eq('id', id);
  }

  // Delete Notification
  Future<void> deleteNotification(String id) async {
    if (cachedGlobalNotifications != null) {
      cachedGlobalNotifications!.removeWhere((n) => n['id'] == id);
    }
    await _supabase.from('notifications').delete().eq('id', id);
  }

  // Fallback: Get highest/latest sensor log globally if a product is missing one
  Future<SensorLog?> getLatestGlobalSensorLog() async {
    try {
      final data = await _supabase.from('sensor_logs').select().order('recorded_at', ascending: false).limit(1).maybeSingle();
      if (data == null) return null;
      return SensorLog.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}


