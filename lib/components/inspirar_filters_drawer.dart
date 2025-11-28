// lib/components/inspirar_filters_drawer.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/inspirar/inspirar_model.dart';

class InspirarFiltersDrawer extends StatefulWidget {
  final InspirarModel model;
  final VoidCallback onApplyFilters;
  final VoidCallback onClearFilters;

  const InspirarFiltersDrawer({
    super.key,
    required this.model,
    required this.onApplyFilters,
    required this.onClearFilters,
  });

  @override
  State<InspirarFiltersDrawer> createState() => _InspirarFiltersDrawerState();
}

class _InspirarFiltersDrawerState extends State<InspirarFiltersDrawer> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _minScoreController = TextEditingController();
  String? _selectedCategoria;

  @override
  void initState() {
    super.initState();
    _selectedCategoria = widget.model.categoria;
    _minScoreController.text = widget.model.minScore?.toString() ?? '';
  }

  @override
  void dispose() {
    _minScoreController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context,
    bool isStartDate,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (widget.model.dateFrom ?? DateTime.now())
          : (widget.model.dateTo ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: FlutterFlowTheme.of(context).primary,
              onPrimary: Colors.white,
              onSurface: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          widget.model.dateFrom = picked;
          // Se data inicial > data final, ajustar data final
          if (widget.model.dateTo != null &&
              widget.model.dateFrom!.isAfter(widget.model.dateTo!)) {
            widget.model.dateTo = widget.model.dateFrom;
          }
        } else {
          // Validar que data final >= data inicial
          if (widget.model.dateFrom != null && picked.isBefore(widget.model.dateFrom!)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('A data final deve ser maior ou igual à data inicial'),
                backgroundColor: FlutterFlowTheme.of(context).error,
              ),
            );
            return;
          }
          widget.model.dateTo = picked;
        }
      });
    }
  }

  void _applyFilters() {
    // Validar nota mínima
    if (_minScoreController.text.isNotEmpty) {
      final score = double.tryParse(_minScoreController.text);
      if (score == null || score < 0 || score > 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A nota deve ser um valor entre 0 e 10'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
        return;
      }
      widget.model.minScore = score;
    } else {
      widget.model.minScore = null;
    }

    // Aplicar categoria
    widget.model.categoria = _selectedCategoria;

    // Fechar drawer antes de aplicar filtros
    Navigator.of(context).pop();
    widget.onApplyFilters();
  }

  void _clearFilters() {
    setState(() {
      widget.model.dateFrom = null;
      widget.model.dateTo = null;
      widget.model.minScore = null;
      widget.model.categoria = null;
      _selectedCategoria = null;
      _minScoreController.clear();
      // Limpar também a lista de fotos para voltar à tela inicial
      widget.model.photos = [];
      widget.model.currentPage = 0;
      widget.model.hasMore = true;
      widget.model.totalResults = 0;
    });
    // Fechar drawer antes de limpar
    Navigator.of(context).pop();
    widget.onClearFilters();
  }

  bool _hasActiveFilters() {
    return widget.model.dateFrom != null ||
        widget.model.dateTo != null ||
        widget.model.minScore != null ||
        (widget.model.categoria != null && widget.model.categoria!.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsetsDirectional.fromSTEB(20, 20, 20, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filtros',
                    style: FlutterFlowTheme.of(context).headlineSmall.override(
                          font: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                          letterSpacing: 0.0,
                        ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: FlutterFlowTheme.of(context).primaryText,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Conteúdo dos filtros
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsetsDirectional.fromSTEB(20, 20, 20, 20),
                  children: [
                    // Filtro por data
                    Text(
                      'Data da postagem',
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            font: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                            letterSpacing: 0.0,
                          ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                      child: Column(
                        children: [
                          // Data inicial
                          InkWell(
                            onTap: () => _selectDate(context, true),
                            child: Container(
                              padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context).secondaryBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context).alternate,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Data inicial',
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .override(
                                              font: GoogleFonts.poppins(),
                                              color: FlutterFlowTheme.of(context)
                                                  .secondaryText,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                                        child: Text(
                                          widget.model.dateFrom != null
                                              ? DateFormat('dd/MM/yyyy', 'pt_BR')
                                                  .format(widget.model.dateFrom!)
                                              : 'Selecione uma data',
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                font: GoogleFonts.poppins(),
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    Icons.calendar_today,
                                    color: FlutterFlowTheme.of(context).primary,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                            child: InkWell(
                              onTap: () => _selectDate(context, false),
                              child: Container(
                                padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).secondaryBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: FlutterFlowTheme.of(context).alternate,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Data final',
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall
                                              .override(
                                                font: GoogleFonts.poppins(),
                                                color: FlutterFlowTheme.of(context)
                                                    .secondaryText,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                        Padding(
                                          padding: EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                                          child: Text(
                                            widget.model.dateTo != null
                                                ? DateFormat('dd/MM/yyyy', 'pt_BR')
                                                    .format(widget.model.dateTo!)
                                                : 'Selecione uma data',
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: GoogleFonts.poppins(),
                                                  letterSpacing: 0.0,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      Icons.calendar_today,
                                      color: FlutterFlowTheme.of(context).primary,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0, 24, 0, 0),
                      child: Divider(
                        color: FlutterFlowTheme.of(context).alternate,
                      ),
                    ),
                    // Filtro por nota
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0, 24, 0, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nota mínima',
                            style: FlutterFlowTheme.of(context).titleMedium.override(
                                  font: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  letterSpacing: 0.0,
                                ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                            child: TextFormField(
                              controller: _minScoreController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), // Permite apenas números e ponto decimal
                                TextInputFormatter.withFunction((oldValue, newValue) {
                                  // Garantir apenas um ponto decimal e máximo 2 casas decimais
                                  final text = newValue.text;
                                  if (text.isEmpty) return newValue;
                                  
                                  // Verificar se há mais de um ponto
                                  if (text.split('.').length > 2) {
                                    return oldValue;
                                  }
                                  
                                  // Verificar se há mais de 2 casas decimais
                                  if (text.contains('.')) {
                                    final parts = text.split('.');
                                    if (parts.length == 2 && parts[1].length > 2) {
                                      return oldValue;
                                    }
                                  }
                                  
                                  return newValue;
                                }),
                              ],
                              decoration: InputDecoration(
                                hintText: 'Ex: 7.5',
                                hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                                      font: GoogleFonts.poppins(),
                                      color: FlutterFlowTheme.of(context).secondaryText,
                                      letterSpacing: 0.0,
                                    ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: FlutterFlowTheme.of(context).alternate,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: FlutterFlowTheme.of(context).primary,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                              ),
                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.poppins(),
                                    letterSpacing: 0.0,
                                  ),
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final score = double.tryParse(value);
                                  if (score == null || score < 0 || score > 10) {
                                    return 'Digite um valor entre 0 e 10';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0, 24, 0, 0),
                      child: Divider(
                        color: FlutterFlowTheme.of(context).alternate,
                      ),
                    ),
                    // Filtro por categoria
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0, 24, 0, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Categoria',
                            style: FlutterFlowTheme.of(context).titleMedium.override(
                                  font: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  letterSpacing: 0.0,
                                ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                            child: Container(
                              padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context).secondaryBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context).alternate,
                                ),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedCategoria,
                                isExpanded: true,
                                underline: SizedBox(),
                                hint: Text(
                                  'Todas as categorias',
                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                        font: GoogleFonts.poppins(),
                                        color: FlutterFlowTheme.of(context).secondaryText,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                      'Todas as categorias',
                                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                                            font: GoogleFonts.poppins(),
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                  ),
                                  ...widget.model.availableCategories.map((category) {
                                    return DropdownMenuItem<String>(
                                      value: category,
                                      child: Text(
                                        category,
                                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                                              font: GoogleFonts.poppins(),
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCategoria = value;
                                  });
                                },
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
            // Botões de ação
            Container(
              padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  if (_hasActiveFilters())
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _clearFilters,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 12),
                            side: BorderSide(
                              color: FlutterFlowTheme.of(context).error,
                            ),
                          ),
                          child: Text(
                            'Limpar Filtros',
                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  color: FlutterFlowTheme.of(context).error,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _applyFilters();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlutterFlowTheme.of(context).primary,
                        padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 12),
                      ),
                      child: Text(
                        'Aplicar Filtros',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                              color: Colors.white,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

