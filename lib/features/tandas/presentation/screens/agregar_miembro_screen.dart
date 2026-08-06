import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../providers/tanda_detalle_provider.dart';

// ─── Modelo ligero del resultado de búsqueda ──────────────────────────────────
class _UsuarioEncontrado {
  final String id;
  final String nombre;
  final String email;
  final String? telefono;
  final String? fotoUrl;

  _UsuarioEncontrado({
    required this.id,
    required this.nombre,
    required this.email,
    this.telefono,
    this.fotoUrl,
  });

  factory _UsuarioEncontrado.fromJson(Map<String, dynamic> json) {
    return _UsuarioEncontrado(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? 'Sin nombre',
      email: json['email'] ?? '',
      telefono: json['telefono'],
      fotoUrl: json['fotoPerfil'],
    );
  }
}

// ─── Fila de la lista de resultados ────────────────────────────────────────────
class _ResultadoTile extends StatelessWidget {
  final _UsuarioEncontrado usuario;
  final VoidCallback onTap;

  const _ResultadoTile({required this.usuario, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage: usuario.fotoUrl != null ? NetworkImage(usuario.fotoUrl!) : null,
          child: usuario.fotoUrl == null
              ? Text(
                  usuario.nombre.isNotEmpty ? usuario.nombre.substring(0, 1).toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                )
              : null,
        ),
        title: Text(usuario.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(usuario.email),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class AgregarMiembroScreen extends StatefulWidget {
  final String id;
  const AgregarMiembroScreen({super.key, required this.id});

  @override
  State<AgregarMiembroScreen> createState() => _AgregarMiembroScreenState();
}

class _AgregarMiembroScreenState extends State<AgregarMiembroScreen> {
  final _queryController = TextEditingController();
  Timer? _debounce;

  bool _buscando = false;
  bool _agregando = false;
  String? _errorBusqueda;
  List<_UsuarioEncontrado> _resultados = [];
  _UsuarioEncontrado? _usuarioEncontrado;
  final Set<int> _turnosSeleccionados = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  // ── Se dispara con cada tecla: espera un momento sin escribir y busca ───────
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _usuarioEncontrado = null;
      _turnosSeleccionados.clear();
      _errorBusqueda = null;
    });

    final q = value.trim();
    if (q.length < 2) {
      setState(() => _resultados = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () => _buscar(q));
  }

  // ── Busca usuarios cuyo correo contenga el texto en la API ──────────────────
  Future<void> _buscar(String q) async {
    setState(() {
      _buscando = true;
      _errorBusqueda = null;
    });

    try {
      final dioClient = context.read<DioClient>();
      final response = await dioClient.dio.get(
        '/usuarios/buscar',
        queryParameters: {'q': q},
      );
      final data = response.data as List;
      if (!mounted) return;
      setState(() {
        _resultados = data.map((j) => _UsuarioEncontrado.fromJson(j)).toList();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['message'];
      setState(() {
        _errorBusqueda = msg ?? 'Error al buscar. Intenta de nuevo.';
        _resultados = [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorBusqueda = 'Error al buscar. Intenta de nuevo.';
        _resultados = [];
      });
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _seleccionarUsuario(_UsuarioEncontrado usuario) {
    FocusScope.of(context).unfocus();
    setState(() {
      _usuarioEncontrado = usuario;
      _turnosSeleccionados.clear();
    });
  }

  // ── Confirma y agrega al miembro encontrado ─────────────────────────────────
  Future<void> _confirmarAgregar() async {
    if (_usuarioEncontrado == null) return;

    setState(() => _agregando = true);

    final provider = context.read<TandaDetalleProvider>();
    final success = await provider.invitarMiembro(
      widget.id,
      _usuarioEncontrado!.email,
      turnos: _turnosSeleccionados.toList(),
    );

    if (!mounted) return;
    setState(() => _agregando = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Miembro agregado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Error al agregar miembro'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tandaDetalle = context.watch<TandaDetalleProvider>().detalle;
    final numParticipantes = tandaDetalle?.tandaBase.numParticipantes;
    final turnosOcupados = <int>{
      if (tandaDetalle != null)
        for (final m in tandaDetalle.miembros)
          for (final t in m.turnos) t.turnoOrden,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Miembro'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instrucción
              Text(
                'Escribe cualquier parte del correo con el que la persona está registrada en Tandas (por ejemplo, lo que va antes de la @).',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // ── Campo de búsqueda (busca automáticamente mientras escribes) ─
              TextFormField(
                controller: _queryController,
                keyboardType: TextInputType.emailAddress,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  labelText: 'Buscar por correo',
                  hintText: 'ej. juan o juan@correo.com',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _buscando
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_queryController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _queryController.clear();
                                _onQueryChanged('');
                              },
                            )
                          : null),
                  errorText: _errorBusqueda,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
              ),

              // ── Lista de resultados ───────────────────────────────────────
              if (_usuarioEncontrado == null && _resultados.isNotEmpty) ...[
                const SizedBox(height: 20),
                ..._resultados.map(
                  (u) => _ResultadoTile(
                    usuario: u,
                    onTap: () => _seleccionarUsuario(u),
                  ),
                ),
              ],

              if (_usuarioEncontrado == null &&
                  !_buscando &&
                  _errorBusqueda == null &&
                  _resultados.isEmpty &&
                  _queryController.text.trim().length >= 2) ...[
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'No se encontraron usuarios con ese correo.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],

              // ── Usuario seleccionado ──────────────────────────────────────
              if (_usuarioEncontrado != null) ...[
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Usuario seleccionado',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_resultados.length > 1)
                      TextButton(
                        onPressed: () => setState(() {
                          _usuarioEncontrado = null;
                          _turnosSeleccionados.clear();
                        }),
                        child: const Text('Elegir otro'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _UserResultCard(
                  usuario: _usuarioEncontrado!,
                  agregando: _agregando,
                  onAgregar: _confirmarAgregar,
                  numParticipantes: numParticipantes,
                  turnosOcupados: turnosOcupados,
                  turnosSeleccionados: _turnosSeleccionados,
                  onTurnoToggled: (turno, seleccionado) => setState(() {
                    if (seleccionado) {
                      _turnosSeleccionados.add(turno);
                    } else {
                      _turnosSeleccionados.remove(turno);
                    }
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tarjeta de resultado ─────────────────────────────────────────────────────
class _UserResultCard extends StatelessWidget {
  final _UsuarioEncontrado usuario;
  final bool agregando;
  final VoidCallback onAgregar;
  final int? numParticipantes;
  final Set<int> turnosOcupados;
  final Set<int> turnosSeleccionados;
  final void Function(int turno, bool seleccionado) onTurnoToggled;

  const _UserResultCard({
    required this.usuario,
    required this.agregando,
    required this.onAgregar,
    required this.numParticipantes,
    required this.turnosOcupados,
    required this.turnosSeleccionados,
    required this.onTurnoToggled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + nombre
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: usuario.fotoUrl != null
                      ? NetworkImage(usuario.fotoUrl!)
                      : null,
                  child: usuario.fotoUrl == null
                      ? Text(
                          usuario.nombre.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    usuario.nombre,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Correo
            _InfoRow(
              icon: Icons.email_outlined,
              label: 'Correo',
              value: usuario.email,
            ),
            const SizedBox(height: 8),

            // Teléfono
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Teléfono',
              value: usuario.telefono?.isNotEmpty == true
                  ? usuario.telefono!
                  : 'No registrado',
            ),

            if (numParticipantes != null) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Asignar turno(s) (opcional)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Puedes elegir más de uno si esta persona va a ocupar varios '
                'lugares en la tanda, o asignarlos después desde la lista de miembros.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int turno = 1; turno <= numParticipantes!; turno++)
                    _buildTurnoChip(context, theme, turno),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // Botón confirmar
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: agregando ? null : onAgregar,
                icon: agregando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_add),
                label: Text(agregando ? 'Agregando...' : 'Agregar a la tanda'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnoChip(BuildContext context, ThemeData theme, int turno) {
    final ocupado = turnosOcupados.contains(turno);
    final seleccionado = turnosSeleccionados.contains(turno);

    return FilterChip(
      label: Text('Turno $turno'),
      avatar: ocupado ? const Icon(Icons.lock, size: 16) : null,
      selected: seleccionado,
      onSelected: ocupado
          ? null
          : (sel) => onTurnoToggled(turno, sel),
      selectedColor: theme.colorScheme.primaryContainer,
      disabledColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
      labelStyle: TextStyle(
        color: ocupado
            ? theme.colorScheme.onSurfaceVariant.withOpacity(0.6)
            : null,
        decoration: ocupado ? TextDecoration.lineThrough : null,
      ),
    );
  }
}

// ─── Fila de información ──────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
