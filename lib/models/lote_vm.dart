// lib/models/lote_vm.dart
enum LoteStrategy { fifo, lifo, fefo }

class LoteVM {
  final String id; // "123"
  final String materiaPrimaId; // "45"
  final String numeroLote; // "48515193"
  final DateTime dataRecebimento;
  final DateTime? dataValidade;
  double quantidadeAtual; // saldo (mutável enquanto consome em memória)
  final bool ativo;

  LoteVM({
    required this.id,
    required this.materiaPrimaId,
    required this.numeroLote,
    required this.dataRecebimento,
    required this.quantidadeAtual,
    required this.ativo,
    this.dataValidade,
  });
}
