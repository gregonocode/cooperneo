class Fornecedor {
  final String id;
  final String nome;
  final String contato;
  final String endereco;

  Fornecedor({
    required this.id,
    required this.nome,
    required this.contato,
    required this.endereco,
  });

  factory Fornecedor.fromJson(Map<String, dynamic> json) {
    return Fornecedor(
      id: json['id'].toString(),
      nome: json['nome'] as String,
      contato: json['contato'] as String,
      endereco: json['endereco'] as String,
    );
  }

  Fornecedor copyWith({
    String? id,
    String? nome,
    String? contato,
    String? endereco,
  }) {
    return Fornecedor(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      contato: contato ?? this.contato,
      endereco: endereco ?? this.endereco,
    );
  }

  @override
  String toString() {
    return 'Fornecedor(id: $id, nome: $nome, contato: $contato, endereco: $endereco)';
  }
}
