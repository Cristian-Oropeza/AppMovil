import 'package:flutter/material.dart';
import '../../domain/models/tanda.dart';

class TandaCard extends StatelessWidget {
  final Tanda tanda;
  final VoidCallback onTap;

  const TandaCard({super.key, required this.tanda, required this.onTap});

  Color _getEstadoColor() {
    switch (tanda.estado) {
      case TandaEstado.armando:
        return Colors.amber.shade700;
      case TandaEstado.activa:
        return Colors.green.shade600;
      case TandaEstado.finalizada:
        return Colors.grey.shade600;
      case TandaEstado.cancelada:
        return Colors.red.shade600;
    }
  }

  String _getEstadoLabel() {
    switch (tanda.estado) {
      case TandaEstado.armando:
        return 'ARMANDO';
      case TandaEstado.activa:
        return 'ACTIVA';
      case TandaEstado.finalizada:
        return 'FINALIZADA';
      case TandaEstado.cancelada:
        return 'CANCELADA';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFull = tanda.numMiembrosActuales >= tanda.numParticipantes;
    final progress = tanda.numMiembrosActuales / tanda.numParticipantes;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      tanda.nombre,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getEstadoColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _getEstadoColor()),
                    ),
                    child: Text(
                      _getEstadoLabel(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _getEstadoColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (tanda.rolDelUsuario == TandaRol.admin) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Admin',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '\$${tanda.montoAportacion.toStringAsFixed(2)} / ${tanda.frecuencia.displayName}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${tanda.numMiembrosActuales}/${tanda.numParticipantes} miembros',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (isFull && tanda.estado == TandaEstado.armando)
                    Text(
                      'Cupo lleno',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.colorScheme.surfaceVariant,
                color: isFull ? Colors.green : theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
                minHeight: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
