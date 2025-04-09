class ComponenteFormula {
  final String materiaPrimaId;
  final double quantidade;
  final String unidadeMedida;

  ComponenteFormula({
    required this.materiaPrimaId,
    required this.quantidade,
    required this.unidadeMedida,
  });

  factory ComponenteFormula.fromJson(Map<String, dynamic> json) {
    return ComponenteFormula(
      materiaPrimaId: json['materia_prima_id'].toString(),
      quantidade: (json['quantidade'] as num).toDouble(),
      unidadeMedida: json['unidade_medida'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'materia_prima_id': materiaPrimaId,
      'quantidade': quantidade,
      'unidade_medida': unidadeMedida,
    };
  }

  @override
  String toString() {
    return 'ComponenteFormula(materiaPrimaId: $materiaPrimaId, quantidade: $quantidade, unidadeMedida: $unidadeMedida)';
  }
}
