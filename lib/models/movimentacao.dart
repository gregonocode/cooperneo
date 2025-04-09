enum TipoMovimentacao { entrada, saida }

class Movimentacao {
  final String id;
  final String materiaPrimaId;
  final TipoMovimentacao tipo;
  final double quantidade;
  final String motivo;
  final DateTime data;

  Movimentacao({
    required this.id,
    required this.materiaPrimaId,
    required this.tipo,
    required this.quantidade,
    required this.motivo,
    required this.data,
  });

  factory Movimentacao.fromJson(Map<String, dynamic> json) {
    return Movimentacao(
      id: json['id'].toString(),
      materiaPrimaId: json['materia_prima_id'].toString(),
      tipo: json['tipo'] == 'entrada'
          ? TipoMovimentacao.entrada
          : TipoMovimentacao.saida,
      quantidade: (json['quantidade'] as num).toDouble(),
      motivo: json['motivo'] as String,
      data: DateTime.parse(json['data'] as String),
    );
  }

  @override
  String toString() {
    return 'Movimentacao(id: $id, materiaPrimaId: $materiaPrimaId, tipo: $tipo, quantidade: $quantidade, motivo: $motivo, data: $data)';
  }
}
