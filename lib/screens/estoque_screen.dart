import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../theme/app_theme.dart';
import '../models/materia_prima.dart';
import '../models/lote.dart';
import '../models/movimentacao.dart';
import '../viewmodels/estoque_viewmodel.dart';

class EstoqueScreen extends StatefulWidget {
  const EstoqueScreen({Key? key}) : super(key: key);

  @override
  State<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends State<EstoqueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    // Garantir que os dados sejam carregados ao iniciar a tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EstoqueViewModel>(context, listen: false).carregarDados();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        title: const Text('Gestão de Estoque'),
        backgroundColor: Theme.of(context).primaryColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: 'Matérias-Primas'),
            Tab(text: 'Lotes'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (estoqueViewModel.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.red.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      estoqueViewModel.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => estoqueViewModel.clearError(),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar...',
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
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMateriasPrimasTab(estoqueViewModel),
                      _buildLotesTab(estoqueViewModel),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'estoque_fab',
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddMateriaPrimaDialog(context);
          } else {
            _showAddLoteDialog(context);
          }
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildMateriasPrimasTab(EstoqueViewModel viewModel) {
    final List<MateriaPrima> filteredMateriasPrimas = viewModel.materiasPrimas
        .where((mp) => mp.nome.toLowerCase().contains(_searchQuery))
        .toList();

    return filteredMateriasPrimas.isEmpty
        ? Center(
            child: Text(
              _searchQuery.isEmpty
                  ? 'Nenhuma matéria-prima cadastrada'
                  : 'Nenhuma matéria-prima encontrada',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          )
        : RefreshIndicator(
            onRefresh: () => viewModel.carregarDados(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: filteredMateriasPrimas.length,
              itemBuilder: (context, index) {
                final materiaPrima = filteredMateriasPrimas[index];
                return _buildMateriaPrimaCard(materiaPrima, viewModel);
              },
            ),
          );
  }

  Widget _buildMateriaPrimaCard(
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
            onPressed: (_) => _showAjusteEstoqueDialog(context, materiaPrima),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            icon: Icons.settings,
            label: 'Ajustar',
          ),
          SlidableAction(
            onPressed: (_) => _showDeleteConfirmationDialog(
              context,
              'Excluir Matéria-Prima',
              'Deseja realmente excluir a matéria-prima "${materiaPrima.nome}"? Esta ação não pode ser desfeita.',
              () async {
                final success = await viewModel
                    .deletarMateriaPrima(int.parse(materiaPrima.id));
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Matéria-prima excluída com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
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
        child: InkWell(
          onTap: () =>
              _showMateriaPrimaDetailsDialog(context, materiaPrima, viewModel),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: materiaPrima.estoqueAtual <= 0
                        ? AppTheme.errorColor.withOpacity(0.2)
                        : materiaPrima.estoqueAtual < 100
                            ? AppTheme.warningColor.withOpacity(0.2)
                            : AppTheme.successColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.inventory,
                      size: 28,
                      color: materiaPrima.estoqueAtual <= 0
                          ? AppTheme.errorColor
                          : materiaPrima.estoqueAtual < 100
                              ? AppTheme.warningColor
                              : AppTheme.successColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        materiaPrima.nome,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Unidade: ${materiaPrima.unidadeMedida}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Estoque Atual',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${materiaPrima.estoqueAtual.toStringAsFixed(2)} ${materiaPrima.unidadeMedida}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: materiaPrima.estoqueAtual <= 0
                                ? AppTheme.errorColor
                                : materiaPrima.estoqueAtual < 100
                                    ? AppTheme.warningColor
                                    : AppTheme.successColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLotesTab(EstoqueViewModel viewModel) {
    final List<Lote> filteredLotes = viewModel.lotes.where((lote) {
      final materiaPrima = viewModel.getMateriaPrimaPorId(lote.materiaPrimaId);
      if (materiaPrima == null) return false;

      return materiaPrima.nome.toLowerCase().contains(_searchQuery) ||
          lote.numeroLote.toLowerCase().contains(_searchQuery);
    }).toList();

    filteredLotes
        .sort((a, b) => b.dataRecebimento.compareTo(a.dataRecebimento));

    return filteredLotes.isEmpty
        ? Center(
            child: Text(
              _searchQuery.isEmpty
                  ? 'Nenhum lote cadastrado'
                  : 'Nenhum lote encontrado',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          )
        : RefreshIndicator(
            onRefresh: () => viewModel.carregarDados(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: filteredLotes.length,
              itemBuilder: (context, index) {
                final lote = filteredLotes[index];
                return _buildLoteCard(lote, viewModel);
              },
            ),
          );
  }

  Widget _buildLoteCard(Lote lote, EstoqueViewModel viewModel) {
    final materiaPrima = viewModel.getMateriaPrimaPorId(lote.materiaPrimaId);
    final fornecedor = viewModel.getFornecedorPorId(lote.fornecedorId);

    if (materiaPrima == null) return const SizedBox.shrink();

    return Slidable(
      key: ValueKey(lote.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _showEditLoteDialog(context, lote, viewModel),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Editar',
          ),
          SlidableAction(
            onPressed: (_) => _showDeleteConfirmationDialog(
              context,
              'Excluir Lote',
              'Deseja realmente excluir o lote "${lote.numeroLote}"? Esta ação não pode ser desfeita.',
              () async {
                final success = await viewModel.deletarLote(int.parse(lote.id));
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lote excluído com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          materiaPrima.nome,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Lote: ${lote.numeroLote}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Quantidade Recebida',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${lote.quantidadeRecebida.toStringAsFixed(2)} ${materiaPrima.unidadeMedida}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: lote.quantidadeRecebida <= 0
                                      ? AppTheme.errorColor
                                      : AppTheme.successColor,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Fornecedor: ${fornecedor?.nome ?? 'Desconhecido'}',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Recebido: ${DateFormat('dd/MM/yyyy').format(lote.dataRecebimento)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMateriaPrimaDialog(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    String nome = '';
    String unidadeMedida = 'kg';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
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
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Unidade de Medida',
                      ),
                      value: unidadeMedida,
                      items: const [
                        DropdownMenuItem(
                            value: 'kg', child: Text('Quilograma (kg)')),
                        DropdownMenuItem(value: 'g', child: Text('Grama (g)')),
                        DropdownMenuItem(value: 'L', child: Text('Litro (L)')),
                        DropdownMenuItem(
                            value: 'mL', child: Text('Mililitro (mL)')),
                        DropdownMenuItem(
                            value: 'ton', child: Text('Tonelada (ton)')),
                      ],
                      onChanged: (value) =>
                          setState(() => unidadeMedida = value!),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, selecione a unidade de medida';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            setState(() => isSaving = true);
                            final viewModel = Provider.of<EstoqueViewModel>(
                                context,
                                listen: false);
                            final success =
                                await viewModel.adicionarMateriaPrima(
                              nome: nome,
                              estoqueAtual: 0,
                              unidadeMedida: unidadeMedida,
                            );
                            setState(() => isSaving = false);
                            Navigator.pop(context);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Matéria-prima adicionada com sucesso!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditMateriaPrimaDialog(
      BuildContext context, MateriaPrima materiaPrima) {
    final _formKey = GlobalKey<FormState>();
    String nome = materiaPrima.nome;
    String unidadeMedida = materiaPrima.unidadeMedida;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Editar Matéria-Prima'),
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
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Unidade de Medida',
                      ),
                      value: unidadeMedida,
                      items: const [
                        DropdownMenuItem(
                            value: 'kg', child: Text('Quilograma (kg)')),
                        DropdownMenuItem(value: 'g', child: Text('Grama (g)')),
                        DropdownMenuItem(value: 'L', child: Text('Litro (L)')),
                        DropdownMenuItem(
                            value: 'mL', child: Text('Mililitro (mL)')),
                        DropdownMenuItem(
                            value: 'ton', child: Text('Tonelada (ton)')),
                      ],
                      onChanged: (value) =>
                          setState(() => unidadeMedida = value!),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, selecione a unidade de medida';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            setState(() => isSaving = true);
                            final viewModel = Provider.of<EstoqueViewModel>(
                                context,
                                listen: false);
                            final success =
                                await viewModel.atualizarMateriaPrima(
                              id: int.parse(materiaPrima.id),
                              nome: nome,
                              estoqueAtual: materiaPrima.estoqueAtual,
                              unidadeMedida: unidadeMedida,
                            );
                            setState(() => isSaving = false);
                            Navigator.pop(context);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Matéria-prima atualizada com sucesso!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAjusteEstoqueDialog(
      BuildContext context, MateriaPrima materiaPrima) {
    final _formKey = GlobalKey<FormState>();
    double novaQuantidade = materiaPrima.estoqueAtual;
    String motivo = '';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
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
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
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
                          return 'Por favor, informe um número válido';
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
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            setState(() => isSaving = true);
                            final viewModel = Provider.of<EstoqueViewModel>(
                                context,
                                listen: false);
                            final success = await viewModel.ajustarEstoque(
                              materiaPrimaId: int.parse(materiaPrima.id),
                              novaQuantidade: novaQuantidade,
                              motivo: motivo,
                            );
                            setState(() => isSaving = false);
                            Navigator.pop(context);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Estoque ajustado com sucesso!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Ajustar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddLoteDialog(BuildContext context) {
    final viewModel = Provider.of<EstoqueViewModel>(context, listen: false);
    final _formKey = GlobalKey<FormState>();
    String materiaPrimaId = '';
    String fornecedorId = '';
    String numeroLote = '';
    double quantidade = 0;
    bool isSaving = false;

    if (viewModel.materiasPrimas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Cadastre uma matéria-prima antes de adicionar um lote'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (viewModel.fornecedores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre um fornecedor antes de adicionar um lote'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    materiaPrimaId = viewModel.materiasPrimas.first.id;
    fornecedorId = viewModel.fornecedores.first.id;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Adicionar Lote'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Matéria-Prima',
                        ),
                        value: materiaPrimaId,
                        items: viewModel.materiasPrimas.map((mp) {
                          return DropdownMenuItem<String>(
                            value: mp.id,
                            child:
                                Text(mp.nome, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => materiaPrimaId = value!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Fornecedor',
                        ),
                        value: fornecedorId,
                        items: viewModel.fornecedores.map((f) {
                          return DropdownMenuItem<String>(
                            value: f.id,
                            child: Text(f.nome ?? 'Desconhecido',
                                overflow:
                                    TextOverflow.ellipsis), // Corrigido aqui
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => fornecedorId = value!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Número do Lote',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, informe o número do lote';
                          }
                          return null;
                        },
                        onSaved: (value) => numeroLote = value!,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Quantidade Recebida',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, informe a quantidade';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Por favor, informe um número válido';
                          }
                          if (double.parse(value) <= 0) {
                            return 'A quantidade deve ser maior que zero';
                          }
                          return null;
                        },
                        onSaved: (value) => quantidade = double.parse(value!),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            setState(() => isSaving = true);
                            final success = await viewModel.adicionarLote(
                              materiaPrimaId: int.parse(materiaPrimaId),
                              fornecedorId: int.parse(fornecedorId),
                              numeroLote: numeroLote,
                              quantidade: quantidade,
                            );
                            setState(() => isSaving = false);
                            Navigator.pop(context);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Lote adicionado com sucesso!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditLoteDialog(
      BuildContext context, Lote lote, EstoqueViewModel viewModel) {
    final _formKey = GlobalKey<FormState>();
    String materiaPrimaId = lote.materiaPrimaId;
    String fornecedorId = lote.fornecedorId;
    String numeroLote = lote.numeroLote;
    double quantidadeAtual = lote.quantidadeAtual;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Editar Lote'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Matéria-Prima',
                        ),
                        value: materiaPrimaId,
                        items: viewModel.materiasPrimas.map((mp) {
                          return DropdownMenuItem<String>(
                            value: mp.id,
                            child:
                                Text(mp.nome, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => materiaPrimaId = value!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Fornecedor',
                        ),
                        value: fornecedorId,
                        items: viewModel.fornecedores.map((f) {
                          return DropdownMenuItem<String>(
                            value: f.id,
                            child: Text(f.nome ?? 'Desconhecido',
                                overflow:
                                    TextOverflow.ellipsis), // Corrigido aqui
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => fornecedorId = value!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Número do Lote',
                        ),
                        initialValue: numeroLote,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, informe o número do lote';
                          }
                          return null;
                        },
                        onSaved: (value) => numeroLote = value!,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Quantidade Atual',
                        ),
                        initialValue: quantidadeAtual.toString(),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, informe a quantidade';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Por favor, informe um número válido';
                          }
                          if (double.parse(value) < 0) {
                            return 'A quantidade não pode ser negativa';
                          }
                          return null;
                        },
                        onSaved: (value) =>
                            quantidadeAtual = double.parse(value!),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            setState(() => isSaving = true);
                            final success = await viewModel.atualizarLote(
                              id: int.parse(lote.id),
                              materiaPrimaId: int.parse(materiaPrimaId),
                              fornecedorId: int.parse(fornecedorId),
                              numeroLote: numeroLote,
                              quantidadeAtual: quantidadeAtual,
                              quantidadeRecebida: lote.quantidadeRecebida,
                              dataRecebimento: lote.dataRecebimento,
                            );
                            setState(() => isSaving = false);
                            Navigator.pop(context);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Lote atualizado com sucesso!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
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
                      child: Icon(Icons.inventory,
                          color: AppTheme.primaryDarkColor),
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
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Estoque: ${materiaPrima.estoqueAtual.toStringAsFixed(2)} ${materiaPrima.unidadeMedida}',
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
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: Colors.black,
                        tabs: const [
                          Tab(text: 'Lotes'),
                          Tab(text: 'Movimentações'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
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
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'Lote: ${lote.numeroLote}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${lote.quantidadeRecebida.toStringAsFixed(2)} ${materiaPrima.unidadeMedida}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: lote.quantidadeRecebida <=
                                                                  0
                                                              ? AppTheme
                                                                  .errorColor
                                                              : AppTheme
                                                                  .successColor,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'Fornecedor: ${fornecedor?.nome ?? 'Desconhecido'}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Recebido: ${DateFormat('dd/MM/yyyy').format(lote.dataRecebimento)}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Quantidade inicial: ${lote.quantidadeRecebida.toStringAsFixed(2)} ${materiaPrima.unidadeMedida}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
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
                                                : 'Saída de ${movimentacao.quantidade.toStringAsFixed(2)} ${materiaPrima.unidadeMedida}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Motivo: ${movimentacao.motivo}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                              ),
                                              Text(
                                                'Data: ${DateFormat('dd/MM/yyyy HH:mm').format(movimentacao.data)}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
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
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, String title,
      String message, VoidCallback onConfirm) {
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
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
