class MateriaPrima {
  final String id;
  final String nome;
  final double estoqueAtual;
  final String unidadeMedida;

  MateriaPrima({
    required this.id,
    required this.nome,
    required this.estoqueAtual,
    required this.unidadeMedida,
  });

  factory MateriaPrima.fromJson(Map<String, dynamic> json) {
    return MateriaPrima(
      id: json['id'].toString(),
      nome: json['nome'] as String,
      estoqueAtual: (json['estoque_atual'] as num).toDouble(),
      unidadeMedida: json['unidade_medida'] as String,
    );
  }

  MateriaPrima copyWith({
    String? id,
    String? nome,
    double? estoqueAtual,
    String? unidadeMedida,
  }) {
    return MateriaPrima(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      estoqueAtual: estoqueAtual ?? this.estoqueAtual,
      unidadeMedida: unidadeMedida ?? this.unidadeMedida,
    );
  }

  @override
  String toString() {
    return 'MateriaPrima(id: $id, nome: $nome, estoqueAtual: $estoqueAtual, unidadeMedida: $unidadeMedida)';
  }
}
