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

      // Carregar fórmulas
      print('Carregando fórmulas...');
      _formulas = await _supabaseService.fetchFormulas();
      print('Fórmulas carregadas: ${_formulas.length}');
      print('Fórmulas disponíveis: ${_formulas.map((f) => f.id).toList()}');

      // Carregar produções (continua mesmo com erro)
      try {
        print('Carregando produções...');
        _producoes = await _supabaseService.getProducoes();
        print('Produções carregadas: ${_producoes.length}');
        print('Produções disponíveis: ${_producoes.map((p) => p.id).toList()}');
      } catch (e) {
        print('Erro ao carregar produções: $e');
        _errorMessage = 'Erro ao carregar produções: $e';
        // Não interrompe o carregamento das matérias-primas
      }

      // Carregar matérias-primas (sempre executa)
      print('Carregando matérias-primas...');
      _materiasPrimas = await _supabaseService.fetchMateriasPrimas();
      print('Matérias-primas carregadas: ${_materiasPrimas.length}');
      print(
          'Matérias-primas disponíveis: ${_materiasPrimas.map((mp) => mp.id).toList()}');

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Erro ao carregar dados: $e';
      print('Erro em carregarDados: $_errorMessage');
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
    String? descricao,
    required List<ComponenteFormula> componentes,
  }) async {
    print(
        'Atualizando fórmula: id=$id, nome=$nome, descricao=$descricao, componentes=$componentes');
    try {
      final success = await _supabaseService.updateFormula(id, {
        'nome': nome,
        if (descricao != null) 'descricao': descricao,
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
    print(
        'Iniciando registrarProducao: formulaId=$formulaId, quantidade=$quantidadeProduzida, lote=$loteProducao');
    try {
      print('Recarregando dados antes de processar a produção...');
      await carregarDados();
      print(
          'Matérias-primas disponíveis após carregarDados: ${_materiasPrimas.map((mp) => mp.id).toList()}');

      final formula = getFormulaPorId(formulaId);
      if (formula == null) {
        throw Exception('Fórmula não encontrada: $formulaId');
      }
      print('Fórmula encontrada: ${formula.nome}');

      Map<String, double> materiaPrimaConsumida = {};
      for (var componente in formula.componentes) {
        final materiaPrima = getMateriaPrimaPorId(componente.materiaPrimaId);
        if (materiaPrima == null) {
          throw Exception(
              'Matéria-prima não encontrada: ${componente.materiaPrimaId}');
        }
        print(
            'Matéria-prima encontrada: ${materiaPrima.nome}, ID: ${materiaPrima.id}');

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
        print(
            'Quantidade consumida calculada: $quantidadeConsumida para ${materiaPrima.nome}');

        double estoqueAtual = materiaPrima.estoqueAtual;
        if (estoqueAtual < quantidadeConsumida) {
          throw Exception(
              'Estoque insuficiente para ${materiaPrima.nome}: $estoqueAtual < $quantidadeConsumida');
        }
        print('Estoque suficiente: $estoqueAtual >= $quantidadeConsumida');

        materiaPrimaConsumida[materiaPrima.id] = quantidadeConsumida;
      }

      for (var entry in materiaPrimaConsumida.entries) {
        final materiaPrimaId = int.parse(entry.key);
        final quantidadeConsumida = entry.value;
        final materiaPrima = _materiasPrimas.firstWhere(
          (mp) => mp.id == entry.key,
          orElse: () => throw Exception(
              'Matéria-prima não encontrada ao atualizar estoque: ${entry.key}'),
        );
        print(
            'Atualizando estoque de ${materiaPrima.nome}: ${materiaPrima.estoqueAtual} - $quantidadeConsumida');
        await _supabaseService.updateMateriaPrima(
          materiaPrimaId,
          {'estoque_atual': materiaPrima.estoqueAtual - quantidadeConsumida},
        );
        print('Estoque atualizado para ${materiaPrima.nome}');
      }

      final producao = Producao(
        id: '',
        formulaId: formulaId,
        quantidadeProduzida: quantidadeProduzida,
        loteProducao: loteProducao,
        materiaPrimaConsumida: materiaPrimaConsumida,
        dataProducao: DateTime.now(),
      );
      print('Produção criada: $producao');

      final success = await _supabaseService.saveProducao(producao);
      if (success) {
        print('Produção registrada com sucesso');
        await carregarDados();
        return true;
      }
      _errorMessage = 'Erro ao salvar produção no Supabase';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao registrar produção: $e';
      print('Erro capturado: $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  Future<bool> excluirProducao(String id) async {
    try {
      print('Excluindo produção: id=$id');
      final producao = _producoes.firstWhereOrNull((p) => p.id == id);
      if (producao == null) {
        _errorMessage = 'Produção não encontrada: $id';
        print('Erro: $_errorMessage');
        notifyListeners();
        return false;
      }

      // Reverter o consumo de matérias-primas
      for (var entry in producao.materiaPrimaConsumida.entries) {
        final materiaPrimaId = entry.key;
        final quantidadeConsumida = entry.value;
        final materiaPrima =
            _materiasPrimas.firstWhereOrNull((mp) => mp.id == materiaPrimaId);
        if (materiaPrima == null) {
          print('Matéria-prima não encontrada para reversão: $materiaPrimaId');
          continue;
        }
        print(
            'Reverting estoque para ${materiaPrima.nome}: ${materiaPrima.estoqueAtual} + $quantidadeConsumida');
        final success = await _supabaseService.updateMateriaPrima(
          int.parse(materiaPrimaId),
          {'estoque_atual': materiaPrima.estoqueAtual + quantidadeConsumida},
        );
        if (!success) {
          _errorMessage = 'Erro ao reverter estoque para ${materiaPrima.nome}';
          print('Erro: $_errorMessage');
          notifyListeners();
          return false;
        }
        print('Estoque revertido para ${materiaPrima.nome}');
      }

      // Excluir a produção
      final success = await _supabaseService.deleteProducao(id);
      if (success) {
        print('Produção excluída com sucesso. Recarregando dados...');
        await carregarDados();
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Erro ao excluir produção no Supabase';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao excluir produção: $e';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    }
  }
}
