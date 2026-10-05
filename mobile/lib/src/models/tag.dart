/// Represents a row in the `tags` table.
class Tag {
  final String id;          // hex device ID e.g. '0x0001'
  final String status;      // 'NORMAL' | 'PERDIDO'
  final String mensagem;    // public rescue message
  final String telefone;    // phone / WhatsApp number
  final String nome;        // user-defined object name (e.g. "Minha Mochila")
  final String emoji;       // user-chosen emoji (e.g. "🎒")
  final double? latitude;
  final double? longitude;
  final DateTime? updatedAt;

  /// Owner secret key stored locally (NOT sent to Supabase).
  /// Used for the anti-reset / secure unbind flow.
  /// This is persisted in SharedPreferences, keyed by tag ID.
  final String? ownerSecretKey;

  const Tag({
    required this.id,
    required this.status,
    this.mensagem = '',
    this.telefone = '',
    this.nome = '',
    this.emoji = '📦',
    this.latitude,
    this.longitude,
    this.updatedAt,
    this.ownerSecretKey,
  });

  /// Whether this tag is flagged as lost.
  bool get isLost => status == 'PERDIDO';

  /// Display-friendly label.
  String get label => nome.isNotEmpty ? nome : id;

  /// Public rescue page URL.
  String get rescueUrl => 'https://tagfind.app/p/$id';

  /// Create from Supabase JSON row.
  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as String,
      status: (json['status'] as String?) ?? 'NORMAL',
      mensagem: (json['mensagem'] as String?) ?? '',
      telefone: (json['telefone'] as String?) ?? '',
      nome: (json['nome'] as String?) ?? '',
      emoji: (json['emoji'] as String?) ?? '📦',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert to Supabase-compatible map (ownerSecretKey is NOT sent).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'mensagem': mensagem,
      'telefone': telefone,
      'nome': nome,
      'emoji': emoji,
      'latitude': latitude,
      'longitude': longitude,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Create a copy with modified fields.
  Tag copyWith({
    String? id,
    String? status,
    String? mensagem,
    String? telefone,
    String? nome,
    String? emoji,
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
    String? ownerSecretKey,
  }) {
    return Tag(
      id: id ?? this.id,
      status: status ?? this.status,
      mensagem: mensagem ?? this.mensagem,
      telefone: telefone ?? this.telefone,
      nome: nome ?? this.nome,
      emoji: emoji ?? this.emoji,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      updatedAt: updatedAt ?? this.updatedAt,
      ownerSecretKey: ownerSecretKey ?? this.ownerSecretKey,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Tag && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Tag($id, $status, nome=$nome)';
}
