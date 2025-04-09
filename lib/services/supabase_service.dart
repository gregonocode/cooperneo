import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/materia_prima.dart';
import '../models/producao.dart';
import '../models/formula.dart';
import '../models/lote.dart';
import '../models/fornecedor.dart';
import '../models/movimentacao.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Fórmulas
  Future<List<Formula>> fetchFormulas() async {
    try {
      print('Buscando fórmulas no Supabase...');
      final response = await _client.from('formulas').select();
      final formulasList = response
          .map((item) => Formula.fromJson(item as Map<String, dynamic>))
          .toList();
      print('Fórmulas mapeadas: $formulasList');
      return formulasList;
    } catch (e) {
      print('Erro ao buscar fórmulas: $e');
      throw Exception('Erro ao buscar fórmulas: $e');
    }
  }

  Future<bool> addFormula(Map<String, dynamic> data) async {
    try {
      print('Tentando inserir fórmula no Supabase: $data');
      final user = await _client.auth.currentUser;
      if (user == null) {
        throw Exception('Nenhum usuário autenticado encontrado');
      }
      final dataWithUserId = {
        ...data,
        'user_id': user.id, // Adiciona o ID do usuário autenticado
      };
      print('Dados com user_id: $dataWithUserId');
      await _client.from('formulas').insert(dataWithUserId);
      print('Fórmula inserida com sucesso no Supabase');
      return true;
    } catch (e) {
      print('Erro ao adicionar fórmula no Supabase: $e');
      return false;
    }
  }

  Future<bool> updateFormula(String id, Map<String, dynamic> data) async {
    try {
      print('Tentando atualizar fórmula no Supabase: id=$id, data=$data');
      final user = await _client.auth.currentUser;
      if (user == null) {
        throw Exception('Nenhum usuário autenticado encontrado');
      }
      final dataWithUserId = {
        ...data,
        'user_id': user.id, // Garante que user_id esteja presente
      };
      print('Dados com user_id: $dataWithUserId');
      await _client.from('formulas').update(dataWithUserId).eq('id', id);
      print('Fórmula atualizada com sucesso no Supabase');
      return true;
    } catch (e) {
      print('Erro ao atualizar fórmula no Supabase: $e');
      return false;
    }
  }

  Future<bool> deleteFormula(int id) async {
    try {
      print('Tentando deletar fórmula no Supabase: id=$id');
      await _client.from('formulas').delete().eq('id', id);
      print('Fórmula deletada com sucesso no Supabase');
      return true;
    } catch (e) {
      print('Erro ao deletar fórmula no Supabase: $e');
      return false;
    }
  }

  // Produções
  Future<List<Producao>> getProducoes() async {
    try {
      final response = await _client.from('producoes').select();
      return response.map((item) => Producao.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Erro ao buscar produções: $e');
    }
  }

  Future<bool> saveProducao(Producao producao) async {
    try {
      await _client.from('producoes').insert(producao.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  // Matérias-primas
  Future<List<MateriaPrima>> fetchMateriasPrimas() async {
    try {
      final response = await _client.from('materias_primas').select();
      return response.map((item) => MateriaPrima.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Erro ao buscar matérias-primas: $e');
    }
  }

  Future<bool> addMateriaPrima(Map<String, dynamic> data) async {
    try {
      await _client.from('materias_primas').insert(data);
      return true;
    } catch (e) {
      print('Erro detalhado ao adicionar matéria-prima: $e');
      throw Exception('Erro ao adicionar matéria-prima: $e');
    }
  }

  Future<bool> updateMateriaPrima(int id, Map<String, dynamic> data) async {
    try {
      await _client.from('materias_primas').update(data).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteMateriaPrima(int id) async {
    try {
      await _client.from('materias_primas').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Fornecedores
  Future<List<Fornecedor>> fetchFornecedores() async {
    try {
      final response = await _client.from('fornecedores').select();
      return response.map((item) => Fornecedor.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Erro ao buscar fornecedores: $e');
    }
  }

  Future<bool> addFornecedor(Map<String, dynamic> data) async {
    try {
      print('Tentando inserir fornecedor no Supabase: $data');
      final user = await _client.auth.currentUser;
      if (user == null) {
        throw Exception('Nenhum usuário autenticado encontrado');
      }
      final dataWithUserId = {
        ...data,
        'user_id': user.id, // Adiciona o ID do usuário autenticado
      };
      print('Dados com user_id: $dataWithUserId');
      await _client.from('fornecedores').insert(dataWithUserId);
      print('Fornecedor inserido com sucesso no Supabase');
      return true;
    } catch (e) {
      print('Erro ao adicionar fornecedor no Supabase: $e');
      return false;
    }
  }

  Future<bool> deleteFornecedor(int id) async {
    try {
      await _client.from('fornecedores').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Lotes
  Future<List<Lote>> fetchLotes() async {
    try {
      final response = await _client.from('lotes').select();
      return response.map((item) => Lote.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Erro ao buscar lotes: $e');
    }
  }

  Future<bool> addLote(Map<String, dynamic> data) async {
    try {
      await _client.from('lotes').insert(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateLote(int id, Map<String, dynamic> data) async {
    try {
      await _client.from('lotes').update(data).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteLote(int id) async {
    try {
      await _client.from('lotes').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Movimentações
  Future<List<Movimentacao>> fetchMovimentacoes() async {
    try {
      final response = await _client.from('movimentacoes').select();
      return response.map((item) => Movimentacao.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Erro ao buscar movimentações: $e');
    }
  }

  Future<bool> addMovimentacao(Map<String, dynamic> data) async {
    try {
      await _client.from('movimentacoes').insert(data);
      return true;
    } catch (e) {
      return false;
    }
  }
}
