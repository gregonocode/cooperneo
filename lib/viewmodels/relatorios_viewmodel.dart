import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:intl/intl.dart';

import '../models/materia_prima.dart';
import '../models/formula.dart';
import '../models/producao.dart';
import '../services/supabase_service.dart';
import 'package:collection/collection.dart';

class RelatoriosViewModel extends ChangeNotifier {
  final SupabaseService _supabaseService;

  List<MateriaPrima> _materiasPrimas = [];
  List<Formula> _formulas = [];
  List<Producao> _producoes = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<MateriaPrima> get materiasPrimas => _materiasPrimas;
  List<Formula> get formulas => _formulas;
  List<Producao> get producoes => _producoes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  RelatoriosViewModel({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService() {
    carregarDados();
  }

  Future<void> carregarDados() async {
    _isLoading = true;
    notifyListeners();

    try {
      _materiasPrimas = await _supabaseService.fetchMateriasPrimas();
      _formulas = await _supabaseService.fetchFormulas();
      _producoes = await _supabaseService.getProducoes();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Erro ao carregar dados: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Formula? getFormulaPorId(String id) {
    return _formulas.firstWhereOrNull((formula) => formula.id == id);
  }

  MateriaPrima? getMateriaPrimaPorId(String id) {
    return _materiasPrimas.firstWhereOrNull((mp) => mp.id == id);
  }

  Future<File> gerarRelatorioDiarioPDF(DateTime data) async {
    final pdf = pw.Document();
    final producoesDoDia = _producoes
        .where((p) =>
            p.dataProducao.year == data.year &&
            p.dataProducao.month == data.month &&
            p.dataProducao.day == data.day)
        .toList();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
                'Relatório Diário - ${DateFormat('dd/MM/yyyy').format(data)}',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            if (producoesDoDia.isEmpty)
              pw.Text('Nenhuma produção registrada neste dia.')
            else
              pw.Table.fromTextArray(
                headers: ['Fórmula', 'Lote', 'Quantidade', 'Data'],
                data: producoesDoDia.map((p) {
                  final formula = getFormulaPorId(p.formulaId);
                  return [
                    formula?.nome ?? 'Desconhecida',
                    p.loteProducao,
                    '${p.quantidadeProduzida.toStringAsFixed(2)} kg',
                    DateFormat('dd/MM/yyyy').format(p.dataProducao),
                  ];
                }).toList(),
              ),
          ],
        ),
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File(
        '${output.path}/relatorio_diario_${DateFormat('yyyyMMdd').format(data)}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<File> gerarRelatorioSemanalPDF(DateTime data) async {
    final pdf = pw.Document();
    final inicioSemana = data.subtract(Duration(days: data.weekday - 1));
    final fimSemana = inicioSemana.add(const Duration(days: 6));
    final producoesDaSemana = _producoes
        .where((p) =>
            p.dataProducao
                .isAfter(inicioSemana.subtract(const Duration(days: 1))) &&
            p.dataProducao.isBefore(fimSemana.add(const Duration(days: 1))))
        .toList();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
                'Relatório Semanal - ${DateFormat('dd/MM/yyyy').format(inicioSemana)} a ${DateFormat('dd/MM/yyyy').format(fimSemana)}',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            if (producoesDaSemana.isEmpty)
              pw.Text('Nenhuma produção registrada nesta semana.')
            else
              pw.Table.fromTextArray(
                headers: ['Fórmula', 'Lote', 'Quantidade', 'Data'],
                data: producoesDaSemana.map((p) {
                  final formula = getFormulaPorId(p.formulaId);
                  return [
                    formula?.nome ?? 'Desconhecida',
                    p.loteProducao,
                    '${p.quantidadeProduzida.toStringAsFixed(2)} kg',
                    DateFormat('dd/MM/yyyy').format(p.dataProducao),
                  ];
                }).toList(),
              ),
          ],
        ),
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File(
        '${output.path}/relatorio_semanal_${DateFormat('yyyyMMdd').format(data)}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<File> gerarRelatorioPersonalizadoPDF(DateTime inicio, DateTime fim,
      [String? empresa]) async {
    final pdf = pw.Document();
    final producoesPeriodo = _producoes
        .where((p) =>
            p.dataProducao.isAfter(inicio.subtract(const Duration(days: 1))) &&
            p.dataProducao.isBefore(fim.add(const Duration(days: 1))))
        .toList();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
                'Relatório Personalizado - ${DateFormat('dd/MM/yyyy').format(inicio)} a ${DateFormat('dd/MM/yyyy').format(fim)}',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            if (empresa != null) pw.Text('Empresa: $empresa'),
            pw.SizedBox(height: 20),
            if (producoesPeriodo.isEmpty)
              pw.Text('Nenhuma produção registrada neste período.')
            else
              pw.Table.fromTextArray(
                headers: ['Fórmula', 'Lote', 'Quantidade', 'Data'],
                data: producoesPeriodo.map((p) {
                  final formula = getFormulaPorId(p.formulaId);
                  return [
                    formula?.nome ?? 'Desconhecida',
                    p.loteProducao,
                    '${p.quantidadeProduzida.toStringAsFixed(2)} kg',
                    DateFormat('dd/MM/yyyy').format(p.dataProducao),
                  ];
                }).toList(),
              ),
          ],
        ),
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File(
        '${output.path}/relatorio_personalizado_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<File> gerarRelatorioEstoquePDF() async {
    final pdf = pw.Document();
    final materiasOrdenadas = List<MateriaPrima>.from(_materiasPrimas)
      ..sort((a, b) => a.estoqueAtual.compareTo(b.estoqueAtual));

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
                'Relatório de Estoque - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            if (materiasOrdenadas.isEmpty)
              pw.Text('Nenhuma matéria-prima cadastrada.')
            else
              pw.Table.fromTextArray(
                headers: ['Matéria-Prima', 'Estoque Atual', 'Unidade'],
                data: materiasOrdenadas
                    .map((m) => [
                          m.nome,
                          m.estoqueAtual.toStringAsFixed(2),
                          m.unidadeMedida,
                        ])
                    .toList(),
              ),
          ],
        ),
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File(
        '${output.path}/relatorio_estoque_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> visualizarPDF(File file) async {
    // Para web, você pode usar um pacote como `universal_html` para abrir o PDF
    // Para este exemplo, vamos apenas compartilhar o arquivo
    await compartilharPDF(file);
  }

  Future<void> compartilharPDF(File file) async {
    if (await file.exists()) {
      await Share.shareXFiles([XFile(file.path)], text: 'Relatório gerado');
    } else {
      throw Exception('Arquivo PDF não encontrado');
    }
  }
}
