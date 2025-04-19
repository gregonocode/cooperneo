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
import '../models/lote.dart'; // Importação adicionada
import '../services/supabase_service.dart';
import 'package:pdf/pdf.dart';

class RelatoriosViewModel extends ChangeNotifier {
  final SupabaseService _supabaseService;

  List<MateriaPrima> _materiasPrimas = [];
  List<Formula> _formulas = [];
  List<Producao> _producoes = [];
  List<Lote> _lotes = []; // Lista de lotes adicionada

  bool _isLoading = false;
  String? _errorMessage;

  List<MateriaPrima> get materiasPrimas => _materiasPrimas;
  List<Formula> get formulas => _formulas;
  List<Producao> get producoes => _producoes;
  List<Lote> get lotes => _lotes; // Getter para lotes
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
      _lotes = await _supabaseService.fetchLotes(); // Carrega os lotes
      print('Lotes carregados: $_lotes'); // Para depuração
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

  // Função ajustada para buscar o numero_lote com base no materia_prima_id
  String getNumeroLoteParaMateriaPrima(
      String materiaPrimaId, Producao producao) {
    // Busca um lote que corresponda à matéria-prima
    final lote = _lotes.firstWhereOrNull(
      (lote) => lote.materiaPrimaId == materiaPrimaId,
    );

    // Se encontrar um lote, retorna o numero_lote; caso contrário, usa o loteProducao como fallback
    return lote?.numeroLote ?? producao.loteProducao;
  }

  Future<pw.Font> _loadRobotoFont() async {
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    return pw.Font.ttf(fontData);
  }

