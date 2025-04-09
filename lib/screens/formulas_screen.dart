import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../models/formula.dart';
import '../viewmodels/producao_viewmodel.dart';
import '../viewmodels/estoque_viewmodel.dart';

class FormulasScreen extends StatefulWidget {
  const FormulasScreen({Key? key}) : super(key: key);

  @override
  State<FormulasScreen> createState() => _FormulasScreenState();
}

class _FormulasScreenState extends State<FormulasScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // Atualizar dados
    Future.microtask(() {
      Provider.of<ProducaoViewModel>(context, listen: false).carregarDados();
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
    final producaoViewModel = Provider.of<ProducaoViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulas'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar formulas...',
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
                : _buildFormulasList(producaoViewModel),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'formulas_fab',
        onPressed: () => _showAddFormulaDialog(context),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildFormulasList(ProducaoViewModel viewModel) {
    // Filtrar fu00f3rmulas
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
                  ? 'Nenhuma Formula cadastrada'
                  : 'Nenhuma Formula encontrada',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          )
        : RefreshIndicator(
            onRefresh: () => viewModel.carregarDados(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
      margin: const EdgeInsets.only(bottom: 8),
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
                          (formula.descricao?.isEmpty ?? true)
                              ? '${formula.componentes.length} componentes'
                              : formula.descricao ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: formula.componentes.take(3).map((componente) {
                  final mp =
                      viewModel.getMateriaPrimaPorId(componente.materiaPrimaId);
                  if (mp == null) return const SizedBox.shrink();

                  return Chip(
                    label: Text(
                      mp.nome,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  );
                }).toList(),
              ),
              if (formula.componentes.length > 3)
                Text(
                  '... e ${formula.componentes.length - 3} mais',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        _showNovaProducaoDialog(context, formula.id),
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

  void _showAddFormulaDialog(BuildContext context) {
    // Abrir tela de produção diretamente
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProductionPage(initialTab: 1)),
    );
  }

  void _showFormulaDetailsDialog(
      BuildContext context, Formula formula, ProducaoViewModel viewModel) {
    // Abrir tela de produção diretamente
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              ProductionPage(initialTab: 1, selectedFormulaId: formula.id)),
    );
  }

  void _showNovaProducaoDialog(BuildContext context, String formulaId) {
    // Abrir tela de produção diretamente
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              ProductionPage(initialTab: 0, selectedFormulaId: formulaId)),
    );
  }
}

// Wrapper para a tela de produção que permite especificar a aba inicial
class ProductionPage extends StatefulWidget {
  final int initialTab;
  final String? selectedFormulaId;

  const ProductionPage({Key? key, this.initialTab = 0, this.selectedFormulaId})
      : super(key: key);

  @override
  State<ProductionPage> createState() => _ProductionPageState();
}

class _ProductionPageState extends State<ProductionPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: 'Produtos'),
            Tab(text: 'Formulas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          Center(child: Text('Aba de Produtos')),
          Center(child: Text('Aba de Formulas')),
        ],
      ),
    );
  }
}
