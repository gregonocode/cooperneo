class Producao {
  final String id;
  final String formulaId;
  final double quantidadeProduzida;
  final String loteProducao; // Adicionado
  final Map<String, double> materiaPrimaConsumida; // Adicionado
  final DateTime dataProducao;

  Producao({
    required this.id,
    required this.formulaId,
    required this.quantidadeProduzida,
    required this.loteProducao,
    required this.materiaPrimaConsumida,
    required this.dataProducao,
  });

  factory Producao.fromJson(Map<String, dynamic> json) {
    return Producao(
      id: json['id'].toString(),
      formulaId: json['formula_id'].toString(),
      quantidadeProduzida: (json['quantidade_produzida'] as num).toDouble(),
      loteProducao: json['lote_producao'] as String,
      materiaPrimaConsumida:
          (json['materia_prima_consumida'] as Map<String, dynamic>?)?.map(
                (key, value) =>
                    MapEntry(key.toString(), (value as num).toDouble()),
              ) ??
              {},
      dataProducao: DateTime.parse(json['data_producao'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'formula_id': formulaId,
      'quantidade_produzida': quantidadeProduzida,
      'lote_producao': loteProducao,
      'materia_prima_consumida': materiaPrimaConsumida,
      'data_producao': dataProducao.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Producao(id: $id, formulaId: $formulaId, quantidadeProduzida: $quantidadeProduzida, loteProducao: $loteProducao, materiaPrimaConsumida: $materiaPrimaConsumida, dataProducao: $dataProducao)';
  }
}
