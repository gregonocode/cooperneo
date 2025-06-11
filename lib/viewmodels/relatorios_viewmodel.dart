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

/// Classe para controlar consumo de lotes de forma mutável
class _LoteConsumicao {
  final String numeroLote;
  double quantidadeAtual;
  final DateTime dataRecebimento;

  _LoteConsumicao(Lote lote)
      : numeroLote = lote.numeroLote,
        quantidadeAtual = lote.quantidadeAtual,
        dataRecebimento = lote.dataRecebimento;
}

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

  /// Método que, dado o mapa de lotes por matéria-prima e a quantidade a consumir,
  /// faz o consumo FIFO (do lote mais antigo para o mais novo) e retorna
  /// uma string com os números de lote usados, separados por "/".
  String _consumirLotes(
    String materiaPrimaId,
    double quantidadeNecessaria,
    Map<String, List<_LoteConsumicao>> lotesPorMP,
  ) {
    final lotesDaMP = lotesPorMP[materiaPrimaId] ?? [];
    final usados = <String>[];
    var restante = quantidadeNecessaria;

    for (var lote in lotesDaMP) {
      if (lote.quantidadeAtual <= 0) continue;

      if (lote.quantidadeAtual >= restante) {
        // Este lote supre toda a quantidade restante
        lote.quantidadeAtual -= restante;
        usados.add(lote.numeroLote);
        restante = 0;
        break;
      } else {
        // Lote não é suficiente: usa todo o restante dele e segue para o próximo lote
        restante -= lote.quantidadeAtual;
        usados.add(lote.numeroLote);
        lote.quantidadeAtual = 0;
      }
    }

    // Se após consumir todos os lotes disponíveis ainda houver restante,
    // podemos simplesmente exibir os que já foram usados; em sistemas reais,
    // talvez queiramos registrar "Falta X" ou algo similar. Aqui, apenas retornamos.
    return usados.join('/');
  }

  // Função para carregar as fontes Roboto
  Future<Map<String, pw.Font>> _loadRobotoFonts() async {
    final robotoRegular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final robotoBold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    return {
      'regular': robotoRegular,
      'bold': robotoBold,
    };
  }

  Future<Uint8List> gerarRelatorioDiarioPDF(DateTime data) async {
    final pdfDoc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    // Carregar fontes com validação
    Map<String, pw.Font> fonts;
    try {
      fonts = await _loadRobotoFonts();
      print('Fontes Roboto carregadas com sucesso: ${fonts.keys}');
    } catch (e) {
      print('Erro ao carregar fontes Roboto: $e');
      fonts = {
        'regular': pw.Font.helvetica(),
        'bold': pw.Font.helveticaBold(),
      };
    }
    final robotoFont = fonts['regular']!;
    final robotoFontBold = fonts['bold']!;

    // Filtrar produções do dia especificado
    final producoesDoDia = _producoes
        .where((p) =>
            p.dataProducao.year == data.year &&
            p.dataProducao.month == data.month &&
            p.dataProducao.day == data.day)
        .toList();

    // Ordenar produções por horário (ascendente)
    producoesDoDia.sort((a, b) => a.dataProducao.compareTo(b.dataProducao));

    // Criar mapa temporário de lotes por matéria-prima com consumo FIFO
    final lotesPorMP = <String, List<_LoteConsumicao>>{};
    for (var lote in _lotes) {
      lotesPorMP.putIfAbsent(lote.materiaPrimaId, () => []);
      lotesPorMP[lote.materiaPrimaId]!.add(_LoteConsumicao(lote));
    }
    // Ordenar cada lista de lotes por data_recebimento (mais antigo primeiro)
    for (var entrada in lotesPorMP.entries) {
      entrada.value
          .sort((a, b) => a.dataRecebimento.compareTo(b.dataRecebimento));
    }

    // Estimar número total de linhas (produções + matérias-primas)
    int totalLinhas = producoesDoDia.length;
    for (final producao in producoesDoDia) {
      totalLinhas += producao.materiaPrimaConsumida.length;
    }

    // Limitar número de linhas para evitar excesso de páginas
    if (totalLinhas > 1000) {
      throw Exception(
          'Dia selecionado contém muitas entradas ($totalLinhas linhas, incluindo ${producoesDoDia.length} produções). Por favor, selecione um dia com menos produções ou contate o suporte.');
    }

    final List<pw.Widget> productionBlocks = [];

    for (final producao in producoesDoDia) {
      final formula = getFormulaPorId(producao.formulaId);
      final List<pw.TableRow> rows = [];

      // Linha da fórmula
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
          ),
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              alignment: pw.Alignment.center,
              child: pw.Text(
                formula?.nome ?? 'Desconhecida',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  font: robotoFontBold,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              alignment: pw.Alignment.center,
              child: pw.Text(
                producao.loteProducao,
                style: pw.TextStyle(
                  font: robotoFontBold,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '${producao.quantidadeProduzida.toStringAsFixed(2)} btd',
                style: pw.TextStyle(
                  font: robotoFontBold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      );

      // Linhas das matérias-primas consumidas (com lógica FIFO)
      if (producao.materiaPrimaConsumida.isNotEmpty) {
        for (final entry in producao.materiaPrimaConsumida.entries) {
          final materiaPrima = getMateriaPrimaPorId(entry.key);
          final quantidadeNecessaria = entry.value;
          final loteString = _consumirLotes(
            entry.key,
            quantidadeNecessaria,
            lotesPorMP,
          );

          rows.add(
            pw.TableRow(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    '  ${materiaPrima?.nome ?? 'Desconhecida'}',
                    style: pw.TextStyle(
                      font: robotoFont,
                      fontSize: 9,
                    ),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    loteString,
                    style: pw.TextStyle(
                      font: robotoFont,
                      fontSize: 9,
                    ),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    '${quantidadeNecessaria.toStringAsFixed(2)} ${materiaPrima?.unidadeMedida ?? ''}',
                    style: pw.TextStyle(
                      font: robotoFont,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }

      // Adiciona a tabela da produção
      productionBlocks.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.5,
              ),
              children: rows,
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(2),
              },
            ),
            pw.SizedBox(height: 5),
          ],
        ),
      );
    }

    try {
      pdfDoc.addPage(
        pw.MultiPage(
          maxPages: 100,
          pageTheme: pw.PageTheme(
            margin: pw.EdgeInsets.all(20),
            theme: pw.ThemeData.withFont(
              base: robotoFont,
              bold: robotoFontBold,
            ),
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
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        alignment: pw.Alignment.centerLeft,
                        child: pw.RichText(
                          text: pw.TextSpan(
                            text: 'N° Documento: ',
                            style: pw.TextStyle(
                              fontSize: 12,
                              font: robotoFont,
                            ),
                            children: [
                              pw.TextSpan(
                                text: 'BPF 18',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  font: robotoFontBold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.Text(
                        'Data: Data: 03/02/2025',
                        style: pw.TextStyle(
                          fontSize: 12,
                          font: robotoFont,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 6),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Página ${context.pageNumber} de ${context.pagesCount}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                        font: robotoFont,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          footer: (pw.Context context) => pw.Column(
            children: [
              pw.SizedBox(height: 10),
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
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'Execução',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                            font: robotoFontBold,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'Monitoramento',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                            font: robotoFontBold,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'Verificação',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                            font: robotoFontBold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Responsável: Helves P. Santos',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Responsável: Pedro Luiz Ferreira',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Responsável: Franciele A. Santos',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Data:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Data:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Data:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Assinatura:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Assinatura:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Assinatura:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
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
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'Data: ${DateFormat('dd/MM/yyyy').format(data)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                  font: robotoFont,
                ),
              ),
            ),
            pw.SizedBox(height: 15),
            if (productionBlocks.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'Nenhuma produção registrada neste dia.',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.red800,
                    font: robotoFont,
                  ),
                ),
              )
            else
              pw.Column(
                children: [
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
                            padding: const pw.EdgeInsets.all(6),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              'Fórmula / Matéria-Prima',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                                font: robotoFontBold,
                              ),
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              'Lote',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                                font: robotoFontBold,
                              ),
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              'Quantidade',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                                font: robotoFontBold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    columnWidths: {
                      0: pw.FlexColumnWidth(3),
                      1: pw.FlexColumnWidth(2),
                      2: pw.FlexColumnWidth(2),
                    },
                  ),
                  ...productionBlocks,
                ],
              ),
          ],
        ),
      );
    } catch (e) {
      throw Exception(
          'Erro ao gerar relatório: Não foi possível gerar o PDF devido ao grande volume de dados ($totalLinhas linhas). Tente um dia com menos produções ou contate o suporte. Detalhes: $e');
    }

    return await pdfDoc.save();
  }

  Future<Uint8List> gerarRelatorioSemanalPDF(DateTime data) async {
    final pdfDoc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    Map<String, pw.Font> fonts;
    try {
      fonts = await _loadRobotoFonts();
    } catch (e) {
      fonts = {
        'regular': pw.Font.helvetica(),
        'bold': pw.Font.helveticaBold(),
      };
    }
    final robotoFont = fonts['regular']!;
    final robotoFontBold = fonts['bold']!;

    final inicioSemana = data.subtract(Duration(days: data.weekday - 1));
    final fimSemana = inicioSemana.add(const Duration(days: 6));

    final producoesDaSemana = _producoes
        .where((p) =>
            !p.dataProducao.isBefore(inicioSemana) &&
            !p.dataProducao.isAfter(fimSemana.add(const Duration(hours: 23))))
        .toList();
    producoesDaSemana.sort((a, b) => a.dataProducao.compareTo(b.dataProducao));

    final lotesPorMP = <String, List<_LoteConsumicao>>{};
    for (var lote in _lotes) {
      lotesPorMP.putIfAbsent(lote.materiaPrimaId, () => []);
      lotesPorMP[lote.materiaPrimaId]!.add(_LoteConsumicao(lote));
    }
    for (var entry in lotesPorMP.entries) {
      entry.value
          .sort((a, b) => a.dataRecebimento.compareTo(b.dataRecebimento));
    }

    int totalLinhas = producoesDaSemana.length;
    for (var p in producoesDaSemana)
      totalLinhas += p.materiaPrimaConsumida.length;
    if (totalLinhas > 1000)
      throw Exception('Semana contém muitas entradas ($totalLinhas linhas).');

    final productionBlocks = <pw.Widget>[];
    for (var prod in producoesDaSemana) {
      final formula = getFormulaPorId(prod.formulaId);
      final rows = <pw.TableRow>[];
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Container(
                padding: const pw.EdgeInsets.all(6),
                alignment: pw.Alignment.center,
                child: pw.Text(formula?.nome ?? 'Desconhecida',
                    style: pw.TextStyle(font: robotoFontBold, fontSize: 10))),
            pw.Container(
                padding: const pw.EdgeInsets.all(6),
                alignment: pw.Alignment.center,
                child: pw.Text(prod.loteProducao,
                    style: pw.TextStyle(font: robotoFontBold, fontSize: 10))),
            pw.Container(
                padding: const pw.EdgeInsets.all(6),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                    '${prod.quantidadeProduzida.toStringAsFixed(2)} btd',
                    style: pw.TextStyle(font: robotoFontBold, fontSize: 10))),
          ],
        ),
      );
      for (var e in prod.materiaPrimaConsumida.entries) {
        final mp = getMateriaPrimaPorId(e.key);
        final quantidade = e.value;
        final loteStr = _consumirLotes(e.key, quantidade, lotesPorMP);
        rows.add(
          pw.TableRow(
            children: [
              pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('  ${mp?.nome ?? 'Desconhecida'}',
                      style: pw.TextStyle(font: robotoFont, fontSize: 9))),
              pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  alignment: pw.Alignment.center,
                  child: pw.Text(loteStr,
                      style: pw.TextStyle(font: robotoFont, fontSize: 9))),
              pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                      '${quantidade.toStringAsFixed(2)} ${mp?.unidadeMedida ?? ''}',
                      style: pw.TextStyle(font: robotoFont, fontSize: 9))),
            ],
          ),
        );
      }
      // Adiciona a linha de Quantidade de Ensaque
      rows.add(
        pw.TableRow(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'Quantidade de ensaque: ',
                style: pw.TextStyle(font: robotoFontBold, fontSize: 10),
              ),
            ),
            pw.Container(), // Célula vazia para manter a estrutura da tabela
            pw.Container(), // Célula vazia para manter a estrutura da tabela
          ],
        ),
      );
      productionBlocks.add(
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            children: rows,
            columnWidths: {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2)
            },
          ),
          pw.SizedBox(height: 5),
        ]),
      );
    }

    pdfDoc.addPage(
      pw.MultiPage(
        maxPages: 100,
        pageTheme: pw.PageTheme(
          margin: pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(base: robotoFont, bold: robotoFontBold),
        ),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Controle de Produção Semanal-Mistura/Ensaque',
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        font: robotoFont)),
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.RichText(
                          text: pw.TextSpan(
                              text: 'N° Documentário: ',
                              style:
                                  pw.TextStyle(font: robotoFont, fontSize: 12),
                              children: [
                            pw.TextSpan(
                                text: 'BPF 18',
                                style: pw.TextStyle(
                                    font: robotoFontBold, fontSize: 12))
                          ])),
                      pw.Text('Data: 03/02/2025',
                          style: pw.TextStyle(font: robotoFont, fontSize: 12)),
                    ]),
              ],
            ),
            pw.SizedBox(height: 10),
            // Período
            pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Text(
                    'Período: ${DateFormat('dd/MM/yyyy').format(inicioSemana)} - ${DateFormat('dd/MM/yyyy').format(fimSemana)}',
                    style: pw.TextStyle(
                        font: robotoFont,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10))),
            pw.SizedBox(height: 10),
            // Paginação
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 6),
              decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300))),
              child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                        style: pw.TextStyle(
                            font: robotoFont,
                            fontSize: 8,
                            color: PdfColors.grey600)),
                  ]),
            ),
            // Linha amarela de cabeçalho da tabela
            pw.SizedBox(height: 5),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.amber100),
                  children: [
                    pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.center,
                        child: pw.Text('Fórmula / Matéria-Prima',
                            style: pw.TextStyle(
                                font: robotoFontBold, fontSize: 10))),
                    pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.center,
                        child: pw.Text('Lote',
                            style: pw.TextStyle(
                                font: robotoFontBold, fontSize: 10))),
                    pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.center,
                        child: pw.Text('Quantidade',
                            style: pw.TextStyle(
                                font: robotoFontBold, fontSize: 10))),
                  ],
                ),
              ],
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(2)
              },
            ),
            pw.SizedBox(height: 5),
          ],
        ),
        footer: (ctx) => pw.Column(children: [
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            children: [
              pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.amber100),
                  children: [
                    pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.center,
                        child: pw.Text('Execução',
                            style: pw.TextStyle(
                                font: robotoFontBold, fontSize: 10))),
                    pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.center,
                        child: pw.Text('Monitoramento',
                            style: pw.TextStyle(
                                font: robotoFontBold, fontSize: 10))),
                    pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.center,
                        child: pw.Text('Verificação',
                            style: pw.TextStyle(
                                font: robotoFontBold, fontSize: 10))),
                  ]),
              pw.TableRow(children: [
                pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('Responsável: Helves P. Santos',
                        style: pw.TextStyle(font: robotoFont, fontSize: 8))),
                pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('Responsável: Pedro Luiz Ferreira',
                        style: pw.TextStyle(font: robotoFont, fontSize: 8))),
                pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('Responsável: Franciele A. Santos',
                        style: pw.TextStyle(font: robotoFont, fontSize: 8))),
              ]),
              pw.TableRow(children: [
                pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('Data:',
                        style: pw.TextStyle(font: robotoFont, fontSize: 8))),
                pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('Data:',
                        style: pw.TextStyle(font: robotoFont, fontSize: 8))),
                pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('Data:',
                        style: pw.TextStyle(font: robotoFont, fontSize: 8))),
              ]),
              pw.TableRow(children: [
                pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('Assinatura:',
                        style: pw.TextStyle(font: robotoFont, fontSize: 8))),
                pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('Assinatura:',
                        style: pw.TextStyle(font: robotoFont, fontSize: 8))),
                pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text('Assinatura:',
                        style: pw.TextStyle(font: robotoFont, fontSize: 8))),
              ]),
            ],
            columnWidths: {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1)
            },
          ),
        ]),
        build: (ctx) => [
          if (productionBlocks.isEmpty)
            pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                    color: PdfColors.red100,
                    borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Text('Nenhuma produção registrada nesta semana.',
                    style: pw.TextStyle(
                        font: robotoFont,
                        fontSize: 12,
                        color: PdfColors.red800)))
          else
            pw.Column(children: productionBlocks)
        ],
      ),
    );

    return await pdfDoc.save();
  }

  Future<Uint8List> gerarRelatorioPersonalizadoPDF(
      DateTime dataInicio, DateTime dataFim) async {
    final pdfDoc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(), // Fallback inicial
        bold: pw.Font.helveticaBold(),
      ),
    );

    // Carregar fontes com validação
    Map<String, pw.Font> fonts;
    try {
      fonts = await _loadRobotoFonts();
    } catch (e) {
      print('Erro ao carregar fontes Roboto: $e');
      fonts = {
        'regular': pw.Font.helvetica(),
        'bold': pw.Font.helveticaBold(),
      };
    }
    final robotoFont = fonts['regular']!;
    final robotoFontBold = fonts['bold']!;

    final producoesPeriodo = _producoes
        .where((p) =>
            !p.dataProducao.isBefore(dataInicio) &&
            p.dataProducao.isBefore(dataFim.add(const Duration(days: 1))))
        .toList();

    // Ordenar produções por data (ascendente)
    producoesPeriodo.sort((a, b) => a.dataProducao.compareTo(b.dataProducao));

    // Limitar o número de produções para evitar excesso de páginas
    if (producoesPeriodo.length > 100) {
      throw Exception(
          'Período selecionado contém muitas produções (${producoesPeriodo.length}). Por favor, reduza o intervalo de datas.');
    }

    // Criar mapa temporário de lotes por matéria-prima com consumo FIFO
    final lotesPorMP = <String, List<_LoteConsumicao>>{};
    for (var lote in _lotes) {
      lotesPorMP.putIfAbsent(lote.materiaPrimaId, () => []);
      lotesPorMP[lote.materiaPrimaId]!.add(_LoteConsumicao(lote));
    }
    // Ordenar cada lista de lotes por data_recebimento (mais antigo primeiro)
    for (var entrada in lotesPorMP.entries) {
      entrada.value
          .sort((a, b) => a.dataRecebimento.compareTo(b.dataRecebimento));
    }

    final List<pw.Widget> productionBlocks = [];

    for (final producao in producoesPeriodo) {
      final formula = getFormulaPorId(producao.formulaId);
      final List<pw.TableRow> rows = [];

      // Linha da fórmula
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
          ),
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              alignment: pw.Alignment.center,
              child: pw.Text(
                formula?.nome ?? 'Desconhecida',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  font: robotoFontBold,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              alignment: pw.Alignment.center,
              child: pw.Text(
                producao.loteProducao,
                style: pw.TextStyle(
                  font: robotoFontBold,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '${producao.quantidadeProduzida.toStringAsFixed(2)} btd',
                style: pw.TextStyle(
                  font: robotoFontBold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      );

      // Linhas das matérias-primas consumidas (com lógica FIFO)
      if (producao.materiaPrimaConsumida.isNotEmpty) {
        for (final entry in producao.materiaPrimaConsumida.entries) {
          final materiaPrima = getMateriaPrimaPorId(entry.key);
          final quantidadeNecessaria = entry.value;
          final loteString = _consumirLotes(
            entry.key,
            quantidadeNecessaria,
            lotesPorMP,
          );

          rows.add(
            pw.TableRow(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    '  ${materiaPrima?.nome ?? 'Desconhecida'}',
                    style: pw.TextStyle(
                      font: robotoFont,
                      fontSize: 9,
                    ),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    loteString,
                    style: pw.TextStyle(
                      font: robotoFont,
                      fontSize: 9,
                    ),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    '${quantidadeNecessaria.toStringAsFixed(2)} ${materiaPrima?.unidadeMedida ?? ''}',
                    style: pw.TextStyle(
                      font: robotoFont,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }

      // Adiciona a tabela da produção
      productionBlocks.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.5,
              ),
              children: rows,
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(2),
              },
            ),
            pw.SizedBox(height: 5),
          ],
        ),
      );
    }

    try {
      pdfDoc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: pw.EdgeInsets.all(20),
            theme: pw.ThemeData.withFont(
              base: robotoFont,
              bold: robotoFontBold,
            ),
          ),
          header: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Controle de Produção Personalizado-Mistura/Ensaque',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      font: robotoFont,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        alignment: pw.Alignment.centerLeft,
                        child: pw.RichText(
                          text: pw.TextSpan(
                            text: 'N° Documento: ',
                            style: pw.TextStyle(
                              fontSize: 12,
                              font: robotoFont,
                            ),
                            children: [
                              pw.TextSpan(
                                text: 'BPF 18',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  font: robotoFontBold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.Text(
                        'Data: Data: 03/02/2025',
                        style: pw.TextStyle(
                          fontSize: 12,
                          font: robotoFont,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 6),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Página ${context.pageNumber} de ${context.pagesCount}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                        font: robotoFont,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          footer: (pw.Context context) => pw.Column(
            children: [
              pw.SizedBox(height: 10),
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
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'Execução',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                            font: robotoFontBold,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'Monitoramento',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                            font: robotoFontBold,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          'Verificação',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                            font: robotoFontBold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Responsável: Helves P. Santos',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Responsável: Pedro Luiz Ferreira',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Responsável: Franciele A. Santos',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Data:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Data:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Data:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Assinatura:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Assinatura:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          'Assinatura:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            font: robotoFont,
                          ),
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
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'Período: ${DateFormat('dd/MM/yyyy').format(dataInicio)} - ${DateFormat('dd/MM/yyyy').format(dataFim)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                  font: robotoFont,
                ),
              ),
            ),
            pw.SizedBox(height: 15),
            if (productionBlocks.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'Nenhuma produção registrada neste período.',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.red800,
                    font: robotoFont,
                  ),
                ),
              )
            else
              pw.Column(
                children: [
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
                            padding: const pw.EdgeInsets.all(6),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              'Fórmula / Matéria-Prima',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                                font: robotoFontBold,
                              ),
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              'Lote',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                                font: robotoFontBold,
                              ),
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              'Quantidade',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                                font: robotoFontBold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    columnWidths: {
                      0: pw.FlexColumnWidth(3),
                      1: pw.FlexColumnWidth(2),
                      2: pw.FlexColumnWidth(2),
                    },
                  ),
                  ...productionBlocks,
                ],
              ),
          ],
        ),
      );
    } catch (e) {
      throw Exception(
          'Erro ao gerar relatório: Número excessivo de páginas ou de dados. Tente um período menor ou contate o suporte. Detalhes: $e');
    }

    return await pdfDoc.save();
  }

  Future<Uint8List> gerarRelatorioEstoquePDF() async {
    final pdfDoc = pw.Document();
    final fonts = await _loadRobotoFonts(); // Carrega o mapa de fontes
    final robotoFont = fonts['regular']!; // Fonte regular
    final robotoFontBold = fonts['bold']!; // Fonte bold

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
                font: robotoFontBold, // Usa fonte bold para o título
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
                  font: robotoFontBold,
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
