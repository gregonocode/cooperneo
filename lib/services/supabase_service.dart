import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/materia_prima.dart';
import '../models/producao.dart';
import '../models/formula.dart';
import '../models/lote.dart';
import '../models/fornecedor.dart';
import '../models/movimentacao.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // ============================================================
  //                      FÓRMULAS
  // ============================================================

  Future<List<Formula>> fetchFormulas() async {
    try {
      final response = await _client.from('formulas').select();
      return response.map((item) => Formula.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Erro ao buscar fórmulas: $e');
    }
  }

  Future<bool> addFormula(Map<String, dynamic> data) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null)
        throw Exception('Nenhum usuário autenticado encontrado');
      final dataWithUserId = {
        ...data,
        'user_id': user.id,
      };
      await _client.from('formulas').insert(dataWithUserId);
      return true;
    } catch (e) {
      print('Erro ao adicionar fórmula no Supabase: $e');
      return false;
    }
  }

  Future<bool> updateFormula(String id, Map<String, dynamic> data) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null)
        throw Exception('Nenhum usuário autenticado encontrado');
      final dataWithUserId = {
        ...data,
        'user_id': user.id,
      };
      await _client.from('formulas').update(dataWithUserId).eq('id', id);
      return true;
    } catch (e) {
      print('Erro ao atualizar fórmula no Supabase: $e');
      return false;
    }
  }

  Future<bool> deleteFormula(int id) async {
    try {
      await _client.from('formulas').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Erro ao deletar fórmula no Supabase: $e');
      return false;
    }
  }

  // ============================================================
  //                      PRODUÇÕES
  // ============================================================

  Future<List<Producao>> getProducoes() async {
    try {
      final response = await _client.from('producoes').select();
      final data = response as List<dynamic>? ?? [];

      final producoesList = data.map((item) {
        final map = item as Map<String, dynamic>;
        try {
          return Producao.fromJson(map);
        } catch (e) {
          // fallback para não quebrar carregamento
          return Producao(
            id: map['id']?.toString() ??
                'desconhecido_${DateTime.now().millisecondsSinceEpoch}',
            formulaId: map['formula_id']?.toString() ?? '',
            quantidadeProduzida:
                (map['quantidade_produzida'] as num?)?.toDouble() ?? 0.0,
            loteProducao: map['lote_producao']?.toString() ?? 'Desconhecido',
            materiaPrimaConsumida:
                (map['materia_prima_consumida'] as Map<String, dynamic>? ?? {})
                    .map((k, v) =>
                        MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0)),
            dataProducao:
                DateTime.tryParse(map['data_producao']?.toString() ?? '') ??
                    DateTime.now(),
          );
        }
      }).toList();

      return producoesList;
    } catch (e) {
      throw Exception('Erro ao buscar produções: $e');
    }
  }

  Future<bool> saveProducao(Producao producao) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        print('Erro: Nenhum usuário autenticado encontrado');
        return false;
      }
      final data = {
        'formula_id': int.tryParse(producao.formulaId) ?? producao.formulaId,
        'quantidade_produzida': producao.quantidadeProduzida,
        'data_producao': producao.dataProducao.toIso8601String(),
        'lote_producao': producao.loteProducao,
        'materia_prima_consumida': producao.materiaPrimaConsumida,
        'user_id': user.id,
      };
      await _client.from('producoes').insert(data);
      return true;
    } catch (e) {
      print('Erro ao salvar produção no Supabase: $e');
      return false;
    }
  }

  /// NOVO: salva produção e retorna o ID gerado (usado pela lógica de consumo por lote)
  Future<String?> saveProducaoReturningId(Producao producao) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        print('Erro: Nenhum usuário autenticado encontrado');
        return null;
      }
      final data = {
        'formula_id': int.tryParse(producao.formulaId) ?? producao.formulaId,
        'quantidade_produzida': producao.quantidadeProduzida,
        'data_producao': producao.dataProducao.toIso8601String(),
        'lote_producao': producao.loteProducao,
        'materia_prima_consumida': producao.materiaPrimaConsumida,
        'user_id': user.id,
      };

      final inserted =
          await _client.from('producoes').insert(data).select('id').single();

      final dynamic id = inserted['id'];
      return id == null ? null : id.toString();
    } catch (e) {
      print('Erro ao salvar produção (retornando id): $e');
      return null;
    }
  }

  Future<bool> updateProducao(String id, Map<String, dynamic> data) async {
    try {
      await _client.from('producoes').update(data).eq('id', id);
      return true;
    } catch (e) {
      print('Erro ao atualizar produção no Supabase: $e');
      return false;
    }
  }

  Future<bool> deleteProducao(String id) async {
    try {
      await _client.from('producoes').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Erro ao deletar produção no Supabase: $e');
      return false;
    }
  }

  /// Excluir TODAS as produções (usado no botão de "excluir todas")
  Future<bool> deleteAllProducoes() async {
    try {
      await _client.from('producoes').delete();
      return true;
    } catch (e) {
      print('Erro ao excluir todas as produções: $e');
      return false;
    }
  }

  /// Reverte o consumo (lotes + estoque agregado) e exclui a produção via RPC atômica.
  Future<bool> revertAndDeleteProducao(int producaoId) async {
    try {
      final res = await _client.rpc(
        'reverter_e_excluir_producao',
        params: {'p_producao_id': producaoId},
      );
      return (res as bool?) ?? false;
    } catch (e) {
      print('Erro ao reverter/excluir produção via RPC: $e');
      return false;
    }
  }

  // ============================================================
  //                    MATÉRIAS-PRIMAS
  // ============================================================

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

  // ============================================================
  //                      FORNECEDORES
  // ============================================================

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
      final user = _client.auth.currentUser;
      if (user == null)
        throw Exception('Nenhum usuário autenticado encontrado');
      final dataWithUserId = {
        ...data,
        'user_id': user.id,
      };
      await _client.from('fornecedores').insert(dataWithUserId);
      return true;
    } catch (e) {
      print('Erro ao adicionar fornecedor no Supabase: $e');
      return false;
    }
  }

  /// NOVO: correção para atualizar fornecedor (antes chamava addFornecedor por engano)
  Future<bool> updateFornecedor(int id, Map<String, dynamic> data) async {
    try {
      await _client.from('fornecedores').update(data).eq('id', id);
      return true;
    } catch (e) {
      print('Erro ao atualizar fornecedor: $e');
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

  // ============================================================
  //                          LOTES
  // ============================================================

  /// Busca geral (você já usava) – mantido: mais novos primeiro
  Future<List<Lote>> fetchLotes() async {
    try {
      final response = await _client
          .from('lotes')
          .select()
          .order('data_recebimento', ascending: false);
      return (response as List)
          .map((item) => Lote.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Erro ao buscar lotes: $e');
    }
  }

  /// NOVO: busca lotes de uma matéria-prima específica (o VM filtra/ordena)
  Future<List<Map<String, dynamic>>> fetchLotesByMateriaPrima(
      String materiaPrimaId) async {
    try {
      final query = _client.from('lotes').select();

      // Se o ID for numérico, filtra como int; se não, filtra como string (para UUID etc.)
      final intId = int.tryParse(materiaPrimaId);
      final filtered = intId != null
          ? query.eq('materia_prima_id', intId)
          : query.eq('materia_prima_id', materiaPrimaId);

      // FIFO natural: mais antigo primeiro
      final resp = await filtered.order('data_recebimento', ascending: true);

      // Garante tipagem segura
      if (resp is List) {
        return resp.cast<Map<String, dynamic>>();
      }
      return const <Map<String, dynamic>>[];
    } catch (e) {
      throw Exception('Erro ao buscar lotes por MP ($materiaPrimaId): $e');
    }
  }

  Future<bool> addLote(Map<String, dynamic> data) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        print('Erro: Nenhum usuário autenticado encontrado');
        return false;
      }
      final dataWithUserId = {
        ...data,
        'user_id': user.id,
      };
      await _client.from('lotes').insert(dataWithUserId);
      return true;
    } catch (e) {
      print('Erro ao adicionar lote no Supabase: $e');
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

  /// NOVO: debita saldo do lote (versão simples; para produção real, prefira RPC atômica)
  // Versão ATÔMICA via RPC (recomendado)
  Future<bool> debitarSaldoDoLote(
      {required int loteId, required double quantidade}) async {
    try {
      final res = await _client.rpc('debitar_saldo_lote', params: {
        'p_lote_id': loteId,
        'p_quantidade': quantidade,
      });
      // Supabase retorna bool (true/false)
      return (res as bool?) ?? false;
    } catch (e) {
      print('Erro RPC debitar_saldo_lote: $e');
      return false;
    }
  }

  // ============================================================
  //                     PRODUÇÃO_CONSUMOS (por lote)
  // ============================================================

  /// NOVO: insere o detalhamento de consumo por lote
  /// Espera: { producao_id, materia_prima_id, lote_id, quantidade }
  Future<bool> insertProducaoConsumo(Map<String, dynamic> data) async {
    try {
      await _client.from('producao_consumos').insert(data);
      return true;
    } catch (e) {
      print('Erro ao inserir producao_consumo: $e');
      return false;
    }
  }

  // ============================================================
  //                     MOVIMENTAÇÕES
  // ============================================================

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
