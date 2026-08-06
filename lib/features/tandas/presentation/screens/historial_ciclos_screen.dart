import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../domain/models/tanda.dart';
import '../../domain/models/tanda_detalle.dart';
import '../providers/tanda_detalle_provider.dart';

class HistorialCiclosScreen extends StatefulWidget {
  final String tandaId;
  const HistorialCiclosScreen({super.key, required this.tandaId});

  @override
  State<HistorialCiclosScreen> createState() => _HistorialCiclosScreenState();
}

class _HistorialCiclosScreenState extends State<HistorialCiclosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TandaDetalleProvider>().fetchHistorialCiclos(widget.tandaId);
    });
  }

  Color _getPagoColor(PagoEstado estado, ThemeData theme) {
    switch (estado) {
      case PagoEstado.pendiente:
        return Colors.amber.shade700;
      case PagoEstado.reportado:
        return Colors.blue.shade600;
      case PagoEstado.pagado:
        return Colors.green.shade600;
      case PagoEstado.atrasado:
        return Colors.red.shade600;
    }
  }

  IconData _getPagoIcon(PagoEstado estado) {
    switch (estado) {
      case PagoEstado.pagado:
        return Icons.check_circle;
      case PagoEstado.reportado:
        return Icons.hourglass_top;
      case PagoEstado.pendiente:
        return Icons.schedule;
      case PagoEstado.atrasado:
        return Icons.error;
    }
  }

  String _formatDate(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TandaDetalleProvider>();
    final theme = Theme.of(context);
    final tandaBase = provider.detalle?.tandaBase;

    // Más reciente primero.
    final ciclos = [...provider.historialCiclos]
      ..sort((a, b) => b.numeroCiclo.compareTo(a.numeroCiclo));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de ciclos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<TandaDetalleProvider>().fetchHistorialCiclos(widget.tandaId),
        child: provider.isLoadingHistorial && ciclos.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.historialErrorMessage != null && ciclos.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          provider.historialErrorMessage!,
                          style: TextStyle(color: theme.colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : ciclos.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Text(
                              'Todavía no hay ciclos generados en esta tanda.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: ciclos.length,
                        itemBuilder: (context, index) =>
                            _buildCicloCard(ciclos[index], theme, tandaBase),
                      ),
      ),
    );
  }

  Widget _buildCicloCard(Ciclo ciclo, ThemeData theme, Tanda? tandaBase) {
    final montoTotal = tandaBase != null
        ? tandaBase.numParticipantes * tandaBase.montoAportacion
        : ciclo.montoTotalCiclo;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Row(
          children: [
            Text(
              'Ciclo #${ciclo.numeroCiclo}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (ciclo.cerrado ? Colors.grey : theme.colorScheme.primary).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ciclo.cerrado ? 'CERRADO' : 'EN CURSO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: ciclo.cerrado ? Colors.grey.shade700 : theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Beneficiario: ${ciclo.nombreBeneficiario} · \$${montoTotal.toStringAsFixed(2)} · Límite: ${_formatDate(ciclo.fechaLimite)}',
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${ciclo.nombreBeneficiario} no aparece en los pagos: al recibir el bote este ciclo, no aporta su propia parte.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (ciclo.pagos.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Nadie más tenía que aportar en este ciclo.'),
            )
          else
            ...ciclo.pagos.map((p) => _buildPagoRow(p, theme)),
        ],
      ),
    );
  }

  Widget _buildPagoRow(Pago pago, ThemeData theme) {
    final color = _getPagoColor(pago.estado, theme);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(_getPagoIcon(pago.estado), size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(pago.nombreMiembro, style: theme.textTheme.bodyMedium),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              pago.estado.name.toUpperCase(),
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
