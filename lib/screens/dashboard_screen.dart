import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../viewmodels/estoque_viewmodel.dart';
import '../viewmodels/producao_viewmodel.dart';
import '../models/producao.dart';
import '../models/materia_prima.dart';
import 'estoque_screen.dart';
import 'materias_primas_screen.dart';
import 'fornecedores_screen.dart';
import 'formulas_screen.dart' as FormulasScreenFile; // Mantido por enquanto
import 'producao_screen.dart' as ProducaoScreenFile;
import 'relatorios_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estoqueViewModel = Provider.of<EstoqueViewModel>(context);
    final producaoViewModel = Provider.of<ProducaoViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CooperNeo'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _logout,
          ),
        ],
      ),
      body: estoqueViewModel.isLoading || producaoViewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: RefreshIndicator(
                  onRefresh: () async {
                    await estoqueViewModel.carregarDados();
                    await producaoViewModel.carregarDados();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.05),
                          AppTheme.backgroundColor,
                        ],
                      ),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        const SizedBox(height: 8),
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildQuickAccess(context),
                        const SizedBox(height: 24),
                        _buildEstoqueSummary(estoqueViewModel.materiasPrimas),
                        const SizedBox(height: 24),
                        _buildRecentProductions(producaoViewModel),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bem-vindo ao CooperNeo',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Sistema de Gestão de Estoque e Produção de Rações',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildQuickAccess(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acesso Rápido',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildMenuCard(
              icon: Icons.inventory,
              title: 'Estoque',
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EstoqueScreen()),
                );
              },
            ),
            _buildMenuCard(
              icon: Icons.category,
              title: 'Matérias-Primas',
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MateriasPrimasScreen()),
                );
              },
            ),
            _buildMenuCard(
              icon: Icons.business,
              title: 'Fornecedores',
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FornecedoresScreen()),
                );
              },
            ),
            _buildMenuCard(
              icon: Icons.receipt_long,
              title: 'Fórmulas',
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProducaoScreenFile.ProducaoScreen(),
                    settings:
                        const RouteSettings(arguments: 1), // Aba "Fórmulas"
                  ),
                );
              },
            ),
            _buildMenuCard(
              icon: Icons.precision_manufacturing,
              title: 'Produção',
              color: Colors.red,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const ProducaoScreenFile.ProducaoScreen()),
                );
              },
            ),
            _buildMenuCard(
              icon: Icons.assessment,
              title: 'Relatórios',
              color: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RelatoriosScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstoqueSummary(List<MateriaPrima> materiasPrimas) {
    final List<MateriaPrima> sortedMaterias = List.from(materiasPrimas);
    sortedMaterias.sort((a, b) => a.estoqueAtual.compareTo(b.estoqueAtual));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Resumo do Estoque',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EstoqueScreen()),
                );
              },
              icon: const Icon(Icons.visibility, size: 18),
              label: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        sortedMaterias.isEmpty
            ? Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Nenhuma matéria-prima cadastrada',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              )
            : Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      for (int i = 0; i < sortedMaterias.length && i < 5; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildEstoqueItem(sortedMaterias[i]),
                        ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildEstoqueItem(MateriaPrima materiaPrima) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            materiaPrima.nome,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            '${materiaPrima.estoqueAtual.toStringAsFixed(2)} ${materiaPrima.unidadeMedida}',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: materiaPrima.estoqueAtual <= 0
                      ? AppTheme.errorColor
                      : materiaPrima.estoqueAtual < 100
                          ? AppTheme.warningColor
                          : AppTheme.successColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentProductions(ProducaoViewModel viewModel) {
    final List<Producao> recentProductions =
        viewModel.getProducoesRecentes(limite: 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Produções Recentes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const ProducaoScreenFile.ProducaoScreen()),
                );
              },
              icon: const Icon(Icons.visibility, size: 18),
              label: const Text('Ver todas'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        recentProductions.isEmpty
            ? Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Nenhuma produção registrada',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              )
            : Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentProductions.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final producao = recentProductions[index];
                    final formula =
                        viewModel.getFormulaPorId(producao.formulaId);

                    return ListTile(
                      title: Text(
                        formula?.nome ?? 'Fórmula desconhecida',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        'Lote: ${producao.loteProducao}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${producao.quantidadeProduzida.toStringAsFixed(2)} kg',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy')
                                .format(producao.dataProducao),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        child: Icon(
                          Icons.precision_manufacturing,
                          color: Colors.black,
                        ),
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }
}
