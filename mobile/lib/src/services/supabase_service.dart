import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tag.dart';

/// Service layer around the Supabase `tags` table.
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

  /// Update the public message and phone number.
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

  /// Insert a new tag (register).
  Future<Tag> registerTag(String tagId) async {
    final response = await _client
        .from('tags')
        .upsert({
          'id': tagId,
          'status': 'NORMAL',
          'mensagem': '',
          'telefone': '',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    return Tag.fromJson(response);
  }
}
