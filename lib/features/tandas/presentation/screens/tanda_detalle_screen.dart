import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/models/tanda.dart';
import '../../domain/models/tanda_detalle.dart';
import '../providers/tanda_detalle_provider.dart';
import '../providers/tandas_provider.dart';

extension StringExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}

class TandaDetalleScreen extends StatefulWidget {
  final String id;
  const TandaDetalleScreen({super.key, required this.id});

  @override
  State<TandaDetalleScreen> createState() => _TandaDetalleScreenState();
}

class _TandaDetalleScreenState extends State<TandaDetalleScreen> {
  final _storage = SecureStorageService();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  void _cargarDetalle() async {
    final userId = await _storage.getUserId();
    if (userId != null && mounted) {
      setState(() => _currentUserId = userId);
      context.read<TandaDetalleProvider>().fetchDetalle(widget.id, userId);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _confirmarCancelarTanda() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar tanda'),
        content: const Text(
          '¿Estás seguro de que deseas cancelar esta tanda?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<TandaDetalleProvider>();
    final success = await provider.cancelarTanda(widget.id);

    if (!mounted) return;
    if (success) {
      _showSnackBar('Tanda cancelada correctamente');
      // Eliminar de la lista local para que desaparezca al regresar
      context.read<TandasProvider>().eliminarTandaLocal(widget.id);
      context.pop();
    } else {
      _showSnackBar(
        provider.errorMessage ?? 'Error al cancelar la tanda',
        isError: true,
      );
    }
  }

  Future<void> _confirmarSalirDeTanda() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salir de la tanda'),
        content: const Text(
          '¿Seguro que quieres salir de esta tanda? Perderás el/los turno(s) '
          'que tengas reservado(s) y alguien más podrá tomarlos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, quedarme'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, salir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<TandaDetalleProvider>();
    final success = await provider.salirDeTanda(widget.id);

    if (!mounted) return;
    if (success) {
      _showSnackBar('Saliste de la tanda correctamente');
      context.read<TandasProvider>().eliminarTandaLocal(widget.id);
      context.pop();
    } else {
      _showSnackBar(
        provider.errorMessage ?? 'Error al salir de la tanda',
        isError: true,
      );
    }
  }

  Future<void> _confirmarIniciarTanda() async {
    final detalle = context.read<TandaDetalleProvider>().detalle;
    if (detalle == null) return;

    final activos = detalle.miembros
        .where((m) => m.estado == MiembroEstado.activo)
        .toList();
    final sinTurno = activos.where((m) => m.turnos.isEmpty).length;
    final totalTurnos = activos.fold<int>(0, (sum, m) => sum + m.turnos.length);
    final faltanTurnos = detalle.tandaBase.numParticipantes - totalTurnos;

    if (sinTurno > 0) {
      _showSnackBar(
        'Hay $sinTurno miembro(s) sin ningún turno asignado. Asígnalos antes de iniciar.',
        isError: true,
      );
      return;
    }
    if (faltanTurnos > 0) {
      _showSnackBar(
        'Faltan $faltanTurnos turno(s) por asignar para completar la tanda.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Iniciar tanda'),
        content: const Text(
          'Al iniciar la tanda ya no podrás agregar ni quitar miembros, y se generará el primer ciclo de pagos.\n\n¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, iniciar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<TandaDetalleProvider>();
    final success = await provider.activarTanda(widget.id);

    if (!mounted) return;
    if (success) {
      _showSnackBar('¡Tanda iniciada! El primer ciclo de pagos ya está en marcha.');
    } else {
      _showSnackBar(
        provider.errorMessage ?? 'Error al iniciar la tanda',
        isError: true,
      );
    }
  }

  Color _getEstadoColor(TandaEstado estado) {
    switch (estado) {
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

  Color _getPagoColor(PagoEstado estado) {
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

  String _formatDate(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
  }

  Miembro? _miMiembro(TandaDetalle detalle) {
    for (final m in detalle.miembros) {
      if (m.usuarioId != null && m.usuarioId == _currentUserId) return m;
    }
    return null;
  }

  String _estadoTurnoTexto(int turnoOrden, TandaEstado estadoTanda, int? numeroCicloActual) {
    if (estadoTanda == TandaEstado.armando) {
      return 'Reservado — la tanda aún no inicia';
    }
    if (estadoTanda == TandaEstado.finalizada) {
      return 'Ya cobraste este turno';
    }
    if (numeroCicloActual == null) {
      return 'Pendiente';
    }
    if (turnoOrden < numeroCicloActual) {
      return 'Ya cobraste (fue en el ciclo #$turnoOrden)';
    } else if (turnoOrden == numeroCicloActual) {
      return '¡Es tu turno! Cobras en este ciclo';
    } else {
      final faltan = turnoOrden - numeroCicloActual;
      return faltan == 1
          ? 'Te toca en el siguiente ciclo'
          : 'Te toca en $faltan ciclos más';
    }
  }

  Widget _buildMiTurnoRow(
    TurnoAsignado turno,
    TandaEstado estadoTanda,
    int? numeroCicloActual,
    ThemeData theme,
  ) {
    final esAhora = estadoTanda == TandaEstado.activa &&
        numeroCicloActual == turno.turnoOrden;
    final yaCobrado = estadoTanda == TandaEstado.finalizada ||
        (estadoTanda == TandaEstado.activa &&
            numeroCicloActual != null &&
            turno.turnoOrden < numeroCicloActual);

    final color = esAhora
        ? theme.colorScheme.primary
        : (yaCobrado ? Colors.green.shade600 : theme.colorScheme.onSurfaceVariant);
    final icon = esAhora
        ? Icons.celebration
        : (yaCobrado ? Icons.check_circle : Icons.schedule);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Turno #${turno.turnoOrden}',
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  _estadoTurnoTexto(turno.turnoOrden, estadoTanda, numeroCicloActual),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiTurnoSection(TandaDetalle detalle, ThemeData theme) {
    final miMiembro = _miMiembro(detalle);
    if (miMiembro == null || miMiembro.turnos.isEmpty) {
      return const SizedBox.shrink();
    }

    final tanda = detalle.tandaBase;
    if (tanda.estado == TandaEstado.cancelada) {
      return const SizedBox.shrink();
    }

    final numeroCicloActual = detalle.cicloActual?.numeroCiclo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          miMiembro.turnos.length == 1 ? 'Tu turno' : 'Tus turnos',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (final turno in miMiembro.turnos)
                  _buildMiTurnoRow(turno, tanda.estado, numeroCicloActual, theme),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoCol(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmarMarcarPagado(Pago pago) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como pagado'),
        content: Text(
          '¿Confirmas que ${pago.nombreMiembro} ya realizó su aportación de este ciclo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, marcar pagado'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<TandaDetalleProvider>();
    final success = await provider.marcarPagoComoPagado(widget.id, pago.id);

    if (!mounted) return;
    if (success) {
      _showSnackBar('Pago de ${pago.nombreMiembro} marcado como realizado');
    } else {
      _showSnackBar(
        provider.errorMessage ?? 'Error al marcar el pago',
        isError: true,
      );
    }
  }

  Future<void> _confirmarAvanzarCiclo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Avanzar al siguiente ciclo'),
        content: const Text(
          'Se cerrará el ciclo actual y se generará el siguiente turno de la '
          'tanda (o se marcará como finalizada si ya se completó la vuelta '
          'completa). ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, avanzar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<TandaDetalleProvider>();
    final success = await provider.avanzarCiclo(widget.id);

    if (!mounted) return;
    if (success) {
      final nuevoEstado = provider.detalle?.tandaBase.estado;
      _showSnackBar(
        nuevoEstado == TandaEstado.finalizada
            ? '¡La tanda se completó! Todos los turnos ya recibieron su bote.'
            : 'Se avanzó al siguiente ciclo.',
      );
    } else {
      _showSnackBar(
        provider.errorMessage ?? 'Error al avanzar de ciclo',
        isError: true,
      );
    }
  }

  Future<void> _confirmarReportarPago(Pago pago) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ya pagué'),
        content: const Text(
          'Se le avisará al administrador de la tanda que ya realizaste tu '
          'aportación de este ciclo, para que la confirme.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, ya pagué'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<TandaDetalleProvider>();
    final success = await provider.reportarPagoPropio(widget.id, pago.id);

    if (!mounted) return;
    if (success) {
      _showSnackBar('Le avisamos al administrador que ya pagaste. Queda pendiente su confirmación.');
    } else {
      _showSnackBar(
        provider.errorMessage ?? 'Error al reportar el pago',
        isError: true,
      );
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

  Widget _buildPagoRow(Pago pago, bool isAdmin, ThemeData theme) {
    final color = _getPagoColor(pago.estado);
    final esPropio = pago.usuarioId != null && pago.usuarioId == _currentUserId;
    final puedeReportar = esPropio &&
        !isAdmin &&
        (pago.estado == PagoEstado.pendiente || pago.estado == PagoEstado.atrasado);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: esPropio ? 8 : 0, vertical: 8),
      decoration: esPropio
          ? BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
            )
          : null,
      child: Row(
        children: [
          Icon(_getPagoIcon(pago.estado), size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    pago.nombreMiembro,
                    style: theme.textTheme.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (esPropio) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(Tú)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              pago.estado.name.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isAdmin && pago.estado != PagoEstado.pagado) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _confirmarMarcarPagado(pago),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.done_all,
                  size: 16,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
          if (puedeReportar) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _confirmarReportarPago(pago),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Ya pagué', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCicloActualSection(Ciclo ciclo, bool isAdmin, ThemeData theme) {
    final todosPagados = ciclo.pagos.isNotEmpty &&
        ciclo.pagos.every((p) => p.estado == PagoEstado.pagado);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ciclo Actual #${ciclo.numeroCiclo}',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Beneficiario',
                          style: theme.textTheme.labelMedium,
                        ),
                        Text(
                          ciclo.nombreBeneficiario,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Bote Total', style: theme.textTheme.labelMedium),
                        Text(
                          '\$${ciclo.montoTotalCiclo.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Límite de pago: ${_formatDate(ciclo.fechaLimite)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (ciclo.pagos.isNotEmpty) ...[
                  Text(
                    'Estado de pagos',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ciclo.nombreBeneficiario} no aparece aquí: al ser quien recibe el bote este ciclo, no aporta su propia parte.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...ciclo.pagos.map((p) => _buildPagoRow(p, isAdmin, theme)),
                ],
                if (isAdmin) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: todosPagados ? _confirmarAvanzarCiclo : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        todosPagados
                            ? 'Avanzar al siguiente ciclo'
                            : 'Faltan pagos para avanzar de ciclo',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiembroTile(Miembro m, bool isAdmin, ThemeData theme) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Text(
          m.nombre.substring(0, 1).toUpperCase(),
          style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
        ),
      ),
      title: Text(
        m.nombre,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: m.turnos.isNotEmpty
          ? Text(
              m.turnos.length == 1
                  ? 'Turno #${m.turnos.first.turnoOrden}'
                  : 'Turnos ${m.turnos.map((t) => '#${t.turnoOrden}').join(', ')}',
            )
          : const Text('Sin turno asignado'),
      trailing: m.rol == TandaRol.admin
          ? Chip(
              label: const Text(
                'Admin',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              backgroundColor: theme.colorScheme.primaryContainer,
              side: BorderSide.none,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            )
          : (isAdmin
                ? IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () =>
                        _showSnackBar('Gestionar miembro - Próximamente'),
                  )
                : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TandaDetalleProvider>();
    final theme = Theme.of(context);

    if (provider.isLoading || provider.detalle == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final detalle = provider.detalle!;
    final tanda = detalle.tandaBase;
    final isAdmin = tanda.rolDelUsuario == TandaRol.admin;
    final isActiva = tanda.estado == TandaEstado.activa;
    final isArmando = tanda.estado == TandaEstado.armando;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tanda.nombre,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getEstadoColor(tanda.estado).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tanda.estado.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: _getEstadoColor(tanda.estado),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (!isArmando)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Historial de ciclos',
              onPressed: () => context.push('/tandas/${widget.id}/historial'),
            ),
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'Cancelar') {
                  _confirmarCancelarTanda();
                } else if (val == 'Editar') {
                  context
                      .push('/tandas/${widget.id}/editar')
                      .then((_) => _cargarDetalle());
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'Editar',
                  child: Text('Editar tanda'),
                ),
                PopupMenuItem(
                  value: 'Cancelar',
                  child: Text(
                    'Cancelar tanda',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          if (!isAdmin && isArmando)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: 'Salir de la tanda',
              onPressed: _confirmarSalirDeTanda,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _cargarDetalle(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoCol(
                        'Aportación',
                        '\$${tanda.montoAportacion.toStringAsFixed(0)}',
                        theme,
                      ),
                      _buildInfoCol(
                        'Frecuencia',
                        tanda.frecuencia.displayName.capitalize(),
                        theme,
                      ),
                      _buildInfoCol(
                        'Miembros',
                        '${tanda.numMiembrosActuales}/${tanda.numParticipantes}',
                        theme,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _buildMiTurnoSection(detalle, theme),

              if (isArmando && isAdmin) ...[
                Text(
                  'Gestión de Tanda',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context
                            .push('/tandas/${widget.id}/miembros/agregar')
                            .then((_) => _cargarDetalle()),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Agregar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _confirmarIniciarTanda,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Iniciar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              if (isActiva && detalle.cicloActual != null) ...[
                _buildCicloActualSection(detalle.cicloActual!, isAdmin, theme),
                const SizedBox(height: 24),
              ],

              if (tanda.estado == TandaEstado.finalizada) ...[
                Card(
                  elevation: 0,
                  color: Colors.green.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.celebration, color: Colors.green.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '¡Esta tanda ya se completó! Todos los turnos recibieron su bote.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Miembros y Turnos',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isAdmin)
                    TextButton(
                      onPressed: () => context
                          .push('/tandas/${widget.id}/miembros')
                          .then((_) => _cargarDetalle()),
                      child: const Text('Gestionar'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (detalle.miembros.isEmpty)
                const Text('No hay miembros en esta tanda aún.'),
              ...detalle.miembros.map(
                (m) => _buildMiembroTile(m, isAdmin, theme),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
