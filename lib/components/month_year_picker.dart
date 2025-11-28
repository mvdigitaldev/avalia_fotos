// lib/components/month_year_picker.dart
import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MonthYearPicker extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final bool isHistorical;

  const MonthYearPicker({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.isHistorical = false,
  });

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
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
      // Ajustar para o primeiro dia do mês selecionado
      final adjustedDate = DateTime(picked.year, picked.month, 1);
      onDateChanged(adjustedDate);
    }
  }

  String _formatMonthYear(DateTime date) {
    final formatter = DateFormat('MMMM yyyy', 'pt_BR');
    return formatter.format(date);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = selectedDate.year == now.year &&
        selectedDate.month == now.month;

    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 16.0, 12.0),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isHistorical
                ? FlutterFlowTheme.of(context).secondary.withOpacity(0.3)
                : FlutterFlowTheme.of(context).primary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              color: isHistorical
                  ? FlutterFlowTheme.of(context).secondary
                  : FlutterFlowTheme.of(context).primary,
              size: 20.0,
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 0.0, 0.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isCurrentMonth ? 'Mês Atual' : 'Histórico',
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.poppins(),
                          color: FlutterFlowTheme.of(context).secondary,
                          fontSize: 10.0,
                          letterSpacing: 0.0,
                        ),
                  ),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 2.0, 0.0, 0.0),
                    child: Text(
                      _formatMonthYear(selectedDate),
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            font: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                            color: isHistorical
                                ? FlutterFlowTheme.of(context).secondary
                                : FlutterFlowTheme.of(context).primaryText,
                            fontSize: 14.0,
                            letterSpacing: 0.0,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 0.0, 0.0),
              child: Icon(
                Icons.arrow_drop_down,
                color: FlutterFlowTheme.of(context).secondary,
                size: 24.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

