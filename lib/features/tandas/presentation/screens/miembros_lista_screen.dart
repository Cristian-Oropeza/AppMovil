import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../domain/models/tanda.dart';
import '../../domain/models/tanda_detalle.dart';
import '../providers/tanda_detalle_provider.dart';

class MiembrosListaScreen extends StatelessWidget {
  final String id;
  const MiembrosListaScreen({super.key, required this.id});

  // Le agrega UN turno más al miembro (puede terminar con varios).
  Future<void> _asignarTurno(
    BuildContext context,
    Miembro miembro,
    int numParticipantes,
    List<Miembro> miembros,
  ) async {
    final turnosTomados = {
      for (final m in miembros) for (final t in m.turnos) t.turnoOrden,
    };

    final seleccionado = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Agregar turno a ${miembro.nombre}'),
        children: [
          for (int turno = 1; turno <= numParticipantes; turno++)
            SimpleDialogOption(
              onPressed: turnosTomados.contains(turno)
                  ? null
                  : () => Navigator.pop(ctx, turno),
              child: Row(
                children: [
                  Text('Turno #$turno'),
                  if (turnosTomados.contains(turno)) ...[
                    const SizedBox(width: 8),
                    const Text(
                      '(ocupado)',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );

    if (seleccionado == null || !context.mounted) return;

    final provider = context.read<TandaDetalleProvider>();
    final success = await provider.asignarTurno(id, miembro.id, seleccionado);

    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Turno #$seleccionado asignado a ${miembro.nombre}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Error al asignar el turno'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // Libera un turno específico (un miembro puede tener otros y seguir teniéndolos).
  Future<void> _quitarTurno(
    BuildContext context,
    TurnoAsignado turno,
    String nombreMiembro,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar turno'),
        content: Text('¿Quitar el turno #${turno.turnoOrden} de $nombreMiembro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final provider = context.read<TandaDetalleProvider>();
    final success = await provider.quitarTurno(id, turno.id);

    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Turno #${turno.turnoOrden} liberado'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Error al quitar el turno'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _removerMiembro(BuildContext context, String miembroId, String nombreMiembro) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar miembro'),
        content: Text('¿Seguro que deseas quitar a $nombreMiembro de la tanda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<TandaDetalleProvider>();
              final success = await provider.quitarMiembro(id, miembroId);

              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Miembro removido exitosamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.errorMessage ?? 'Error al quitar miembro'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnoChip(
    BuildContext context,
    ThemeData theme,
    String label, {
    bool asignado = false,
    VoidCallback? onTap,
    bool trailingClose = false,
  }) {
    final color = asignado ? theme.colorScheme.primary : Colors.amber.shade800;
    final bgColor = asignado
        ? theme.colorScheme.primary.withOpacity(0.1)
        : Colors.amber.withOpacity(0.2);

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
            if (trailingClose) ...[
              const SizedBox(width: 4),
              Icon(Icons.close, size: 12, color: color),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TandaDetalleProvider>();
    final detalle = provider.detalle;
    final theme = Theme.of(context);

    if (provider.isLoading && detalle == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }

    if (detalle == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Tanda no encontrada')));
    }

    final tanda = detalle.tandaBase;
    final isAdmin = tanda.rolDelUsuario == TandaRol.admin;
    final isArmando = tanda.estado == TandaEstado.armando;
    final miembros = detalle.miembros;
    final puedeEditarTurnos = isAdmin && isArmando;

    return Scaffold(
      appBar: AppBar(
        title: Text('Miembros (${miembros.length}/${tanda.numParticipantes})'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: miembros.length,
            itemBuilder: (context, index) {
              final miembro = miembros[index];
              final isCurrentUserAdmin = miembro.rol == TandaRol.admin;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 0,
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCurrentUserAdmin ? theme.colorScheme.primaryContainer : theme.colorScheme.secondaryContainer,
                    child: Text(
                      miembro.nombre.isNotEmpty ? miembro.nombre.substring(0, 1).toUpperCase() : '?',
                      style: TextStyle(
                        color: isCurrentUserAdmin ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          miembro.nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUserAdmin) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.star, size: 16, color: theme.colorScheme.primary),
                      ]
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (miembro.turnos.isEmpty)
                          _buildTurnoChip(context, theme, 'Sin turno asignado'),
                        ...miembro.turnos.map(
                          (t) => _buildTurnoChip(
                            context,
                            theme,
                            'Turno #${t.turnoOrden}',
                            asignado: true,
                            trailingClose: puedeEditarTurnos,
                            onTap: puedeEditarTurnos
                                ? () => _quitarTurno(context, t, miembro.nombre)
                                : null,
                          ),
                        ),
                        if (puedeEditarTurnos)
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 14),
                            label: const Text('Agregar turno'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _asignarTurno(
                              context,
                              miembro,
                              tanda.numParticipantes,
                              miembros,
                            ),
                          ),
                      ],
                    ),
                  ),
                  trailing: (isAdmin && !isCurrentUserAdmin && isArmando)
                      ? IconButton(
                          icon: const Icon(Icons.person_remove),
                          color: theme.colorScheme.error,
                          onPressed: () => _removerMiembro(context, miembro.id, miembro.nombre),
                        )
                      : null,
                ),
              );
            },
          ),
          if (provider.isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: (isAdmin && isArmando)
          ? FloatingActionButton.extended(
              onPressed: () => context
                  .push('/tandas/$id/miembros/agregar')
                  .then((_) {}),
              icon: const Icon(Icons.person_add),
              label: const Text('Agregar miembro'),
            )
          : null,
    );
  }
}
