import 'package:flutter/material.dart';
import '../models/materia_prima.dart';
import '../models/lote.dart';
import '../models/fornecedor.dart';
import '../models/movimentacao.dart';
import '../services/supabase_service.dart';

class EstoqueViewModel extends ChangeNotifier {
  final SupabaseService _supabaseService;

  List<MateriaPrima> _materiasPrimas = [];
  List<Lote> _lotes = [];
  List<Fornecedor> _fornecedores = [];
  List<Movimentacao> _movimentacoes = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<MateriaPrima> get materiasPrimas => _materiasPrimas;
  List<Lote> get lotes => _lotes;
  List<Fornecedor> get fornecedores => _fornecedores;
  List<Movimentacao> get movimentacoes => _movimentacoes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  EstoqueViewModel({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService() {
    print('EstoqueViewModel inicializado. Carregando dados...');
    carregarDados();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> carregarDados() async {
    print('Iniciando carregarDados...');
    _isLoading = true;
    notifyListeners();

    try {
      _materiasPrimas = await _supabaseService.fetchMateriasPrimas();
      print('Matérias-primas carregadas: $_materiasPrimas');
      _lotes = await _supabaseService.fetchLotes();
      print('Lotes carregados: $_lotes');
      _fornecedores = await _supabaseService.fetchFornecedores();
      print('Fornecedores carregados: $_fornecedores');
      _movimentacoes = await _supabaseService.fetchMovimentacoes();
      print('Movimentações carregadas: $_movimentacoes');
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Erro ao carregar dados: $e';
      print('Erro em carregarDados: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
      print('carregarDados finalizado. isLoading: $_isLoading');
    }
  }

  Future<bool> adicionarMateriaPrima({
    required String nome,
    required double estoqueAtual,
    required String unidadeMedida,
  }) async {
    print(
        'Adicionando matéria-prima: nome=$nome, estoqueAtual=$estoqueAtual, unidadeMedida=$unidadeMedida');
    try {
      final success = await _supabaseService.addMateriaPrima({
        'nome': nome,
        'estoque_atual': estoqueAtual,
        'unidade_medida': unidadeMedida,
      });

      if (success) {
        print('Matéria-prima adicionada com sucesso. Recarregando dados...');
        await carregarDados();
        return true;
      }
      _errorMessage = 'Erro ao adicionar matéria-prima';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao adicionar matéria-prima: $e';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  Future<bool> atualizarMateriaPrima({
    required int id,
    required String nome,
    required double estoqueAtual,
    required String unidadeMedida,
  }) async {
    print(
        'Atualizando matéria-prima ID $id: nome=$nome, estoqueAtual=$estoqueAtual, unidadeMedida=$unidadeMedida');
    try {
      final success = await _supabaseService.updateMateriaPrima(id, {
        'nome': nome,
        'estoque_atual': estoqueAtual,
        'unidade_medida': unidadeMedida,
      });

      if (success) {
        print('Matéria-prima atualizada com sucesso. Recarregando dados...');
        await carregarDados();
        return true;
      }
      _errorMessage = 'Erro ao atualizar matéria-prima';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao atualizar matéria-prima: $e';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletarMateriaPrima(int id) async {
    print('Deletando matéria-prima ID $id');
    try {
      final success = await _supabaseService.deleteMateriaPrima(id);
      if (success) {
        print('Matéria-prima deletada com sucesso. Recarregando dados...');
        await carregarDados();
        return true;
      }
      _errorMessage = 'Erro ao deletar matéria-prima';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao deletar matéria-prima: $e';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  Future<bool> excluirMateriaPrima(String id) async {
    return await deletarMateriaPrima(int.parse(id));
  }

  Future<bool> adicionarFornecedor({
    required String nome,
    required String? contato,
    required String? endereco,
  }) async {
    print(
        'Adicionando fornecedor: nome=$nome, contato=$contato, endereco=$endereco');
    try {
      final success = await _supabaseService.addFornecedor({
        'nome': nome,
        if (contato != null) 'contato': contato,
        if (endereco != null) 'endereco': endereco,
      });
      if (success) {
        print('Fornecedor adicionado com sucesso. Recarregando dados...');
        await carregarDados();
        return true;
      } else {
        _errorMessage = 'Falha ao adicionar fornecedor no Supabase';
        print('Erro: $_errorMessage');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Erro ao adicionar fornecedor: $e';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  Future<bool> atualizarFornecedor({
    required int id,
    required String nome,
    required String? contato,
    required String? endereco,
  }) async {
    print(
        'Atualizando fornecedor ID $id: nome=$nome, contato=$contato, endereco=$endereco');
    try {
      final success = await _supabaseService.addFornecedor({
        'nome': nome,
        if (contato != null) 'contato': contato,
        if (endereco != null) 'endereco': endereco,
      });

      if (success) {
        print('Fornecedor atualizado com sucesso. Recarregando dados...');
        await carregarDados();
        return true;
      }
      _errorMessage = 'Erro ao atualizar fornecedor';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao atualizar fornecedor: $e';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  Future<bool> excluirFornecedor(String id) async {
    print('Deletando fornecedor ID $id');
    try {
      final success = await _supabaseService.deleteFornecedor(int.parse(id));
      if (success) {
        print('Fornecedor deletado com sucesso. Recarregando dados...');
        await carregarDados();
        return true;
      }
      _errorMessage = 'Erro ao deletar fornecedor';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao deletar fornecedor: $e';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  Future<bool> adicionarLote({
    required int materiaPrimaId,
    required int fornecedorId,
    required String numeroLote,
    required double quantidade,
  }) async {
    print(
        'Adicionando lote: materiaPrimaId=$materiaPrimaId, fornecedorId=$fornecedorId, numeroLote=$numeroLote, quantidade=$quantidade');
    try {
      final materiaPrima = _materiasPrimas.firstWhere(
        (mp) => mp.id == materiaPrimaId.toString(),
        orElse: () => throw Exception('Matéria-prima não encontrada'),
      );

      final success = await _supabaseService.addLote({
        'materia_prima_id': materiaPrimaId,
        'fornecedor_id': fornecedorId,
        'numero_lote': numeroLote,
        'quantidade_recebida': quantidade,
        'quantidade_atual': quantidade,
        'data_recebimento': DateTime.now().toIso8601String(),
      });

      if (success) {
        await _supabaseService.addMovimentacao({
          'materia_prima_id': materiaPrimaId,
          'tipo': 'entrada',
          'quantidade': quantidade,
          'motivo': 'Recebimento de lote $numeroLote',
          'data': DateTime.now().toIso8601String(),
        });

        await atualizarEstoqueMateriaPrima(
          materiaPrimaId: materiaPrimaId,
          novaQuantidade: materiaPrima.estoqueAtual + quantidade,
        );

        print('Lote adicionado com sucesso. Recarregando dados...');
        await carregarDados();
        return true;
      }
      _errorMessage = 'Erro ao adicionar lote';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao adicionar lote: $e';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  Future<bool> atualizarLote({
    required int id,
    required int materiaPrimaId,
    required int fornecedorId,
    required String numeroLote,
    required double quantidadeAtual,
    required double quantidadeRecebida,
    required DateTime dataRecebimento,
  }) async {
    print(
        'Atualizando lote ID $id: materiaPrimaId=$materiaPrimaId, fornecedorId=$fornecedorId, numeroLote=$numeroLote, quantidadeAtual=$quantidadeAtual');
    try {
      final loteAtual = _lotes.firstWhere(
        (lote) => lote.id == id.toString(),
        orElse: () => throw Exception('Lote não encontrado'),
      );

      final success = await _supabaseService.updateLote(id, {
        'materia_prima_id': materiaPrimaId,
        'fornecedor_id': fornecedorId,
        'numero_lote': numeroLote,
        'quantidade_atual': quantidadeAtual,
        'quantidade_recebida': quantidadeRecebida,
        'data_recebimento': dataRecebimento.toIso8601String(),
      });

      if (success) {
        final materiaPrima = _materiasPrimas.firstWhere(
          (mp) => mp.id == materiaPrimaId.toString(),
          orElse: () => throw Exception('Matéria-prima não encontrada'),
        );

        final diferenca = quantidadeAtual - loteAtual.quantidadeAtual;
        await atualizarEstoqueMateriaPrima(
          materiaPrimaId: materiaPrimaId,
          novaQuantidade: materiaPrima.estoqueAtual + diferenca,
        );

        print('Lote atualizado com sucesso. Recarregando dados...');
        await carregarDados();
        return true;
      }
      _errorMessage = 'Erro ao atualizar lote';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao atualizar lote: $e';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletarLote(int id) async {
    print('Deletando lote ID $id');
    try {
      final lote = _lotes.firstWhere(
        (lote) => lote.id == id.toString(),
        orElse: () => throw Exception('Lote não encontrado'),
      );

      final materiaPrima = _materiasPrimas.firstWhere(
        (mp) => mp.id == lote.materiaPrimaId,
        orElse: () => throw Exception('Matéria-prima não encontrada'),
      );

      final success = await _supabaseService.deleteLote(id);
      if (success) {
        await atualizarEstoqueMateriaPrima(
          materiaPrimaId: int.parse(lote.materiaPrimaId),
          novaQuantidade: materiaPrima.estoqueAtual - lote.quantidadeAtual,
        );

        print('Lote deletado com sucesso. Recarregando dados...');
        await carregarDados();
        return true;
      }
      _errorMessage = 'Erro ao deletar lote';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao deletar lote: $e';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  Future<bool> ajustarEstoque({
    required int materiaPrimaId,
    required double novaQuantidade,
    required String motivo,
  }) async {
    print(
        'Ajustando estoque: materiaPrimaId=$materiaPrimaId, novaQuantidade=$novaQuantidade, motivo=$motivo');
    try {
      final materiaPrima = _materiasPrimas.firstWhere(
        (mp) => mp.id == materiaPrimaId.toString(),
        orElse: () => throw Exception('Matéria-prima não encontrada'),
      );

      final diferenca = novaQuantidade - materiaPrima.estoqueAtual;
      final tipo = diferenca >= 0 ? 'entrada' : 'saida';
      final quantidade = diferenca.abs();

      final success = await atualizarEstoqueMateriaPrima(
        materiaPrimaId: materiaPrimaId,
        novaQuantidade: novaQuantidade,
      );

      if (success) {
        await _supabaseService.addMovimentacao({
          'materia_prima_id': materiaPrimaId,
          'tipo': tipo,
          'quantidade': quantidade,
          'motivo': motivo,
          'data': DateTime.now().toIso8601String(),
        });

        print('Estoque ajustado com sucesso. Recarregando dados...');
        await carregarDados();
        return true;
      }
      _errorMessage = 'Erro ao ajustar estoque';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao ajustar estoque: $e';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  Future<bool> atualizarEstoqueMateriaPrima({
    required int materiaPrimaId,
    required double novaQuantidade,
  }) async {
    print(
        'Atualizando estoque da matéria-prima ID $materiaPrimaId: novaQuantidade=$novaQuantidade');
    try {
      final success = await _supabaseService.updateMateriaPrima(
        materiaPrimaId,
        {'estoque_atual': novaQuantidade},
      );

      if (success) {
        print(
            'Estoque da matéria-prima atualizado com sucesso. Recarregando dados...');
        await carregarDados();
        return true;
      }
      _errorMessage = 'Erro ao atualizar estoque da matéria-prima';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao atualizar estoque da matéria-prima: $e';
      print('Erro: $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  MateriaPrima? getMateriaPrimaPorId(String id) {
    try {
      return _materiasPrimas.firstWhere((mp) => mp.id == id);
    } catch (e) {
      print('Matéria-prima ID $id não encontrada');
      return null;
    }
  }

  Fornecedor? getFornecedorPorId(String id) {
    try {
      return _fornecedores.firstWhere((f) => f.id == id);
    } catch (e) {
      print('Fornecedor ID $id não encontrado');
      return null;
    }
  }

  List<Lote> getLotesPorMateriaPrima(String materiaPrimaId) {
    return _lotes
        .where((lote) => lote.materiaPrimaId == materiaPrimaId)
        .toList();
  }

  List<Movimentacao> getMovimentacoesPorMateriaPrima(String materiaPrimaId) {
    return _movimentacoes
        .where((mov) => mov.materiaPrimaId == materiaPrimaId)
        .toList();
  }
}
