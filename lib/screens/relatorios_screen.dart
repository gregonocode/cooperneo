import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

import '../theme/app_theme.dart';
import '../viewmodels/relatorios_viewmodel.dart';

class RelatoriosScreen extends StatefulWidget {
  const RelatoriosScreen({Key? key}) : super(key: key);

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen>
    with SingleTickerProviderStateMixin {
  DateTime _dataInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime _dataFim = DateTime.now();
  bool _isDataRangePickerVisible = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleDateRangePicker() {
    setState(() {
      _isDataRangePickerVisible = !_isDataRangePickerVisible;
      if (_isDataRangePickerVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
      ),
      body: Consumer<RelatoriosViewModel>(
        builder: (context, relatoriosViewModel, child) {
          return relatoriosViewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
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
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildDateRangeSection(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildReportCard(
                                title: 'Relatório Diário',
                                description:
                                    'Gerar relatório com informações de produção e consumo do dia atual.',
                                icon: Icons.today,
                                color: Colors.blue,
                                onTap: () => _gerarRelatorioDiario(context),
                              ),
                              const SizedBox(height: 16),
                              _buildReportCard(
                                title: 'Relatório Semanal',
                                description:
                                    'Gerar relatório com informações de produção e consumo da semana atual.',
                                icon: Icons.date_range,
                                color: Colors.green,
                                onTap: () => _gerarRelatorioSemanal(context),
                              ),
                              const SizedBox(height: 16),
                              _buildReportCard(
                                title: 'Relatório de Período Personalizado',
                                description:
                                    'Gerar relatório com informações do período selecionado.',
                                icon: Icons.calendar_month,
                                color: Colors.purple,
                                onTap: () => _gerarRelatorioPeriodo(context),
                              ),
                              const SizedBox(height: 16),
                              _buildReportCard(
                                title: 'Relatório de Estoque Atual',
                                description:
                                    'Gerar relatório com informações do estoque atual de matérias-primas.',
                                icon: Icons.inventory,
                                color: Colors.orange,
                                onTap: () => _gerarRelatorioEstoque(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
        },
      ),
    );
  }

  Widget _buildDateRangeSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: InkWell(
            onTap: _toggleDateRangePicker,
            borderRadius: BorderRadius.circular(12),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          color: AppTheme.primaryDarkColor,
                          size: 28,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Período Selecionado',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${DateFormat('dd/MM/yyyy').format(_dataInicio)} - ${DateFormat('dd/MM/yyyy').format(_dataFim)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _isDataRangePickerVisible
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: AppTheme.primaryDarkColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _animation,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Data Inicial',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _selecionarData(true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat('dd/MM/yyyy')
                                            .format(_dataInicio),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      const Icon(Icons.calendar_today,
                                          size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Data Final',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _selecionarData(false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat('dd/MM/yyyy')
                                            .format(_dataFim),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      const Icon(Icons.calendar_today,
                                          size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickDateButton('Hoje', () {
                          setState(() {
                            _dataInicio = DateTime.now();
                            _dataFim = DateTime.now();
                          });
                        }),
                        _buildQuickDateButton('Esta Semana', () {
                          setState(() {
                            final now = DateTime.now();
                            final weekDay = now.weekday;
                            _dataInicio =
                                now.subtract(Duration(days: weekDay - 1));
                            _dataFim = now;
                          });
                        }),
                        _buildQuickDateButton('Este Mês', () {
                          setState(() {
                            final now = DateTime.now();
                            _dataInicio = DateTime(now.year, now.month, 1);
                            _dataFim = now;
                          });
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickDateButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Gerar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
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

  Future<void> _selecionarData(bool isInicio) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isInicio ? _dataInicio : _dataFim,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.black,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isInicio) {
          _dataInicio = picked;
          if (_dataInicio.isAfter(_dataFim)) {
            _dataFim = _dataInicio;
          }
        } else {
          _dataFim = picked;
          if (_dataFim.isBefore(_dataInicio)) {
            _dataInicio = _dataFim;
          }
        }
      });
    }
  }

  void _gerarRelatorioDiario(BuildContext context) async {
    final viewModel = Provider.of<RelatoriosViewModel>(context, listen: false);
    final hoje = DateTime.now();

    _showLoadingDialog('Gerando relatório diário...');

    try {
      final pdfBytes = await viewModel.gerarRelatorioDiarioPDF(hoje);
      Navigator.pop(context); // Fechar dialog de carregamento
      _showReportOptionsDialog(context, pdfBytes);
    } catch (e) {
      Navigator.pop(context); // Fechar dialog de carregamento
      _showErrorDialog('Erro ao gerar relatório: $e');
    }
  }

  void _gerarRelatorioSemanal(BuildContext context) async {
    final viewModel = Provider.of<RelatoriosViewModel>(context, listen: false);
    final hoje = DateTime.now();

    _showLoadingDialog('Gerando relatório semanal...');

    try {
      final pdfBytes = await viewModel.gerarRelatorioSemanalPDF(hoje);
      Navigator.pop(context); // Fechar dialog de carregamento
      _showReportOptionsDialog(context, pdfBytes);
    } catch (e) {
      Navigator.pop(context); // Fechar dialog de carregamento
      _showErrorDialog('Erro ao gerar relatório: $e');
    }
  }

  void _gerarRelatorioPeriodo(BuildContext context) async {
    final viewModel = Provider.of<RelatoriosViewModel>(context, listen: false);

    _showLoadingDialog('Gerando relatório personalizado...');

    try {
      final pdfBytes = await viewModel.gerarRelatorioPersonalizadoPDF(
        _dataInicio,
        _dataFim,
        'Relatório de Produção',
      );
      Navigator.pop(context); // Fechar dialog de carregamento
      _showReportOptionsDialog(context, pdfBytes);
    } catch (e) {
      Navigator.pop(context); // Fechar dialog de carregamento
      _showErrorDialog('Erro ao gerar relatório: $e');
    }
  }

  void _gerarRelatorioEstoque(BuildContext context) async {
    final viewModel = Provider.of<RelatoriosViewModel>(context, listen: false);

    _showLoadingDialog('Gerando relatório de estoque...');

    try {
      final pdfBytes = await viewModel.gerarRelatorioEstoquePDF();
      Navigator.pop(context); // Fechar dialog de carregamento
      _showReportOptionsDialog(context, pdfBytes);
    } catch (e) {
      Navigator.pop(context); // Fechar dialog de carregamento
      _showErrorDialog('Erro ao gerar relatório: $e');
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erro'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showReportOptionsDialog(BuildContext context, Uint8List pdfBytes) {
    final viewModel = Provider.of<RelatoriosViewModel>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Relatório Gerado com Sucesso',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionButton(
                    label: 'Visualizar',
                    icon: Icons.visibility,
                    color: Colors.blue,
                    onPressed: () {
                      Navigator.pop(context);
                      viewModel.visualizarPDF(pdfBytes);
                    },
                  ),
                  _buildOptionButton(
                    label: 'Baixar',
                    icon: Icons.download,
                    color: Colors.green,
                    onPressed: () {
                      Navigator.pop(context);
                      viewModel.compartilharPDF(pdfBytes);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
