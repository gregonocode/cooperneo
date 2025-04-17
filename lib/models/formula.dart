import 'componente_formula.dart';

class Formula {
  final String id;
  final String? userId; // Adicionado para mapear user_id do Supabase
  final String nome;
  final String? descricao; // Opcional, não será usado no producao_screen.dart
  final List<ComponenteFormula> componentes;
  final DateTime? createdAt; // Adicionado para mapear created_at do Supabase

  Formula({
    required this.id,
    this.userId,
    required this.nome,
    this.descricao,
    required this.componentes,
    this.createdAt,
  });

  factory Formula.fromJson(Map<String, dynamic> json) {
    return Formula(
      id: json['id'].toString(),
      userId: json['user_id'] as String?,
      nome: json['nome'] as String,
      descricao: json['descricao'] as String? ??
          '', // Mantido, mas ignorado por enquanto
      componentes: (json['componentes'] as List<dynamic>?)
              ?.map(
                  (c) => ComponenteFormula.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'nome': nome,
      // 'descricao' não incluído aqui para alinhar com producao_screen.dart
      'componentes': componentes.map((c) => c.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Formula copyWith({
    String? id,
    String? userId,
    String? nome,
    String? descricao,
    List<ComponenteFormula>? componentes,
    DateTime? createdAt,
  }) {
    return Formula(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      componentes: componentes ?? this.componentes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Formula(id: $id, userId: $userId, nome: $nome, descricao: $descricao, componentes: $componentes, createdAt: $createdAt)';
  }
}
