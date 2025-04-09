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
    _isLoading = true;
    notifyListeners();

    try {
      _formulas = await _supabaseService.fetchFormulas();
      _producoes = await _supabaseService.getProducoes();
      _materiasPrimas = await _supabaseService.fetchMateriasPrimas();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Erro ao carregar dados: $e';
    } finally {
      _isLoading = false;
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
    if (formula == null) {
      return {};
    }

    Map<String, double> disponibilidade = {};

    for (var componente in formula.componentes) {
      final materiaPrima = getMateriaPrimaPorId(componente.materiaPrimaId);
      if (materiaPrima == null) {
        continue;
      }

      double quantidadeNecessaria = componente.quantidade * quantidadeProduzida;
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

      double estoqueAtual = materiaPrima.estoqueAtual;
      double saldo = estoqueAtual - quantidadeNecessaria;
      disponibilidade[materiaPrima.nome] = saldo;
    }

    return disponibilidade;
  }

  Future<bool> adicionarFormula({
    required String nome,
    required List<ComponenteFormula> componentes,
  }) async {
    print('Adicionando fórmula: nome=$nome, componentes=$componentes');
    try {
      final success = await _supabaseService.addFormula({
        'nome': nome,
        'componentes': componentes.map((c) => c.toJson()).toList(),
      });
      if (success) {
        print('Fórmula adicionada com sucesso. Recarregando dados...');
        await carregarDados();
        return true;
      } else {
        _errorMessage = 'Falha ao adicionar fórmula no Supabase';
        print('Erro: $_errorMessage');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Erro ao adicionar fórmula: $e';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  Future<bool> atualizarFormula({
    required String id,
    required String nome,
    String? descricao, // Alterado de String para String?
    required List<ComponenteFormula> componentes,
  }) async {
    print(
        'Atualizando fórmula: id=$id, nome=$nome, descricao=$descricao, componentes=$componentes');
    try {
      final success = await _supabaseService.updateFormula(id, {
        'nome': nome,
        if (descricao != null)
          'descricao': descricao, // Só inclui se não for null
        'componentes': componentes.map((c) => c.toJson()).toList(),
      });
      if (success) {
        print('Fórmula atualizada com sucesso. Recarregando dados...');
        await carregarDados();
        return true;
      } else {
        _errorMessage = 'Falha ao atualizar fórmula no Supabase';
        print('Erro: $_errorMessage');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Erro ao atualizar fórmula: $e';
      print('Erro: $_errorMessage');
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

  Future<bool> registrarProducao(
      String formulaId, double quantidadeProduzida, String loteProducao) async {
    try {
      final formula = getFormulaPorId(formulaId);
      if (formula == null) {
        throw Exception('Fórmula não encontrada');
      }

      Map<String, double> materiaPrimaConsumida = {};
      for (var componente in formula.componentes) {
        final materiaPrima = getMateriaPrimaPorId(componente.materiaPrimaId);
        if (materiaPrima == null) {
          throw Exception(
              'Matéria-prima não encontrada: ${componente.materiaPrimaId}');
        }

        double quantidadeConsumida =
            componente.quantidade * quantidadeProduzida;
        if (componente.unidadeMedida == 'g' &&
            materiaPrima.unidadeMedida == 'kg') {
          quantidadeConsumida /= 1000;
        } else if (componente.unidadeMedida == 'kg' &&
            materiaPrima.unidadeMedida == 'g') {
          quantidadeConsumida *= 1000;
        } else if (componente.unidadeMedida == 'mL' &&
            materiaPrima.unidadeMedida == 'L') {
          quantidadeConsumida /= 1000;
        } else if (componente.unidadeMedida == 'L' &&
            materiaPrima.unidadeMedida == 'mL') {
          quantidadeConsumida *= 1000;
        }

        double estoqueAtual = materiaPrima.estoqueAtual;
        if (estoqueAtual < quantidadeConsumida) {
          throw Exception('Estoque insuficiente para ${materiaPrima.nome}');
        }

        materiaPrimaConsumida[materiaPrima.id] = quantidadeConsumida;
      }

      for (var entry in materiaPrimaConsumida.entries) {
        final materiaPrimaId = int.parse(entry.key);
        final quantidadeConsumida = entry.value;
        final materiaPrima = _materiasPrimas.firstWhere(
          (mp) => mp.id == entry.key,
          orElse: () => throw Exception('Matéria-prima não encontrada'),
        );

        await _supabaseService.updateMateriaPrima(
          materiaPrimaId,
          {'estoque_atual': materiaPrima.estoqueAtual - quantidadeConsumida},
        );
      }

      final producao = Producao(
        id: '', // O ID será gerado pelo Supabase
        formulaId: formulaId,
        quantidadeProduzida: quantidadeProduzida,
        loteProducao: loteProducao,
        materiaPrimaConsumida: materiaPrimaConsumida,
        dataProducao: DateTime.now(),
      );

      final success = await _supabaseService.saveProducao(producao);
      if (success) {
        await carregarDados();
        return true;
      }
      _errorMessage = 'Erro ao registrar produção';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao registrar produção: $e';
      notifyListeners();
      return false;
    }
  }
}