  Future<Uint8List> gerarRelatorioDiarioPDF(DateTime data) async {
    final pdfDoc = pw.Document();
    final robotoFont = await _loadRobotoFont();

    final producoesDoDia = _producoes
        .where((p) =>
            p.dataProducao.year == data.year &&
            p.dataProducao.month == data.month &&
            p.dataProducao.day == data.day)
        .toList();

    final List<pw.TableRow> tableRows = [];

    for (final producao in producoesDoDia) {
      final formula = getFormulaPorId(producao.formulaId);

      tableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
          ),
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              alignment: pw.Alignment.center,
              child: pw.Text(
                formula?.nome ?? 'Desconhecida',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  font: robotoFont,
                ),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              alignment: pw.Alignment.center,
              child: pw.Text(
                producao.loteProducao,
                style: pw.TextStyle(font: robotoFont),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '${producao.quantidadeProduzida.toStringAsFixed(2)} btd',
                style: pw.TextStyle(font: robotoFont),
              ),
            ),
          ],
        ),
      );

      if (formula != null && formula.componentes.isNotEmpty) {
        for (final componente in formula.componentes) {
          final materiaPrima = getMateriaPrimaPorId(componente.materiaPrimaId);
          tableRows.add(
            pw.TableRow(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    '  ${materiaPrima?.nome ?? 'Desconhecida'}',
                    style: pw.TextStyle(font: robotoFont),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    getNumeroLoteParaMateriaPrima(
                        componente.materiaPrimaId, producao),
                    style: pw.TextStyle(font: robotoFont),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    '${componente.quantidade.toStringAsFixed(2)} ${componente.unidadeMedida}',
                    style: pw.TextStyle(font: robotoFont),
                  ),
                ),
              ],
            ),
          );
        }
      }

      tableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.white),
          children: [
            pw.SizedBox(height: 10),
            pw.SizedBox(),
            pw.SizedBox(),
          ],
        ),
      );
    }

    pdfDoc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(base: robotoFont),
        ),
        header: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Controle de Produção Diário-Mistura/Ensaque',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    font: robotoFont,
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'N° Documento: BPF 18',
                        style: pw.TextStyle(
                          fontSize: 12,
                          font: robotoFont,
                        ),
                      ),
                    ),
                    pw.Text(
                      'Data: ${DateFormat('dd/MM/yyyy').format(data)}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        font: robotoFont,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border:
                    pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Relatório Diário de Produção',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Página ${context.pageNumber} de ${context.pagesCount}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
          ],
        ),
        footer: (pw.Context context) => pw.Column(
          children: [
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.5,
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.amber100,
                  ),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Execução',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Monitoramento',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Verificação',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Responsável: Helves Presllei',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Responsável: Pedro Luiz',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Responsável: Franciele Aparecida',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Data:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Data:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Data:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Assinatura:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Assinatura:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Assinatura:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                  ],
                ),
              ],
              columnWidths: {
                0: pw.FlexColumnWidth(1),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1),
              },
            ),
          ],
        ),
        build: (pw.Context context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'Data: ${DateFormat('dd/MM/yyyy').format(data)}',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          if (tableRows.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.red100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'Nenhuma produção registrada neste dia.',
                style: pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.red800,
                ),
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.5,
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.amber100,
                  ),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Fórmula / Matéria-Prima',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Lote',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Quantidade',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                ...tableRows,
              ],
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(2),
              },
            ),
        ],
      ),
    );

    return await pdfDoc.save();
  }

  Future<Uint8List> gerarRelatorioSemanalPDF(DateTime data) async {
    final pdfDoc = pw.Document();
    final robotoFont = await _loadRobotoFont();

    final inicioSemana = data.subtract(Duration(days: data.weekday - 1));
    final fimSemana = inicioSemana.add(const Duration(days: 6));

    final producoesDaSemana = _producoes
        .where((p) =>
            p.dataProducao
                .isAfter(inicioSemana.subtract(const Duration(days: 1))) &&
            p.dataProducao.isBefore(fimSemana.add(const Duration(days: 1))))
        .toList();

    final List<pw.TableRow> tableRows = [];

    for (final producao in producoesDaSemana) {
      final formula = getFormulaPorId(producao.formulaId);

      tableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
          ),
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              alignment: pw.Alignment.center,
              child: pw.Text(
                formula?.nome ?? 'Desconhecida',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  font: robotoFont,
                ),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              alignment: pw.Alignment.center,
              child: pw.Text(
                producao.loteProducao,
                style: pw.TextStyle(font: robotoFont),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '${producao.quantidadeProduzida.toStringAsFixed(2)} btd',
                style: pw.TextStyle(font: robotoFont),
              ),
            ),
          ],
        ),
      );

      if (formula != null && formula.componentes.isNotEmpty) {
        for (final componente in formula.componentes) {
          final materiaPrima = getMateriaPrimaPorId(componente.materiaPrimaId);
          tableRows.add(
            pw.TableRow(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    '  ${materiaPrima?.nome ?? 'Desconhecida'}',
                    style: pw.TextStyle(font: robotoFont),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    getNumeroLoteParaMateriaPrima(
                        componente.materiaPrimaId, producao),
                    style: pw.TextStyle(font: robotoFont),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    '${componente.quantidade.toStringAsFixed(2)} ${componente.unidadeMedida}',
                    style: pw.TextStyle(font: robotoFont),
                  ),
                ),
              ],
            ),
          );
        }
      }
    }

    pdfDoc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(base: robotoFont),
        ),
        header: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Controle de Produção Semanal-Mistura/Ensaque',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    font: robotoFont,
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'N° Documento:BPF 18',
                        style: pw.TextStyle(
                          fontSize: 12,
                          font: robotoFont,
                        ),
                      ),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Data: ${DateFormat('dd/MM/yyyy').format(data)}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          font: robotoFont,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border:
                    pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Relatório Semanal de Produção',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Página ${context.pageNumber} de ${context.pagesCount}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
          ],
        ),
        footer: (pw.Context context) => pw.Column(
          children: [
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.5,
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.amber100,
                  ),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Execução',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Monitoramento',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Verificação',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Responsável: Helves Presllei',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Responsável: Pedro Luiz',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Responsável: Franciele Aparecida',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Data:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Data:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Data:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Assinatura:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Assinatura:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Assinatura:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                  ],
                ),
              ],
              columnWidths: {
                0: pw.FlexColumnWidth(1),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1),
              },
            ),
          ],
        ),
        build: (pw.Context context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'Período: ${DateFormat('dd/MM/yyyy').format(inicioSemana)} a ${DateFormat('dd/MM/yyyy').format(fimSemana)}',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          if (tableRows.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.red100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'Nenhuma produção registrada nesta semana.',
                style: pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.red800,
                ),
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.5,
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.amber100,
                  ),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Fórmula / Matéria-Prima',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Lote',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Quantidade',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                ...tableRows,
              ],
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(2),
              },
            ),
        ],
      ),
    );

    return await pdfDoc.save();
  }

  Future<Uint8List> gerarRelatorioPersonalizadoPDF(
      DateTime inicio, DateTime fim,
      [String? empresa]) async {
    final pdfDoc = pw.Document();
    final robotoFont = await _loadRobotoFont();

    final producoesPeriodo = _producoes
        .where((p) =>
            p.dataProducao.isAfter(inicio.subtract(const Duration(days: 1))) &&
            p.dataProducao.isBefore(fim.add(const Duration(days: 1))))
        .toList();

    final List<pw.TableRow> tableRows = [];

    for (final producao in producoesPeriodo) {
      final formula = getFormulaPorId(producao.formulaId);

      tableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
          ),
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              alignment: pw.Alignment.center,
              child: pw.Text(
                formula?.nome ?? 'Desconhecida',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  font: robotoFont,
                ),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              alignment: pw.Alignment.center,
              child: pw.Text(
                producao.loteProducao,
                style: pw.TextStyle(font: robotoFont),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '${producao.quantidadeProduzida.toStringAsFixed(2)} btd',
                style: pw.TextStyle(font: robotoFont),
              ),
            ),
          ],
        ),
      );

      if (formula != null && formula.componentes.isNotEmpty) {
        for (final componente in formula.componentes) {
          final materiaPrima = getMateriaPrimaPorId(componente.materiaPrimaId);
          tableRows.add(
            pw.TableRow(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    '  ${materiaPrima?.nome ?? 'Desconhecida'}',
                    style: pw.TextStyle(font: robotoFont),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    getNumeroLoteParaMateriaPrima(
                        componente.materiaPrimaId, producao),
                    style: pw.TextStyle(font: robotoFont),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    '${componente.quantidade.toStringAsFixed(2)} ${componente.unidadeMedida}',
                    style: pw.TextStyle(font: robotoFont),
                  ),
                ),
              ],
            ),
          );
        }
      }
    }

    pdfDoc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(base: robotoFont),
        ),
        header: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Controle de Produção Mistura/Ensaque',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    font: robotoFont,
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'N° Documento:BPF 18',
                        style: pw.TextStyle(
                          fontSize: 12,
                          font: robotoFont,
                        ),
                      ),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Data: ${DateFormat('dd/MM/yyyy').format(inicio)}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          font: robotoFont,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border:
                    pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Relatório Personalizado de Produção',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Página ${context.pageNumber} de ${context.pagesCount}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
          ],
        ),
        footer: (pw.Context context) => pw.Column(
          children: [
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.5,
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.amber100,
                  ),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Execução',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Monitoramento',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Verificação',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Responsável: Helves Presllei',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Responsável: Pedro Luiz',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Responsável: Franciele Aparecida',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Data:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Data:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Data:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Assinatura:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Assinatura:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'Assinatura:',
                        style: pw.TextStyle(fontSize: 10, font: robotoFont),
                      ),
                    ),
                  ],
                ),
              ],
              columnWidths: {
                0: pw.FlexColumnWidth(1),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1),
              },
            ),
          ],
        ),
        build: (pw.Context context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'Período: ${DateFormat('dd/MM/yyyy').format(inicio)} a ${DateFormat('dd/MM/yyyy').format(fim)}',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          if (tableRows.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.red100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'Nenhuma produção registrada neste período.',
                style: pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.red800,
                ),
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.5,
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.amber100,
                  ),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Fórmula / Matéria-Prima',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Lote',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'Quantidade',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                ...tableRows,
              ],
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(2),
              },
            ),
        ],
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
