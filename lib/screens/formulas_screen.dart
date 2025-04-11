import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/producao_viewmodel.dart';
import '../models/producao.dart';
import '../models/formula.dart';
import '../models/componente_formula.dart';

class ProducaoScreen extends StatefulWidget {
  final int initialTab; // Adicionado para selecionar aba inicial
  const ProducaoScreen({super.key, this.initialTab = 0});

  @override
  State<ProducaoScreen> createState() => _ProducaoScreenState();
}

class _ProducaoScreenState extends State<ProducaoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex:
          widget.initialTab, // Usa o argumento para definir a aba inicial
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produção'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Produções'),
            Tab(text: 'Fórmulas'),
          ],
        ),
      ),
      body: Consumer<ProducaoViewModel>(
        builder: (context, producaoViewModel, child) {
          if (producaoViewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (producaoViewModel.errorMessage != null) {
            return Center(
              child: Text('Erro: ${producaoViewModel.errorMessage}'),
            );
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _buildProducoesTab(producaoViewModel),
              _buildFormulasTab(producaoViewModel),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNovaProducaoDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProducoesTab(ProducaoViewModel producaoViewModel) {
    final producoes = producaoViewModel.producoes;
    if (producoes.isEmpty) {
      return const Center(child: Text('Nenhuma produção registrada'));
    }
    return ListView.builder(
      itemCount: producoes.length,
      itemBuilder: (context, index) {
        final producao = producoes[index];
        final formula = producaoViewModel.getFormulaPorId(producao.formulaId);
        return ListTile(
          title: Text('Lote: ${producao.loteProducao}'),
          subtitle: Text(
              'Fórmula: ${formula?.nome ?? "Desconhecida"} | Quantidade: ${producao.quantidadeProduzida} kg'),
          trailing: Text(producao.dataProducao.toString().substring(0, 10)),
        );
      },
    );
  }

  Widget _buildFormulasTab(ProducaoViewModel producaoViewModel) {
    final formulas = producaoViewModel.formulas;
    if (formulas.isEmpty) {
      return const Center(child: Text('Nenhuma fórmula cadastrada'));
    }
    return ListView.builder(
      itemCount: formulas.length,
      itemBuilder: (context, index) {
        final formula = formulas[index];
        return ListTile(
          title: Text(formula.nome),
          subtitle: Text('Componentes: ${formula.componentes.length}'),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showEditarFormulaDialog(context, formula),
          ),
        );
      },
    );
  }

  void _showEditarFormulaDialog(BuildContext context, Formula formula) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Fórmula: ${formula.nome}'),
        content: const Text('Funcionalidade de edição a ser implementada'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
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
                            labelText: 'Quantidade a Produzir (kg)'),
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

                      try {
                        final success =
                            await producaoViewModel.registrarProducao(
                                formulaId, quantidade, loteProducao);
                        Navigator.of(context, rootNavigator: true)
                            .pop(); // Fecha o diálogo
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Produção registrada com sucesso'
                                  : 'Erro ao registrar produção: ${producaoViewModel.errorMessage ?? "Verifique o estoque!"}',
                            ),
                            backgroundColor:
                                success ? Colors.green : Colors.red,
                          ),
                        );
                      } catch (e) {
                        Navigator.of(context, rootNavigator: true)
                            .pop(); // Fecha o diálogo em erro
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro inesperado: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
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
}
