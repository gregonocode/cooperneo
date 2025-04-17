import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:collection/collection.dart';

import '../models/materia_prima.dart';
import '../models/formula.dart';
import '../models/producao.dart';
import '../services/supabase_service.dart';

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

      // Logs para verificar os dados carregados
      print('Matérias-primas carregadas: $_materiasPrimas');
      print('Fórmulas carregadas: $_formulas');
      print('Produções carregadas: $_producoes');

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Erro ao carregar dados: $e';
      print('Erro ao carregar dados: $e');
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

  Future<pw.Font> _loadRobotoFont() async {
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    return pw.Font.ttf(fontData);
  }

  Future<Uint8List> gerarRelatorioDiarioPDF(DateTime data) async {
    final pdfDoc = pw.Document();
    final robotoFont = await _loadRobotoFont();

    // Filtrar produções do dia
    final producoesDoDia = _producoes
        .where((p) =>
            p.dataProducao.year == data.year &&
            p.dataProducao.month == data.month &&
            p.dataProducao.day == data.day)
        .toList();

    // Construir os dados da tabela
    final List<List<dynamic>> tableData = [];

    for (final producao in producoesDoDia) {
      final formula = getFormulaPorId(producao.formulaId);

      // Adicionar linha da produção (centralizando o nome da fórmula)
      tableData.add([
        pw.Center(
            child: pw.Text(formula?.nome ?? 'Desconhecida')), // Centralizado
        producao.loteProducao,
        '${producao.quantidadeProduzida.toStringAsFixed(2)} btd',
      ]);

      // Adicionar linhas das matérias-primas utilizadas
      if (formula != null && formula.componentes.isNotEmpty) {
        for (final componente in formula.componentes) {
          final materiaPrima = getMateriaPrimaPorId(componente.materiaPrimaId);
          tableData.add([
            materiaPrima?.nome ?? 'Desconhecida', // Nome da matéria-prima
            componente.materiaPrimaId,
            '${componente.quantidade.toStringAsFixed(2)} ${componente.unidadeMedida}',
          ]);
        }
      }

      // Adicionar uma linha em branco após cada produção
      tableData.add(['', '', '']);
    }

    pdfDoc.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Título do relatório
            pw.Text(
              'Relatório Diário - ${DateFormat('dd/MM/yyyy').format(data)}',
              style: pw.TextStyle(
                fontSize: 20,
                font: robotoFont,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),

            // Tabela Única
            if (tableData.isEmpty)
              pw.Text(
                'Nenhuma produção registrada neste dia.',
                style: pw.TextStyle(font: robotoFont),
              )
            else
              pw.Table.fromTextArray(
                headers: ['Fórmula', 'Lote', 'Quantidade'],
                cellStyle: pw.TextStyle(font: robotoFont),
                headerStyle: pw.TextStyle(
                  font: robotoFont,
                  fontWeight: pw.FontWeight.bold,
                ),
                data: tableData,
              ),
          ],
        ),
      ),
    );

    return await pdfDoc.save();
  }

  Future<Uint8List> gerarRelatorioSemanalPDF(DateTime data) async {
    final pdfDoc = pw.Document();
    final robotoFont = await _loadRobotoFont();

    // Calcular o início e o fim da semana
    final inicioSemana = data.subtract(Duration(days: data.weekday - 1));
    final fimSemana = inicioSemana.add(const Duration(days: 6));

    // Filtrar produções da semana
    final producoesDaSemana = _producoes
        .where((p) =>
            p.dataProducao
                .isAfter(inicioSemana.subtract(const Duration(days: 1))) &&
            p.dataProducao.isBefore(fimSemana.add(const Duration(days: 1))))
        .toList();

    // Construir os dados da tabela
    final List<List<dynamic>> tableData = [];

    for (final producao in producoesDaSemana) {
      final formula = getFormulaPorId(producao.formulaId);

      // Adicionar linha da produção (centralizando o nome da fórmula)
      tableData.add([
        pw.Center(
            child: pw.Text(formula?.nome ?? 'Desconhecida')), // Centralizado
        producao.loteProducao,
        '${producao.quantidadeProduzida.toStringAsFixed(2)} btd',
      ]);

      // Adicionar linhas das matérias-primas utilizadas
      if (formula != null && formula.componentes.isNotEmpty) {
        for (final componente in formula.componentes) {
          final materiaPrima = getMateriaPrimaPorId(componente.materiaPrimaId);
          tableData.add([
            materiaPrima?.nome ?? 'Desconhecida', // Nome da matéria-prima
            componente.materiaPrimaId,
            '${componente.quantidade.toStringAsFixed(2)} ${componente.unidadeMedida}',
          ]);
        }
      }

      // Adicionar uma linha em branco após cada produção
      tableData.add(['', '', '']);
    }

    pdfDoc.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Título do relatório
            pw.Text(
              'Relatório Semanal - ${DateFormat('dd/MM/yyyy').format(inicioSemana)} a ${DateFormat('dd/MM/yyyy').format(fimSemana)}',
              style: pw.TextStyle(
                fontSize: 20,
                font: robotoFont,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),

            // Tabela Única
            if (tableData.isEmpty)
              pw.Text(
                'Nenhuma produção registrada nesta semana.',
                style: pw.TextStyle(font: robotoFont),
              )
            else
              pw.Table.fromTextArray(
                headers: ['Fórmula', 'Lote', 'Quantidade'],
                cellStyle: pw.TextStyle(font: robotoFont),
                headerStyle: pw.TextStyle(
                  font: robotoFont,
                  fontWeight: pw.FontWeight.bold,
                ),
                data: tableData,
              ),
          ],
        ),
      ),
    );

    return await pdfDoc.save();
  }

  Future<Uint8List> gerarRelatorioPersonalizadoPDF(
      DateTime inicio, DateTime fim,
      [String? empresa]) async {
    final pdfDoc = pw.Document();
    final robotoFont = await _loadRobotoFont();

    // Filtrar produções do período personalizado
    final producoesPeriodo = _producoes
        .where((p) =>
            p.dataProducao.isAfter(inicio.subtract(const Duration(days: 1))) &&
            p.dataProducao.isBefore(fim.add(const Duration(days: 1))))
        .toList();

    // Construir os dados da tabela
    final List<List<dynamic>> tableData = [];

    for (final producao in producoesPeriodo) {
      final formula = getFormulaPorId(producao.formulaId);

      // Adicionar linha da produção (centralizando o nome da fórmula)
      tableData.add([
        pw.Center(
            child: pw.Text(formula?.nome ?? 'Desconhecida')), // Centralizado
        producao.loteProducao,
        '${producao.quantidadeProduzida.toStringAsFixed(2)} btd',
      ]);

      // Adicionar linhas das matérias-primas utilizadas
      if (formula != null && formula.componentes.isNotEmpty) {
        for (final componente in formula.componentes) {
          final materiaPrima = getMateriaPrimaPorId(componente.materiaPrimaId);
          tableData.add([
            materiaPrima?.nome ?? 'Desconhecida', // Nome da matéria-prima
            componente.materiaPrimaId,
            '${componente.quantidade.toStringAsFixed(2)} ${componente.unidadeMedida}',
          ]);
        }
      }

      // Adicionar uma linha em branco após cada produção
      tableData.add(['', '', '']);
    }

    pdfDoc.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Título do relatório
            pw.Text(
              'Relatório Personalizado - ${DateFormat('dd/MM/yyyy').format(inicio)} a ${DateFormat('dd/MM/yyyy').format(fim)}',
              style: pw.TextStyle(
                fontSize: 20,
                font: robotoFont,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (empresa != null)
              pw.Text(
                'Empresa: $empresa',
                style: pw.TextStyle(font: robotoFont),
              ),
            pw.SizedBox(height: 20),

            // Tabela Única
            if (tableData.isEmpty)
              pw.Text(
                'Nenhuma produção registrada neste período.',
                style: pw.TextStyle(font: robotoFont),
              )
            else
              pw.Table.fromTextArray(
                headers: ['Fórmula', 'Lote', 'Quantidade'],
                cellStyle: pw.TextStyle(font: robotoFont),
                headerStyle: pw.TextStyle(
                  font: robotoFont,
                  fontWeight: pw.FontWeight.bold,
                ),
                data: tableData,
              ),
          ],
        ),
      ),
    );

    return await pdfDoc.save();
  }

  Future<Uint8List> gerarRelatorioEstoquePDF() async {
    final pdfDoc = pw.Document();
    final robotoFont = await _loadRobotoFont();
    final materiasOrdenadas = List<MateriaPrima>.from(_materiasPrimas)
      ..sort((a, b) => a.estoqueAtual.compareTo(b.estoqueAtual));

    pdfDoc.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Relatório de Estoque - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
              style: pw.TextStyle(
                fontSize: 20,
                font: robotoFont,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),
            if (materiasOrdenadas.isEmpty)
              pw.Text(
                'Nenhuma matéria-prima cadastrada.',
                style: pw.TextStyle(font: robotoFont),
              )
            else
              pw.Table.fromTextArray(
                headers: ['Matéria-Prima', 'Estoque Atual', 'Unidade'],
                cellStyle: pw.TextStyle(font: robotoFont),
                headerStyle: pw.TextStyle(
                  font: robotoFont,
                  fontWeight: pw.FontWeight.bold,
                ),
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

    return await pdfDoc.save();
  }

  Future<void> visualizarPDF(Uint8List pdfBytes) async {
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    await Future.delayed(const Duration(milliseconds: 100));
    html.Url.revokeObjectUrl(url);
  }

  Future<void> compartilharPDF(Uint8List pdfBytes) async {
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'relatorio.pdf')
      ..click();
    await Future.delayed(const Duration(milliseconds: 100));
    html.Url.revokeObjectUrl(url);
  }
}
