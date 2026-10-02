/// Represents a row in the `tags` table.
class Tag {
  final String id;          // e.g. '0x0001'
  final String status;      // 'NORMAL' | 'PERDIDO'
  final String mensagem;    // public message
  final String telefone;    // phone number
  final double? latitude;
  final double? longitude;
  final DateTime? updatedAt;

  const Tag({
    required this.id,
    required this.status,
    this.mensagem = '',
    this.telefone = '',
    this.latitude,
    this.longitude,
    this.updatedAt,
  });

  /// Whether this tag is flagged as lost.
  bool get isLost => status == 'PERDIDO';

  /// Display-friendly label.
  String get label => isLost ? 'Objeto perdido' : 'Tag ativa';

  /// Create from Supabase JSON row.
  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as String,
      status: (json['status'] as String?) ?? 'NORMAL',
      mensagem: (json['mensagem'] as String?) ?? '',
      telefone: (json['telefone'] as String?) ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert to Supabase-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'mensagem': mensagem,
      'telefone': telefone,
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
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
  }) {
    return Tag(
      id: id ?? this.id,
      status: status ?? this.status,
      mensagem: mensagem ?? this.mensagem,
      telefone: telefone ?? this.telefone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Tag && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Tag($id, $status)';
}
