import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tag.dart';

/// Service layer around the Supabase `tags` and `security_alerts` tables.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Fetch all tags ordered by updated_at descending.
  Future<List<Tag>> fetchAllTags() async {
    final response = await _client
        .from('tags')
        .select()
        .order('updated_at', ascending: false);

    return (response as List)
        .map((row) => Tag.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single tag by its hex ID.
  Future<Tag?> fetchTag(String tagId) async {
    final response = await _client
        .from('tags')
        .select()
        .eq('id', tagId)
        .maybeSingle();

    if (response == null) return null;
    return Tag.fromJson(response);
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Toggle the lost status of a tag.
  /// When activating "Modo Perda" (PERDIDO), this also signals the collaborative
  /// network to increase scan frequency awareness.
  Future<Tag> toggleLost(Tag tag) async {
    final newStatus = tag.isLost ? 'NORMAL' : 'PERDIDO';
    final response = await _client
        .from('tags')
        .update({
          'status': newStatus,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', tag.id)
        .select()
        .single();

    return Tag.fromJson(response);
  }

  /// Update the public rescue message and phone number.
  Future<Tag> updateContactInfo(
    String tagId, {
    required String mensagem,
    required String telefone,
  }) async {
    final response = await _client
        .from('tags')
        .update({
          'mensagem': mensagem,
          'telefone': telefone,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', tagId)
        .select()
        .single();

    return Tag.fromJson(response);
  }

  /// Update the display name and emoji of a tag.
  Future<Tag> updateNomeEmoji(
    String tagId, {
    required String nome,
    required String emoji,
  }) async {
    final response = await _client
        .from('tags')
        .update({
          'nome': nome,
          'emoji': emoji,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', tagId)
        .select()
        .single();

    return Tag.fromJson(response);
  }

  /// Silently update the GPS coordinates of a detected tag (collaborative network).
  Future<void> updateLocation(
    String tagId, {
    required double latitude,
    required double longitude,
  }) async {
    await _client
        .from('tags')
        .update({
          'latitude': latitude,
          'longitude': longitude,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', tagId);
  }

  /// Insert a new tag (register from BLE scan).
  Future<Tag> registerTag(String tagId, {String nome = '', String emoji = '📦'}) async {
    final response = await _client
        .from('tags')
        .upsert({
          'id': tagId,
          'status': 'NORMAL',
          'mensagem': '',
          'telefone': '',
          'nome': nome,
          'emoji': emoji,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    return Tag.fromJson(response);
  }

  /// Remove the tag association from this user's account in Supabase.
  /// Called after the ESP32-C3 successfully validated the OWNER_SECRET_KEY
  /// and wiped its NVS flash.
  Future<void> unbindTag(String tagId) async {
    await _client
        .from('tags')
        .delete()
        .eq('id', tagId);
  }

  /// Record a security violation alert (status byte 0xFF received via BLE).
  /// Inserts into the `security_alerts` table so the owner is notified.
  ///
  /// Schema expected:
  ///   security_alerts(id uuid, tag_id text, detected_at timestamptz, type text)
  Future<void> insertSecurityAlert(String tagId) async {
    try {
      await _client.from('security_alerts').insert({
        'tag_id': tagId,
        'detected_at': DateTime.now().toUtc().toIso8601String(),
        'type': 'RESET_ATTEMPT',
      });
    } catch (e) {
      // Table may not exist yet in early deployments — fail silently.
      // ignore: avoid_print
      print('[SupabaseService] insertSecurityAlert failed: $e');
    }
  }
}
