import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../theme/app_theme.dart';
import '../models/materia_prima.dart';
import '../models/movimentacao.dart';
import '../viewmodels/estoque_viewmodel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class MateriasPrimasScreen extends StatefulWidget {
  const MateriasPrimasScreen({Key? key}) : super(key: key);

  @override
  State<MateriasPrimasScreen> createState() => _MateriasPrimasScreenState();
}

class _MateriasPrimasScreenState extends State<MateriasPrimasScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // Atualizar dados
    Future.microtask(() {
      Provider.of<EstoqueViewModel>(context, listen: false).carregarDados();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final estoqueViewModel = Provider.of<EstoqueViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Materias-Primas'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar Materia-prima...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: estoqueViewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMateriasPrimasList(estoqueViewModel),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'materias_fab',
        onPressed: () => _showAddMateriaPrimaDialog(context),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildMateriasPrimasList(EstoqueViewModel viewModel) {
    final List<MateriaPrima> filteredMateriasPrimas = viewModel.materiasPrimas
        .where((mp) => mp.nome.toLowerCase().contains(_searchQuery))
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome)); // Ordenar por nome

    return filteredMateriasPrimas.isEmpty
        ? Center(
            child: Text(
              _searchQuery.isEmpty
                  ? 'Nenhuma materia-prima cadastrada'
                  : 'Nenhuma materia-prima encontrada',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          )
        : RefreshIndicator(
            onRefresh: () => viewModel.carregarDados(),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80), // Espaço para o FAB
              itemCount: filteredMateriasPrimas.length,
              itemBuilder: (context, index) {
                final materiaPrima = filteredMateriasPrimas[index];
                return _buildMateriaPrimaItem(materiaPrima, viewModel);
              },
            ),
          );
  }

  Widget _buildMateriaPrimaItem(
      MateriaPrima materiaPrima, EstoqueViewModel viewModel) {
    return Slidable(
      key: ValueKey(materiaPrima.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) =>
                _showEditMateriaPrimaDialog(context, materiaPrima),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Editar',
          ),
          SlidableAction(
            onPressed: (_) => _showDeleteConfirmationDialog(
              context,
              'Excluir materia-Prima',
              'Deseja realmente excluir a materia-prima "${materiaPrima.nome}"? Esta ação pode ser desfeita.',
              () => viewModel.excluirMateriaPrima(materiaPrima.id),
            ),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Excluir',
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
            child: Text(
              materiaPrima.nome.substring(0, 1).toUpperCase(),
              style: TextStyle(color: AppTheme.primaryDarkColor),
            ),
          ),
          title: Text(
            materiaPrima.nome,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            'Estoque: ${materiaPrima.estoqueAtual.toStringAsFixed(2)} ${materiaPrima.unidadeMedida}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: AppTheme.primaryDarkColor,
          ),
          onTap: () =>
              _showMateriaPrimaDetailsDialog(context, materiaPrima, viewModel),
        ),
      ),
    );
  }

  void _showAddMateriaPrimaDialog(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    String nome = '';
    String unidadeMedida = 'kg';
    double estoqueInicial = 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Matéria-Prima'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Ex: Milho',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, informe o nome';
                  }
                  return null;
                },
                onSaved: (value) => nome = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Estoque Inicial',
                  hintText: 'Ex: 0.0',
                  suffixText: 'unidade',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                initialValue: '0.0',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, informe o estoque inicial';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Por favor, informe um número válido';
                  }
                  return null;
                },
                onSaved: (value) => estoqueInicial = double.parse(value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Unidade de Medida',
                ),
                value: unidadeMedida,
                items: const [
                  DropdownMenuItem(value: 'kg', child: Text('Quilograma (kg)')),
                  DropdownMenuItem(value: 'g', child: Text('Grama (g)')),
                  DropdownMenuItem(value: 'L', child: Text('Litro (L)')),
                  DropdownMenuItem(value: 'mL', child: Text('Mililitro (mL)')),
                  DropdownMenuItem(value: 'ton', child: Text('Tonelada (ton)')),
                ],
                onChanged: (value) => unidadeMedida = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, selecione a unidade de medida';
                  }
                  return null;
                },
                onSaved: (value) => unidadeMedida = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();

                // Pegar o user_id do usuário autenticado
                final userId = Supabase.instance.client.auth.currentUser?.id;
                if (userId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Usuário não autenticado')),
                  );
                  return;
                }

                // Criar o mapa de dados para o Supabase
                final data = {
                  'user_id': userId,
                  'nome': nome,
                  'estoque_atual': estoqueInicial,
                  'unidade_medida': unidadeMedida,
                };

                try {
                  // Instanciar o SupabaseService diretamente aqui
                  final supabaseService = SupabaseService();
                  final success = await supabaseService.addMateriaPrima(data);
                  if (success) {
                    Provider.of<EstoqueViewModel>(context, listen: false)
                        .carregarDados();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Matéria-prima adicionada com sucesso')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Erro ao adicionar matéria-prima')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro: $e')),
                  );
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showEditMateriaPrimaDialog(
      BuildContext context, MateriaPrima materiaPrima) {
    final _formKey = GlobalKey<FormState>();
    String nome = materiaPrima.nome;
    String unidadeMedida = materiaPrima.unidadeMedida;
    double estoqueAtual = materiaPrima.estoqueAtual;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar materia-Prima'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Nome',
                ),
                initialValue: nome,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, informe o nome';
                  }
                  return null;
                },
                onSaved: (value) => nome = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Estoque Atual',
                  suffixText: 'unidade',
                ),
                initialValue: estoqueAtual.toString(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, informe o estoque atual';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Por favor, informe um número válido';
                  }
                  return null;
                },
                onSaved: (value) => estoqueAtual = double.parse(value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Unidade de Medida',
                ),
                value: unidadeMedida,
                items: const [
                  DropdownMenuItem(value: 'kg', child: Text('Quilograma (kg)')),
                  DropdownMenuItem(value: 'g', child: Text('Grama (g)')),
                  DropdownMenuItem(value: 'L', child: Text('Litro (L)')),
                  DropdownMenuItem(value: 'mL', child: Text('Mililitro (mL)')),
                  DropdownMenuItem(value: 'ton', child: Text('Tonelada (ton)')),
                ],
                onChanged: (value) => unidadeMedida = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, selecione a unidade de medida';
                  }
                  return null;
                },
                onSaved: (value) => unidadeMedida = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                Provider.of<EstoqueViewModel>(context, listen: false)
                    .atualizarMateriaPrima(
                  id: int.parse(materiaPrima.id),
                  nome: nome,
                  estoqueAtual: estoqueAtual,
                  unidadeMedida: unidadeMedida,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('materia-prima atualizada com sucesso')),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showMateriaPrimaDetailsDialog(BuildContext context,
      MateriaPrima materiaPrima, EstoqueViewModel viewModel) {
    final lotes = viewModel.getLotesPorMateriaPrima(materiaPrima.id);
    final movimentacoes =
        viewModel.getMovimentacoesPorMateriaPrima(materiaPrima.id);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(
                        materiaPrima.nome.substring(0, 1).toUpperCase(),
                        style: TextStyle(color: AppTheme.primaryDarkColor),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            materiaPrima.nome,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Unidade: ${materiaPrima.unidadeMedida}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Estoque Atual: ',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${materiaPrima.estoqueAtual.toStringAsFixed(2)} ${materiaPrima.unidadeMedida}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: materiaPrima.estoqueAtual <= 0
                                ? Colors.red
                                : Colors.green,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: Colors.black,
                        tabs: const [
                          Tab(text: 'Lotes'),
                          Tab(text: 'movimentações'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Lotes Tab
                            lotes.isEmpty
                                ? const Center(
                                    child: Text('Nenhum lote encontrado'))
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: lotes.length,
                                    itemBuilder: (context, index) {
                                      final lote = lotes[index];
                                      final fornecedor =
                                          viewModel.getFornecedorPorId(
                                              lote.fornecedorId);

                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          title:
                                              Text('Lote: ${lote.numeroLote}'),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  'Fornecedor: ${fornecedor?.nome ?? 'Desconhecido'}'),
                                              Text(
                                                  'Recebido em: ${lote.dataRecebimento.toString().substring(0, 10)}'),
                                            ],
                                          ),
                                          trailing: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Atual:',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                              Text(
                                                '${lote.quantidadeAtual.toStringAsFixed(2)} ${materiaPrima.unidadeMedida}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      lote.quantidadeAtual <= 0
                                                          ? Colors.red
                                                          : Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                            // Movimentações Tab
                            movimentacoes.isEmpty
                                ? const Center(
                                    child:
                                        Text('Nenhuma movimentação encontrada'))
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: movimentacoes.length,
                                    itemBuilder: (context, index) {
                                      final movimentacao = movimentacoes[index];

                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: movimentacao
                                                        .tipo ==
                                                    TipoMovimentacao.entrada
                                                ? Colors.green.withOpacity(0.2)
                                                : Colors.red.withOpacity(0.2),
                                            child: Icon(
                                              movimentacao.tipo ==
                                                      TipoMovimentacao.entrada
                                                  ? Icons.arrow_downward
                                                  : Icons.arrow_upward,
                                              color: movimentacao.tipo ==
                                                      TipoMovimentacao.entrada
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                          title: Text(
                                            movimentacao.tipo ==
                                                    TipoMovimentacao.entrada
                                                ? 'Entrada de ${movimentacao.quantidade.toStringAsFixed(2)} ${materiaPrima.unidadeMedida}'
                                                : 'saida de ${movimentacao.quantidade.toStringAsFixed(2)} ${materiaPrima.unidadeMedida}',
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(movimentacao.motivo),
                                              Text(
                                                  'Data: ${movimentacao.data.toString().substring(0, 16)}'),
                                            ],
                                          ),
                                          isThreeLine: true,
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditMateriaPrimaDialog(context, materiaPrima);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAjusteEstoqueDialog(context, materiaPrima);
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Ajustar Estoque'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAjusteEstoqueDialog(
      BuildContext context, MateriaPrima materiaPrima) {
    final _formKey = GlobalKey<FormState>();
    double novaQuantidade = materiaPrima.estoqueAtual;
    String motivo = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajustar Estoque'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                materiaPrima.nome,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Estoque Atual: ',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '${materiaPrima.estoqueAtual.toStringAsFixed(2)} ${materiaPrima.unidadeMedida}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Nova Quantidade',
                  suffixText: materiaPrima.unidadeMedida,
                ),
                initialValue: novaQuantidade.toString(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, informe a quantidade';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Por favor, informe um numero valido';
                  }
                  return null;
                },
                onSaved: (value) => novaQuantidade = double.parse(value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Motivo do Ajuste',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, informe o motivo';
                  }
                  return null;
                },
                onSaved: (value) => motivo = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                Provider.of<EstoqueViewModel>(context, listen: false)
                    .ajustarEstoque(
                  materiaPrimaId: int.parse(materiaPrima.id),
                  novaQuantidade: novaQuantidade,
                  motivo: motivo,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Estoque ajustado com sucesso')),
                );
              }
            },
            child: const Text('Ajustar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('materia-prima excluída com sucesso')),
              );
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
