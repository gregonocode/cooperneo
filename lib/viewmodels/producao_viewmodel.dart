import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import '../models/materia_prima.dart';
import '../models/formula.dart';
import '../models/producao.dart';
import '../models/componente_formula.dart';
import '../services/supabase_service.dart';

// usa o LoteVM e a enum LoteStrategy que você colocou em lib/models/lote_vm.dart
import '../models/lote_vm.dart';

class ProducaoViewModel extends ChangeNotifier {
  final SupabaseService _supabaseService;

  // ---------- Estado ----------
  List<MateriaPrima> _materiasPrimas = [];
  List<Formula> _formulas = [];
  List<Producao> _producoes = [];

  bool _isLoading = false;
  String? _errorMessage;

  // Estratégia atual (altere aqui se quiser LIFO/FEFO)
  final LoteStrategy _loteStrategy = LoteStrategy.fifo;

  // ---------- Getters ----------
  List<MateriaPrima> get materiasPrimas => _materiasPrimas;
  List<Formula> get formulas => _formulas;
  List<Producao> get producoes => _producoes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ProducaoViewModel({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService() {
    carregarDados();
  }

  Future<void> carregarDados() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Fórmulas
      _formulas = await _supabaseService.fetchFormulas();

      // Produções (não falha o fluxo se der erro)
      try {
        _producoes = await _supabaseService.getProducoes();
      } catch (e) {
        _errorMessage = 'Erro ao carregar produções: $e';
      }

      // Matérias-primas
      _materiasPrimas = await _supabaseService.fetchMateriasPrimas();

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Erro ao carregar dados: $e';
      notifyListeners();
    }
  }

  List<Producao> getProducoesRecentes({required int limite}) {
    final producoesOrdenadas = List<Producao>.from(_producoes)
      ..sort((a, b) => b.dataProducao.compareTo(a.dataProducao));
    return producoesOrdenadas.take(limite).toList();
  }

  Formula? getFormulaPorId(String id) {
    return _formulas.firstWhereOrNull((formula) => formula.id == id);
  }

  MateriaPrima? getMateriaPrimaPorId(String id) {
    return _materiasPrimas.firstWhereOrNull((mp) => mp.id == id);
  }

  // ---------- Simulação de disponibilidade no modal ----------
  Map<String, double> verificarDisponibilidadeProducao(
      String formulaId, double quantidadeProduzida) {
    final formula = getFormulaPorId(formulaId);
    if (formula == null) return {};

    final Map<String, double> disponibilidade = {};

    for (final componente in formula.componentes) {
      final materiaPrima = getMateriaPrimaPorId(componente.materiaPrimaId);
      if (materiaPrima == null) continue;

      double quantidadeNecessaria = componente.quantidade * quantidadeProduzida;

      // Conversões usuais
      if (componente.unidadeMedida == 'g' &&
          materiaPrima.unidadeMedida == 'kg') {
        quantidadeNecessaria /= 1000;
      } else if (componente.unidadeMedida == 'kg' &&
          materiaPrima.unidadeMedida == 'g') {
        quantidadeNecessaria *= 1000;
      } else if (componente.unidadeMedida == 'mL' &&
          materiaPrima.unidadeMedida == 'L') {
        quantidadeNecessaria /= 1000;
      } else if (componente.unidadeMedida == 'L' &&
          materiaPrima.unidadeMedida == 'mL') {
        quantidadeNecessaria *= 1000;
      }

      final double saldo = materiaPrima.estoqueAtual - quantidadeNecessaria;
      disponibilidade[materiaPrima.nome] = saldo;
    }

    return disponibilidade;
  }

