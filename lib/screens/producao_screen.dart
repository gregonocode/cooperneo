import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../models/formula.dart';
import '../models/producao.dart';
import '../models/componente_formula.dart'; // Reintroduzindo a importação direta
import '../viewmodels/producao_viewmodel.dart';
import '../viewmodels/estoque_viewmodel.dart';

class ProducaoScreen extends StatefulWidget {
  const ProducaoScreen({Key? key}) : super(key: key);

  @override
  State<ProducaoScreen> createState() => _ProducaoScreenState();
}

class _ProducaoScreenState extends State<ProducaoScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);

    // Atualizar dados
    Future.microtask(() {
      Provider.of<ProducaoViewModel>(context, listen: false).carregarDados();
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
    final producaoViewModel = Provider.of<ProducaoViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produção de Rações'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: 'Produções'),
            Tab(text: 'Fórmulas'),
          ],
        ),
        actions: [
          if (_tabController.index == 0)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'excluir_todas') {
                  _showExcluirTodasProducoesDialog(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'excluir_todas',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: 8),
                      Text("Excluir Todas as Produções"),
                    ],
                  ),
                ),
              ],
            )
          else
            const SizedBox.shrink(), // garante que sempre retorne um widget
        ],
      ),
      body: Column(
        children: [
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
            child: producaoViewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProducoesTab(producaoViewModel),
                      _buildFormulasTab(producaoViewModel),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'producao_fab',
        onPressed: () {
          if (_tabController.index == 0) {
            _showNovaProducaoDialog(context);
          } else {
            _showAddFormulaDialog(context);
          }
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildProducoesTab(ProducaoViewModel viewModel) {
    // Filtrar produções
    final List<Producao> producoes = viewModel.producoes.where((p) {
      final formula = viewModel.getFormulaPorId(p.formulaId);
      if (formula == null) return false;

      return formula.nome.toLowerCase().contains(_searchQuery) ||
          p.loteProducao.toLowerCase().contains(_searchQuery);
    }).toList()
      ..sort((a, b) => b.dataProducao.compareTo(a.dataProducao));

    return producoes.isEmpty
        ? Center(
            child: Text(
              _searchQuery.isEmpty
                  ? 'Nenhuma produção registrada'
                  : 'Nenhuma produção encontrada',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          )
        : RefreshIndicator(
            onRefresh: () => viewModel.carregarDados(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: producoes.length,
              itemBuilder: (context, index) {
                final producao = producoes[index];
                return _buildProducaoCard(producao, viewModel);
              },
            ),
          );
  }

  Widget _buildProducaoCard(Producao producao, ProducaoViewModel viewModel) {
    final formula = viewModel.getFormulaPorId(producao.formulaId);

    if (formula == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () =>
            _showProducaoDetailsDialog(context, producao, formula, viewModel),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      formula.nome,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${producao.quantidadeProduzida.toStringAsFixed(2)} btd',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lote: ${producao.loteProducao}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(producao.dataProducao),
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

  Widget _buildFormulasTab(ProducaoViewModel viewModel) {
    // Filtrar fórmulas
    final List<Formula> formulas = viewModel.formulas
        .where((f) =>
            f.nome.toLowerCase().contains(_searchQuery) ||
            (f.descricao?.toLowerCase() ?? '').contains(_searchQuery))
        .toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));

    return formulas.isEmpty
        ? Center(
            child: Text(
              _searchQuery.isEmpty
                  ? 'Nenhuma fórmula cadastrada'
                  : 'Nenhuma fórmula encontrada',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          )
        : RefreshIndicator(
            onRefresh: () => viewModel.carregarDados(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: formulas.length,
              itemBuilder: (context, index) {
                final formula = formulas[index];
                return _buildFormulaCard(formula, viewModel);
              },
            ),
          );
  }

  Widget _buildFormulaCard(Formula formula, ProducaoViewModel viewModel) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showFormulaDetailsDialog(context, formula, viewModel),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                    child: Text(
                      formula.nome.substring(0, 1).toUpperCase(),
                      style: TextStyle(color: AppTheme.primaryDarkColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formula.nome,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${formula.componentes.length} componentes',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showNovaProducaoDialog(context,
                        formulaPreSelecionada: formula.id),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Produzir'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProducaoDetailsDialog(BuildContext context, Producao producao,
      Formula formula, ProducaoViewModel viewModel) {
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
                      child: Icon(Icons.precision_manufacturing,
                          color: AppTheme.primaryDarkColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Produção de ${formula.nome}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Lote: ${producao.loteProducao}',
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
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
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildInfoSection(
                      title: 'Informações Gerais',
                      children: [
                        _buildInfoRow('Quantidade Produzida',
                            '${producao.quantidadeProduzida.toStringAsFixed(2)} btd'),
                        _buildInfoRow(
                            'Data de Produção',
                            DateFormat('dd/MM/yyyy HH:mm')
                                .format(producao.dataProducao)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildInfoSection(
                      title: 'Matérias-Primas Utilizadas',
                      children:
                          producao.materiaPrimaConsumida.entries.map((entry) {
                        final materiaPrima =
                            viewModel.getMateriaPrimaPorId(entry.key);
                        if (materiaPrima == null)
                          return const SizedBox.shrink();

                        return _buildInfoRow(
                          materiaPrima.nome,
                          '${entry.value.toStringAsFixed(2)} ${materiaPrima.unidadeMedida}',
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    _buildInfoSection(
                      title: 'Fórmula',
                      children: [
                        _buildInfoRow('Nome', formula.nome),
                        if (formula.descricao?.isNotEmpty ?? false)
                          _buildInfoRow('Descrição', formula.descricao ?? ''),
                        const SizedBox(height: 8),
                        const Text('Componentes:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        ...formula.componentes.map((c) {
                          final mp =
                              viewModel.getMateriaPrimaPorId(c.materiaPrimaId);
                          if (mp == null) return const SizedBox.shrink();

                          return Padding(
                            padding: const EdgeInsets.only(
                                left: 8.0, top: 4, bottom: 4),
                            child: _buildInfoRow(
                              mp.nome,
                              '${c.quantidade.toStringAsFixed(2)} ${c.unidadeMedida}',
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              ),
              // Adicionando o rodapé com os botões
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // EDITAR (azul)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // fecha o dialog de detalhes
                          _showEditarProducaoDialog(context, producao);
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Editar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // EXCLUIR E REVERTER ESTOQUE (vermelho)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showDeleteConfirmationDialog(
                            context,
                            'Excluir e reverter estoque',
                            'Esta ação vai excluir a produção do lote "${producao.loteProducao}" '
                            'e DEVOLVER todo o consumo aos lotes e às matérias-primas. '
                            'Tem certeza que deseja continuar?',
                            () => viewModel.excluirProducao(producao.id),
                            viewModel: viewModel,
                            entityType: 'producao',
                          );
                        },
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Excluir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // FECHAR (neutro)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fechar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
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

// Função para exibir o diálogo de confirmação de exclusão
  void _showDeleteConfirmationDialog(
    BuildContext context,
    String title,
    String message,
    Future<bool> Function() onConfirm, {
    required ProducaoViewModel viewModel,
    required String entityType, // 'producao' ou 'formula'
  }) {
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
            onPressed: () async {
              print('Confirmando exclusão: entityType=$entityType');
              Navigator.pop(context); // Fecha o diálogo de confirmação
              final success = await onConfirm();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? entityType == 'producao'
                            ? 'Produção excluída com sucesso'
                            : 'Fórmula excluída com sucesso'
                        : viewModel.errorMessage ??
                            'Erro ao excluir ${entityType == 'producao' ? 'produção' : 'fórmula'}',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
              print('Exclusão: success=$success, entityType=$entityType');
              if (success && entityType == 'producao') {
                Navigator.pop(context); // Fecha o modal de detalhes
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

// Funções auxiliares (supondo que já existam no seu código)
  Widget _buildInfoSection(
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  void _showFormulaDetailsDialog(
      BuildContext context, Formula formula, ProducaoViewModel viewModel) {
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
                      child: Icon(Icons.receipt_long,
                          color: AppTheme.primaryDarkColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formula.nome,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (formula.descricao?.isNotEmpty ?? false)
                            Text(
                              formula.descricao ?? '',
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Componentes da Fórmula',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 16),
                            ...formula.componentes.map((componente) {
                              final mp = viewModel.getMateriaPrimaPorId(
                                  componente.materiaPrimaId);
                              if (mp == null) return const SizedBox.shrink();

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        mp.nome,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${componente.quantidade.toStringAsFixed(2)} ${componente.unidadeMedida}',
                                        textAlign: TextAlign.end,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditFormulaDialog(context, formula);
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Editar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            _showDeleteConfirmationDialog(
                              context,
                              'Excluir Fórmula',
                              'Deseja realmente excluir a fórmula "${formula.nome}"? Esta ação não pode ser desfeita.',
                              () => viewModel.excluirFormula(formula.id),
                              viewModel: viewModel,
                              entityType: 'formula',
                            );
                          },
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text('Excluir'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showNovaProducaoDialog(context,
                          formulaPreSelecionada: formula.id);
                    },
                    icon: const Icon(Icons.add_circle, size: 20),
                    label: const Text('Produzir com esta Fórmula'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNovaProducaoDialog(BuildContext context,
      {String? formulaPreSelecionada}) {
    final producaoViewModel =
        Provider.of<ProducaoViewModel>(context, listen: false);
    final _formKey = GlobalKey<FormState>();
    String formulaId = formulaPreSelecionada ??
        (producaoViewModel.formulas.isNotEmpty
            ? producaoViewModel.formulas.first.id
            : '');
    String loteProducao = '';
    double quantidade = 0;
    double? _simulacaoQuantidade;

    if (producaoViewModel.formulas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre uma fórmula antes de registrar produção'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setState) {
            final formula = producaoViewModel.getFormulaPorId(formulaId);
            final Map<String, double> disponibilidade =
                _simulacaoQuantidade != null && formula != null
                    ? producaoViewModel.verificarDisponibilidadeProducao(
                        formulaId, _simulacaoQuantidade!)
                    : {};

            return AlertDialog(
              title: const Text('Nova Produção'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Fórmula'),
                        value: formulaId,
                        items: producaoViewModel.formulas.map((f) {
                          return DropdownMenuItem<String>(
                            value: f.id,
                            child:
                                Text(f.nome, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            formulaId = value ?? '';
                            _simulacaoQuantidade = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                            labelText: 'Lote de Produção'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, informe o lote';
                          }
                          return null;
                        },
                        onSaved: (value) => loteProducao = value ?? '',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                            labelText: 'Quantidade a Produzir (btd)'),
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
                        onChanged: (value) {
                          final valorNumerico = double.tryParse(value);
                          setState(() {
                            _simulacaoQuantidade =
                                valorNumerico != null && valorNumerico > 0
                                    ? valorNumerico
                                    : null;
                          });
                        },
                      ),
                      if (_simulacaoQuantidade != null && formula != null) ...[
                        const SizedBox(height: 24),
                        Text('Previsão de Consumo',
                            style:
                                Theme.of(builderContext).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        ...disponibilidade.entries.map((entry) {
                          final bool disponivel = entry.value >= 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(entry.key,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Text(
                                  disponivel
                                      ? 'OK (${entry.value.toStringAsFixed(2)})'
                                      : 'Falta ${(-entry.value).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color:
                                        disponivel ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (disponibilidade.values.any((v) => v < 0))
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: const Text(
                              'Estoque insuficiente para produção',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(builderContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      Navigator.pop(builderContext); // Fecha o formulário

                      // Mostrar diálogo de carregamento
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (loadingContext) => const AlertDialog(
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Processando produção...'),
                            ],
                          ),
                        ),
                      );

                      // Registrar produção
                      final success = await producaoViewModel.registrarProducao(
                          formulaId, quantidade, loteProducao);
                      Navigator.of(context, rootNavigator: true)
                          .pop(); // Fecha o diálogo de carregamento
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Produção registrada com sucesso'
                                : producaoViewModel.errorMessage ??
                                    'Erro ao registrar produção',
                          ),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Produzir'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddFormulaDialog(BuildContext context) {
    final producaoViewModel =
        Provider.of<ProducaoViewModel>(context, listen: false);
    final estoqueViewModel =
        Provider.of<EstoqueViewModel>(context, listen: false);
    final _formKey = GlobalKey<FormState>();
    String nome = '';
    List<ComponenteFormula> componentes = [];

    // Verificar se há matérias-primas cadastradas
    if (estoqueViewModel.materiasPrimas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre matérias-primas antes de criar uma fórmula'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nova Fórmula'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Nome da Fórmula',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, informe o nome';
                          }
                          return null;
                        },
                        onSaved: (value) => nome = value!,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Componentes',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ...componentes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final componente = entry.value;
                        final mp = estoqueViewModel
                            .getMateriaPrimaPorId(componente.materiaPrimaId);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(mp?.nome ?? 'Desconhecido',
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${componente.quantidade.toStringAsFixed(2)} ${componente.unidadeMedida}',
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      componentes.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 8),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddComponenteDialog(
                              context, estoqueViewModel, (componente) {
                            setState(() {
                              componentes.add(componente);
                            });
                          }),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Adicionar Componente'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
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
                    if (componentes.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Adicione pelo menos um componente à fórmula'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      final success = await producaoViewModel.adicionarFormula(
                        nome: nome,
                        componentes: componentes,
                      );
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fórmula adicionada com sucesso'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(producaoViewModel.errorMessage ??
                                'Erro ao adicionar fórmula'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditarProducaoDialog(BuildContext context, Producao producao) {
    final producaoViewModel =
        Provider.of<ProducaoViewModel>(context, listen: false);
    final _formKey = GlobalKey<FormState>();

    String loteProducao = producao.loteProducao;
    double quantidade = producao.quantidadeProduzida;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Editar Produção'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: loteProducao,
                  decoration:
                      const InputDecoration(labelText: 'Lote de Produção'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe o lote' : null,
                  onSaved: (v) => loteProducao = v ?? '',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: quantidade.toString(),
                  decoration: const InputDecoration(
                      labelText: 'Quantidade Produzida (btd)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe a quantidade';
                    if (double.tryParse(v) == null) return 'Número inválido';
                    return null;
                  },
                  onSaved: (v) => quantidade = double.parse(v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  Navigator.pop(ctx);

                  final success = await producaoViewModel.atualizarProducao(
                    id: producao.id,
                    formulaId: producao
                        .formulaId, // se um dia quiser trocar fórmula, mude aqui
                    quantidadeProduzida: quantidade,
                    loteProducao: loteProducao,
                    dataProducao: producao.dataProducao,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'Produção atualizada com sucesso'
                          : 'Erro ao atualizar produção'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _showEditFormulaDialog(BuildContext context, Formula formula) {
    final producaoViewModel =
        Provider.of<ProducaoViewModel>(context, listen: false);
    final estoqueViewModel =
        Provider.of<EstoqueViewModel>(context, listen: false);
    final _formKey = GlobalKey<FormState>();
    String nome = formula.nome;
    String? descricao = formula.descricao;
    List<ComponenteFormula> componentes = List.from(formula.componentes);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Editar Fórmula'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Nome da Fórmula',
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
                          labelText: 'Descrição (opcional)',
                        ),
                        initialValue: descricao,
                        onSaved: (value) => descricao = value ?? '',
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Componentes',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ...componentes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final componente = entry.value;
                        final mp = estoqueViewModel
                            .getMateriaPrimaPorId(componente.materiaPrimaId);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(mp?.nome ?? 'Desconhecido',
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${componente.quantidade.toStringAsFixed(2)} ${componente.unidadeMedida}',
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () => _showEditComponenteDialog(
                                    context,
                                    estoqueViewModel,
                                    componente,
                                    (newComponente) {
                                      setState(() {
                                        componentes[index] = newComponente;
                                      });
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      componentes.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 8),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddComponenteDialog(
                              context, estoqueViewModel, (componente) {
                            setState(() {
                              componentes.add(componente);
                            });
                          }),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Adicionar Componente'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
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
                  onPressed: () {
                    if (componentes.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Adicione pelo menos um componente à fórmula'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      producaoViewModel.atualizarFormula(
                        id: formula.id,
                        nome: nome,
                        descricao: descricao,
                        componentes: componentes,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Fórmula atualizada com sucesso')),
                      );
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showExcluirTodasProducoesDialog(BuildContext context) {
    final producaoViewModel =
        Provider.of<ProducaoViewModel>(context, listen: false);
    final TextEditingController _controller = TextEditingController();
    bool isEnabled = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Excluir Todas as Produções'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Digite EXCLUIR para confirmar a exclusão de todas as produções. Esta ação não pode ser desfeita.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    onChanged: (value) {
                      setState(() {
                        isEnabled = value.trim().toUpperCase() == 'EXCLUIR';
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Digite EXCLUIR',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isEnabled
                      ? () async {
                          Navigator.pop(context);
                          // Mostra loading
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                          final success =
                              await producaoViewModel.excluirTodasProducoes();
                          Navigator.of(context, rootNavigator: true)
                              .pop(); // fecha loading
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'Todas as produções foram excluídas'
                                  : 'Erro ao excluir produções'),
                              backgroundColor:
                                  success ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Excluir Tudo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddComponenteDialog(
    BuildContext context,
    EstoqueViewModel estoqueViewModel,
    Function(ComponenteFormula) onAdd,
  ) {
    final _formKey = GlobalKey<FormState>();
    String materiaPrimaId = estoqueViewModel.materiasPrimas.first.id;
    double quantidade = 0;
    String unidadeMedida = 'kg';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Componente'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Matéria-Prima'),
                value: materiaPrimaId,
                items: estoqueViewModel.materiasPrimas.map((mp) {
                  return DropdownMenuItem<String>(
                    value: mp.id,
                    child: Text(mp.nome, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) => materiaPrimaId = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Quantidade',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                ],
                onChanged: (value) => unidadeMedida = value!,
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
                final componente = ComponenteFormula(
                  materiaPrimaId: materiaPrimaId,
                  quantidade: quantidade,
                  unidadeMedida: unidadeMedida,
                );
                onAdd(componente);
                Navigator.pop(context);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _showEditComponenteDialog(
    BuildContext context,
    EstoqueViewModel estoqueViewModel,
    ComponenteFormula componente,
    Function(ComponenteFormula) onUpdate,
  ) {
    final _formKey = GlobalKey<FormState>();
    String materiaPrimaId = componente.materiaPrimaId;
    double quantidade = componente.quantidade;
    String unidadeMedida = componente.unidadeMedida;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Componente'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Matéria-Prima',
                ),
                value: materiaPrimaId,
                items: estoqueViewModel.materiasPrimas.map((mp) {
                  return DropdownMenuItem<String>(
                    value: mp.id,
                    child: Text(mp.nome, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) => materiaPrimaId = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Quantidade',
                ),
                initialValue: quantidade.toString(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                ],
                onChanged: (value) => unidadeMedida = value!,
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
                final updatedComponente = ComponenteFormula(
                  materiaPrimaId: materiaPrimaId,
                  quantidade: quantidade,
                  unidadeMedida: unidadeMedida,
                );
                onUpdate(updatedComponente);
                Navigator.pop(context);
              }
            },
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }
}
