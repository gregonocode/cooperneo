import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../theme/app_theme.dart';
import '../models/fornecedor.dart';
import '../viewmodels/estoque_viewmodel.dart';

class FornecedoresScreen extends StatefulWidget {
  const FornecedoresScreen({Key? key}) : super(key: key);

  @override
  State<FornecedoresScreen> createState() => _FornecedoresScreenState();
}

class _FornecedoresScreenState extends State<FornecedoresScreen> {
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
      appBar: AppBar(title: const Text('Fornecedores')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar fornecedor...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                suffixIcon:
                    _searchQuery.isNotEmpty
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
            child:
                estoqueViewModel.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildFornecedoresList(estoqueViewModel),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fornecedores_fab',
        onPressed: () => _showAddFornecedorDialog(context),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildFornecedoresList(EstoqueViewModel viewModel) {
    final List<Fornecedor> filteredFornecedores =
        viewModel.fornecedores
            .where(
              (f) =>
                  (f.nome.toLowerCase() ?? '').contains(_searchQuery) ||
                  (f.contato.toLowerCase() ?? '').contains(_searchQuery) ||
                  (f.endereco.toLowerCase() ?? '').contains(_searchQuery),
            )
            .toList()
          ..sort(
            (a, b) => (a.nome ?? '').compareTo(b.nome ?? ''),
          ); // Ordenar por nome

    return filteredFornecedores.isEmpty
        ? Center(
          child: Text(
            _searchQuery.isEmpty
                ? 'Nenhum fornecedor cadastrado'
                : 'Nenhum fornecedor encontrado',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        )
        : RefreshIndicator(
          onRefresh: () => viewModel.carregarDados(),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // Espaço para o FAB
            itemCount: filteredFornecedores.length,
            itemBuilder: (context, index) {
              final fornecedor = filteredFornecedores[index];
              return _buildFornecedorItem(fornecedor, viewModel);
            },
          ),
        );
  }

  Widget _buildFornecedorItem(
    Fornecedor fornecedor,
    EstoqueViewModel viewModel,
  ) {
    return Slidable(
      key: ValueKey(fornecedor.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _showEditFornecedorDialog(context, fornecedor),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Editar',
          ),
          SlidableAction(
            onPressed:
                (_) => _showDeleteConfirmationDialog(
                  context,
                  'Excluir Fornecedor',
                  'Deseja realmente excluir o fornecedor "${fornecedor.nome ?? 'Desconhecido'}"? Esta ação não pode ser desfeita.',
                  () => viewModel.excluirFornecedor(fornecedor.id),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
            child: Icon(Icons.business, color: AppTheme.primaryDarkColor),
          ),
          title: Text(
            fornecedor.nome ?? 'Desconhecido',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(
            'Contato: ${fornecedor.contato ?? 'Não informado'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          trailing: Icon(Icons.chevron_right, color: AppTheme.primaryDarkColor),
          onTap: () => _showFornecedorDetailsDialog(context, fornecedor),
        ),
      ),
    );
  }

  void _showAddFornecedorDialog(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    String nome = '';
    String contato = '';
    String endereco = '';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Adicionar Fornecedor'),
            content: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        hintText: 'Ex: Cooperativa Central',
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
                        labelText: 'Contato',
                        hintText: 'Ex: (11) 99999-9999',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, informe o contato';
                        }
                        return null;
                      },
                      onSaved: (value) => contato = value!,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Endereço',
                        hintText: 'Ex: Rua Principal, 123',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, informe o endereço';
                        }
                        return null;
                      },
                      onSaved: (value) => endereco = value!,
                    ),
                  ],
                ),
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
                    final viewModel = Provider.of<EstoqueViewModel>(
                      context,
                      listen: false,
                    );
                    final success = await viewModel.adicionarFornecedor(
                      nome: nome,
                      contato: contato,
                      endereco: endereco,
                    );
                    Navigator.pop(context);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fornecedor adicionado com sucesso'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            viewModel.errorMessage ??
                                'Erro ao adicionar fornecedor',
                          ),
                          backgroundColor: Colors.red,
                        ),
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

  void _showEditFornecedorDialog(BuildContext context, Fornecedor fornecedor) {
    final _formKey = GlobalKey<FormState>();
    String nome = fornecedor.nome ?? '';
    String contato = fornecedor.contato ?? '';
    String endereco = fornecedor.endereco ?? '';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Editar Fornecedor'),
            content: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Nome'),
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
                      decoration: const InputDecoration(labelText: 'Contato'),
                      initialValue: contato,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, informe o contato';
                        }
                        return null;
                      },
                      onSaved: (value) => contato = value!,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Endereço'),
                      initialValue: endereco,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, informe o endereço';
                        }
                        return null;
                      },
                      onSaved: (value) => endereco = value!,
                    ),
                  ],
                ),
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
                    final viewModel = Provider.of<EstoqueViewModel>(
                      context,
                      listen: false,
                    );
                    final success = await viewModel.atualizarFornecedor(
                      id: int.parse(fornecedor.id),
                      nome: nome,
                      contato: contato,
                      endereco: endereco,
                    );
                    Navigator.pop(context);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fornecedor atualizado com sucesso'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            viewModel.errorMessage ??
                                'Erro ao atualizar fornecedor',
                          ),
                          backgroundColor: Colors.red,
                        ),
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

  void _showFornecedorDetailsDialog(
    BuildContext context,
    Fornecedor fornecedor,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                        radius: 30,
                        child: Icon(
                          Icons.business,
                          color: AppTheme.primaryDarkColor,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fornecedor.nome ?? 'Desconhecido',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Detalhes do Fornecedor',
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
                  const SizedBox(height: 24),
                  _buildDetailItem(
                    icon: Icons.phone,
                    title: 'Contato',
                    value: fornecedor.contato,
                  ),
                  const Divider(),
                  _buildDetailItem(
                    icon: Icons.location_on,
                    title: 'Endereço',
                    value: fornecedor.endereco,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditFornecedorDialog(context, fornecedor);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Editar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showDeleteConfirmationDialog(
                            context,
                            'Excluir Fornecedor',
                            'Deseja realmente excluir o fornecedor "${fornecedor.nome ?? 'Desconhecido'}"? Esta ação não pode ser desfeita.',
                            () => Provider.of<EstoqueViewModel>(
                              context,
                              listen: false,
                            ).excluirFornecedor(fornecedor.id),
                          );
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Excluir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String? value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryDarkColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value ?? 'Não informado',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
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
      builder:
          (context) => AlertDialog(
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
                      content: Text('Fornecedor excluído com sucesso'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Excluir'),
              ),
            ],
          ),
    );
  }
}
