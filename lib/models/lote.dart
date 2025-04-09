class Lote {
  final String id;
  final String materiaPrimaId;
  final String fornecedorId;
  final String numeroLote;
  final double quantidadeRecebida;
  final double quantidadeAtual;
  final DateTime dataRecebimento;

  Lote({
    required this.id,
    required this.materiaPrimaId,
    required this.fornecedorId,
    required this.numeroLote,
    required this.quantidadeRecebida,
    required this.quantidadeAtual,
    required this.dataRecebimento,
  });

  factory Lote.fromJson(Map<String, dynamic> json) {
    return Lote(
      id: json['id'].toString(),
      materiaPrimaId: json['materia_prima_id'].toString(),
      fornecedorId: json['fornecedor_id'].toString(),
      numeroLote: json['numero_lote'] as String,
      quantidadeRecebida: (json['quantidade_recebida'] as num).toDouble(),
      quantidadeAtual: (json['quantidade_atual'] as num).toDouble(),
      dataRecebimento: DateTime.parse(json['data_recebimento'] as String),
    );
  }

  @override
  String toString() {
    return 'Lote(id: $id, materiaPrimaId: $materiaPrimaId, fornecedorId: $fornecedorId, numeroLote: $numeroLote, quantidadeRecebida: $quantidadeRecebida, quantidadeAtual: $quantidadeAtual, dataRecebimento: $dataRecebimento)';
  }
}
