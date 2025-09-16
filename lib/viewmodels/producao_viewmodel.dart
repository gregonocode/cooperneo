import 'package:flutter/material.dart';
import '../models/materia_prima.dart';
import '../models/formula.dart';
import '../models/producao.dart';
import '../models/componente_formula.dart';
import '../services/supabase_service.dart';
import 'package:collection/collection.dart';

class ProducaoViewModel extends ChangeNotifier {
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

  // ---------- Produção: criar ----------
  Future<bool> registrarProducao(
      String formulaId, double quantidadeProduzida, String loteProducao) async {
    try {
      await carregarDados();

      final formula = getFormulaPorId(formulaId);
      if (formula == null) {
        throw Exception('Fórmula não encontrada: $formulaId');
      }

      // Calcula consumo e valida estoque
      final Map<String, double> materiaPrimaConsumida = {};
      for (final componente in formula.componentes) {
        final mp = getMateriaPrimaPorId(componente.materiaPrimaId);
        if (mp == null) {
          throw Exception(
              'Matéria-prima não encontrada: ${componente.materiaPrimaId}');
        }

        double qtd = componente.quantidade * quantidadeProduzida;
        if (componente.unidadeMedida == 'g' && mp.unidadeMedida == 'kg') {
          qtd /= 1000;
        } else if (componente.unidadeMedida == 'kg' &&
            mp.unidadeMedida == 'g') {
          qtd *= 1000;
        } else if (componente.unidadeMedida == 'mL' &&
            mp.unidadeMedida == 'L') {
          qtd /= 1000;
        } else if (componente.unidadeMedida == 'L' &&
            mp.unidadeMedida == 'mL') {
          qtd *= 1000;
        }

        if (mp.estoqueAtual < qtd) {
          throw Exception(
              'Estoque insuficiente para ${mp.nome}: ${mp.estoqueAtual} < $qtd');
        }

        materiaPrimaConsumida[mp.id] = qtd;
      }

      // Abate estoque
      for (final e in materiaPrimaConsumida.entries) {
        final mp = _materiasPrimas.firstWhere(
          (m) => m.id == e.key,
          orElse: () => throw Exception(
              'MP não encontrada ao atualizar estoque: ${e.key}'),
        );
        await _supabaseService.updateMateriaPrima(
          int.parse(mp.id),
          {'estoque_atual': mp.estoqueAtual - e.value},
        );
      }

      // Persiste produção
      final producao = Producao(
        id: '',
        formulaId: formulaId,
        quantidadeProduzida: quantidadeProduzida,
        loteProducao: loteProducao,
        materiaPrimaConsumida: materiaPrimaConsumida,
        dataProducao: DateTime.now(),
      );

      final ok = await _supabaseService.saveProducao(producao);
      if (!ok) {
        _errorMessage = 'Erro ao salvar produção no Supabase';
        notifyListeners();
        return false;
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

  // ---------- Produção: atualizar com delta de estoque ----------
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

      // Recalcula consumo novo
      final Map<String, double> consumoNovo =
          _calcularConsumoPorMateriaPrima(formulaId, quantidadeProduzida);

      // Deltas (novo - antigo)
      final Set<String> todasMPs = {...consumoAntigo.keys, ...consumoNovo.keys};

      // Validação: para deltas positivos precisa ter estoque
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

      // Aplica deltas ao estoque (delta>0 consome; delta<0 devolve)
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

  // ---------- Produção: excluir (reverte estoque) ----------
  Future<bool> excluirProducao(String id) async {
    try {
      final producao = _producoes.firstWhereOrNull((p) => p.id == id);
      if (producao == null) {
        _errorMessage = 'Produção não encontrada: $id';
        notifyListeners();
        return false;
      }

      // Devolve estoque consumido
      for (final entry in producao.materiaPrimaConsumida.entries) {
        final mpId = entry.key;
        final qtd = entry.value;

        final mp = _materiasPrimas.firstWhereOrNull((m) => m.id == mpId);
        if (mp == null) continue;

        final ok = await _supabaseService.updateMateriaPrima(
          int.parse(mpId),
          {'estoque_atual': mp.estoqueAtual + qtd},
        );
        if (!ok) {
          _errorMessage = 'Erro ao reverter estoque para ${mp.nome}';
          notifyListeners();
          return false;
        }
      }

      // Remove a produção
      final okDelete = await _supabaseService.deleteProducao(id);
      if (!okDelete) {
        _errorMessage = 'Erro ao excluir produção no Supabase';
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
      final result = await _supabaseService.deleteAllProducoes();
      if (result) {
        await carregarDados();
      }
      return result;
    } catch (e) {
      _errorMessage = 'Erro ao excluir todas as produções: $e';
      return false;
    }
  }
}