  // ---------- CRUD de Fórmulas ----------
  Future<bool> adicionarFormula({
    required String nome,
    required List<ComponenteFormula> componentes,
  }) async {
    try {
      final success = await _supabaseService.addFormula({
        'nome': nome,
        'componentes': componentes.map((c) => c.toJson()).toList(),
      });
      if (success) {
        await carregarDados();
        return true;
      } else {
        _errorMessage = 'Falha ao adicionar fórmula no Supabase';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Erro ao adicionar fórmula: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> atualizarFormula({
    required String id,
    required String nome,
    String? descricao,
    required List<ComponenteFormula> componentes,
  }) async {
    try {
      final success = await _supabaseService.updateFormula(id, {
        'nome': nome,
        if (descricao != null) 'descricao': descricao,
        'componentes': componentes.map((c) => c.toJson()).toList(),
      });
      if (success) {
        await carregarDados();
        return true;
      } else {
        _errorMessage = 'Falha ao atualizar fórmula no Supabase';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Erro ao atualizar fórmula: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> excluirFormula(String id) async {
    try {
      final success = await _supabaseService.deleteFormula(int.parse(id));
      if (success) {
        await carregarDados();
        return true;
      }
      _errorMessage = 'Erro ao excluir fórmula';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao excluir fórmula: $e';
      notifyListeners();
      return false;
    }
  }

  // ============================================================
  //                       LÓGICA DE LOTES
  // ============================================================

  /// Busca lotes de uma MP diretamente do serviço e mapeia para LoteVM (sem nulos).
  Future<List<LoteVM>> _fetchLotesDaMP(String materiaPrimaId) async {
    final rows =
        await _supabaseService.fetchLotesByMateriaPrima(materiaPrimaId);

    return rows.map<LoteVM>((raw) {
      final id = (raw['id'] ?? '').toString();
      final mpId = (raw['materia_prima_id'] ?? '').toString();
      final numero = (raw['numero_lote'] ?? '').toString();

      final drStr = (raw['data_recebimento'] ?? '').toString();
      final dataRec = DateTime.tryParse(drStr) ?? DateTime(1970, 1, 1);

      final dvStr = raw['data_validade']?.toString();
      final dataVal =
          (dvStr == null || dvStr.isEmpty) ? null : DateTime.tryParse(dvStr);

      final qtd = (raw['quantidade_atual'] as num?)?.toDouble() ?? 0.0;
      final ativo = (raw['ativo'] as bool?) ?? true;

      return LoteVM(
        id: id,
        materiaPrimaId: mpId,
        numeroLote: numero,
        dataRecebimento: dataRec,
        dataValidade: dataVal,
        quantidadeAtual: qtd,
        ativo: ativo,
      );
    }).toList();
  }

  /// Seleciona/consome por lote conforme a estratégia, retornando
  /// { loteId : quantidadeConsumida }. Consumo em cascata até cobrir 'quantidadeNecessaria'.
  Map<String, double> _consumirPorLotes({
    required List<LoteVM> lotes,
    required double quantidadeNecessaria,
    required LoteStrategy strategy,
    DateTime? agora,
  }) {
    double restante = quantidadeNecessaria;
    final Map<String, double> consumoPorLoteId = {};
    final now = agora ?? DateTime.now();

    // Filtra elegíveis
    final elegiveis = lotes.where((l) {
      final saldoOk = l.quantidadeAtual > 0;
      final ativoOk = l.ativo;
      final validadeOk = l.dataValidade == null || l.dataValidade!.isAfter(now);
      return saldoOk && ativoOk && validadeOk;
    }).toList();

    // Ordena conforme a estratégia
    elegiveis.sort((a, b) {
      switch (strategy) {
        case LoteStrategy.fefo:
          final av = a.dataValidade ?? a.dataRecebimento;
          final bv = b.dataValidade ?? b.dataRecebimento;
          final cmp = av.compareTo(bv); // vence primeiro
          return (cmp != 0) ? cmp : a.id.compareTo(b.id);
        case LoteStrategy.lifo:
          final cmp =
              b.dataRecebimento.compareTo(a.dataRecebimento); // mais novo 1º
          return (cmp != 0) ? cmp : a.id.compareTo(b.id);
        case LoteStrategy.fifo:
        default:
          final cmp =
              a.dataRecebimento.compareTo(b.dataRecebimento); // mais antigo 1º
          return (cmp != 0) ? cmp : a.id.compareTo(b.id);
      }
    });

    // Consumo em cascata
    for (final lote in elegiveis) {
      if (restante <= 0) break;
      final disponivel = lote.quantidadeAtual;
      final consumir = disponivel >= restante ? restante : disponivel;
      if (consumir > 0) {
        consumoPorLoteId[lote.id] = (consumoPorLoteId[lote.id] ?? 0) + consumir;
        lote.quantidadeAtual = disponivel - consumir; // debita em memória
        restante -= consumir;
      }
    }

    return consumoPorLoteId; // se sobrar restante > 0, faltou estoque por lote
  }

  // ============================================================
  //                          PRODUÇÃO
  // ============================================================

  /// Registrar produção **com seleção e consumo por LOTE** (FIFO/LIFO/FEFO).
  Future<bool> registrarProducao(
    String formulaId,
    double quantidadeProduzida,
    String loteProducao,
  ) async {
    try {
      await carregarDados();

      final formula = getFormulaPorId(formulaId);
      if (formula == null) {
        throw Exception('Fórmula não encontrada: $formulaId');
      }

      // 1) Consumo necessário por MP (com conversão de unidade)
      final Map<String, double> consumoNecessarioPorMP =
          _calcularConsumoPorMateriaPrima(formulaId, quantidadeProduzida);

      // 2) Selecionar/consumir por LOTE para cada MP
      // Detalhe para persistência: { mpId: { loteId: qtd } }
      final Map<String, Map<String, double>> detalheConsumoPorMP = {};
      // Agregado por MP (mantém compatibilidade com seu modelo Producao)
      final Map<String, double> agregadoPorMP = {};

      for (final entry in consumoNecessarioPorMP.entries) {
        final mpId = entry.key;
        final qtdNec = entry.value;

        // Busca lotes da MP
        final lotes = await _fetchLotesDaMP(mpId);

        // Consome conforme estratégia (padrão FIFO)
        final consumoPorLote = _consumirPorLotes(
          lotes: lotes,
          quantidadeNecessaria: qtdNec,
          strategy: _loteStrategy,
        );

        final consumido =
            consumoPorLote.values.fold<double>(0, (a, b) => a + b);
        if (consumido + 1e-6 < qtdNec) {
          throw Exception(
              'Estoque por lote insuficiente para a MP $mpId (necessário $qtdNec, disponível $consumido).');
        }

        detalheConsumoPorMP[mpId] = consumoPorLote;
        agregadoPorMP[mpId] = consumido;
      }

      // 3) Persistir produção e consumos por lote (ideal: transação/RPC no Postgres)
      // 3.1) Salva a produção (precisamos do id gerado)
      String? producaoId =
          await _supabaseService.saveProducaoReturningId(Producao(
        id: '',
        formulaId: formulaId,
        quantidadeProduzida: quantidadeProduzida,
        loteProducao: loteProducao,
        materiaPrimaConsumida: agregadoPorMP,
        dataProducao: DateTime.now(),
      ));

      if (producaoId == null || producaoId.isEmpty) {
        _errorMessage = 'Erro ao salvar produção (id não retornado)';
        notifyListeners();
        return false;
      }

      // 3.2) Insere CONSUMO por LOTE
      for (final mpEntry in detalheConsumoPorMP.entries) {
        final mpId = mpEntry.key;
        for (final loteEntry in mpEntry.value.entries) {
          final loteId = loteEntry.key;
          final qtd = loteEntry.value;

          final okItem = await _supabaseService.insertProducaoConsumo({
            'producao_id': int.parse(producaoId),
            'materia_prima_id': int.parse(mpId),
            'lote_id': int.parse(loteId),
            'quantidade': qtd,
          });
          if (!okItem) {
            _errorMessage =
                'Erro ao salvar consumo por lote (MP $mpId, lote $loteId)';
            notifyListeners();
            return false;
          }
        }
      }

      // 3.3) Debita saldo de CADA LOTE consumido
      for (final mpEntry in detalheConsumoPorMP.entries) {
        for (final loteEntry in mpEntry.value.entries) {
          final loteId = loteEntry.key;
          final qtd = loteEntry.value;

          final okLote = await _supabaseService.debitarSaldoDoLote(
            loteId: int.parse(loteId),
            quantidade: qtd,
          );
          if (!okLote) {
            _errorMessage = 'Erro ao debitar saldo do lote $loteId';
            notifyListeners();
            return false;
          }
        }
      }

      // (Opcional) 3.4) Atualiza estoque agregado da MP
      for (final mpEntry in agregadoPorMP.entries) {
        final mp = getMateriaPrimaPorId(mpEntry.key);
        if (mp == null) continue;

        final novoSaldo = mp.estoqueAtual - mpEntry.value;
        final okMP = await _supabaseService.updateMateriaPrima(
          int.parse(mp.id),
          {'estoque_atual': novoSaldo},
        );
        if (!okMP) {
          _errorMessage = 'Erro ao atualizar estoque agregado de ${mp.nome}';
          notifyListeners();
          return false;
        }
      }

      await carregarDados();
      return true;
    } catch (e) {
      _errorMessage = 'Erro ao registrar produção: $e';
      notifyListeners();
      return false;
    }
  }

  // ---------- Helper: consumo por MP para (fórmula, quantidade) ----------
  Map<String, double> _calcularConsumoPorMateriaPrima(
    String formulaId,
    double quantidadeProduzida,
  ) {
    final formula = getFormulaPorId(formulaId);
    if (formula == null) {
      throw Exception('Fórmula não encontrada para cálculo: $formulaId');
    }

    final Map<String, double> consumo = {};

    for (final componente in formula.componentes) {
      final mp = getMateriaPrimaPorId(componente.materiaPrimaId);
      if (mp == null) continue;

      double qtd = componente.quantidade * quantidadeProduzida;

      if (componente.unidadeMedida == 'g' && mp.unidadeMedida == 'kg') {
        qtd /= 1000;
      } else if (componente.unidadeMedida == 'kg' && mp.unidadeMedida == 'g') {
        qtd *= 1000;
      } else if (componente.unidadeMedida == 'mL' && mp.unidadeMedida == 'L') {
        qtd /= 1000;
      } else if (componente.unidadeMedida == 'L' && mp.unidadeMedida == 'mL') {
        qtd *= 1000;
      }

      consumo[mp.id] = (consumo[mp.id] ?? 0) + qtd;
    }

    return consumo;
  }

  // ---------- Produção: atualizar (mantém lógica antiga por MP) ----------
  Future<bool> atualizarProducao({
    required String id,
    required String formulaId,
    required double quantidadeProduzida,
    required String loteProducao,
    DateTime? dataProducao,
  }) async {
    try {
      await carregarDados();

      // Produção original
      final producaoAntiga = _producoes.firstWhere(
        (p) => p.id == id,
        orElse: () => throw Exception('Produção não encontrada: $id'),
      );

      final Map<String, double> consumoAntigo =
          Map<String, double>.from(producaoAntiga.materiaPrimaConsumida);

      // Recalcula consumo novo (agregado por MP)
      final Map<String, double> consumoNovo =
          _calcularConsumoPorMateriaPrima(formulaId, quantidadeProduzida);

      // Deltas (novo - antigo)
      final Set<String> todasMPs = {...consumoAntigo.keys, ...consumoNovo.keys};

      // Validação: para deltas positivos precisa ter estoque agregado
      for (final mpId in todasMPs) {
        final mp = getMateriaPrimaPorId(mpId);
        if (mp == null) continue;

        final double antigo = consumoAntigo[mpId] ?? 0.0;
        final double novo = consumoNovo[mpId] ?? 0.0;
        final double delta = novo - antigo;

        if (delta > 0 && mp.estoqueAtual < delta) {
          throw Exception(
            'Estoque insuficiente para ${mp.nome}: disponível ${mp.estoqueAtual.toStringAsFixed(2)} < necessário ${delta.toStringAsFixed(2)}',
          );
        }
      }

      // Aplica deltas ao estoque agregado (delta>0 consome; delta<0 devolve)
      for (final mpId in todasMPs) {
        final mp = getMateriaPrimaPorId(mpId);
        if (mp == null) continue;

        final double antigo = consumoAntigo[mpId] ?? 0.0;
        final double novo = consumoNovo[mpId] ?? 0.0;
        final double delta = novo - antigo;

        if (delta == 0) continue;

        final double novoEstoque = mp.estoqueAtual - delta;
        await _supabaseService.updateMateriaPrima(
          int.parse(mp.id),
          {'estoque_atual': novoEstoque},
        );
      }

      // Persiste a produção atualizada
      final payload = {
        'formula_id': formulaId,
        'quantidade_produzida': quantidadeProduzida,
        'lote_producao': loteProducao,
        'materia_prima_consumida': consumoNovo,
        'data_producao':
            (dataProducao ?? producaoAntiga.dataProducao).toIso8601String(),
      };

      final ok = await _supabaseService.updateProducao(id, payload);
      if (!ok) {
        _errorMessage = 'Erro ao atualizar produção';
        notifyListeners();
        return false;
      }

      await carregarDados();
      return true;
    } catch (e) {
      _errorMessage = 'Erro ao atualizar produção: $e';
      notifyListeners();
      return false;
    }
  }

  /// Exclui produção revertendo todo impacto no estoque (lotes + MPs).
  /// Usa a RPC reverter_e_excluir_producao.
  Future<bool> excluirProducao(String id) async {
    try {
      final producaoIdInt = int.tryParse(id);
      if (producaoIdInt == null) {
        _errorMessage = 'ID de produção inválido: $id';
        notifyListeners();
        return false;
      }

      final ok = await _supabaseService.revertAndDeleteProducao(producaoIdInt);

      if (!ok) {
        _errorMessage =
            'Erro ao reverter e excluir produção no Supabase';
        notifyListeners();
        return false;
      }

      await carregarDados();
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erro ao excluir produção: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> excluirTodasProducoes() async {
    try {
      await carregarDados();
      final producoesAtuais = List<Producao>.from(_producoes);

      for (final producao in producoesAtuais) {
        final ok = await excluirProducao(producao.id);
        if (!ok) {
          return false;
        }
      }

      await carregarDados();
      return true;
    } catch (e) {
      _errorMessage = 'Erro ao excluir todas as produções: $e';
      return false;
    }
  }
}
