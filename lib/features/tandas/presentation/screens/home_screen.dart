import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/tanda.dart';
import '../providers/tandas_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Cargar tandas desde la API al inicializar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TandasProvider>().fetchMisTandas();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<AuthProvider>().logout();

    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tandasProvider = context.watch<TandasProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Tandas', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.watch_outlined),
            tooltip: 'Vincular reloj',
            onPressed: () => context.push('/vincular-reloj'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _confirmarCerrarSesion,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(text: 'Tandas'),
            Tab(text: 'Mis Tandas'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<TandasProvider>().fetchMisTandas();
        },
        child: tandasProvider.isLoading && tandasProvider.tandas.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _TandaList(
                    tandas: tandasProvider.tandas
                        .where((t) => t.rolDelUsuario == TandaRol.miembro)
                        .toList(),
                  ),
                  _TandaList(
                    tandas: tandasProvider.tandas
                        .where((t) => t.rolDelUsuario == TandaRol.admin)
                        .toList(),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tandas/crear'),
        icon: const Icon(Icons.add),
        label: const Text('Crear Tanda'),
      ),
    );
  }
}

class _TandaList extends StatelessWidget {
  final List<Tanda> tandas;

  const _TandaList({required this.tandas});

  @override
  Widget build(BuildContext context) {
    if (tandas.isEmpty) {
      return ListView( // Usamos ListView para que funcione el RefreshIndicator
        children: const [
          SizedBox(height: 150),
          Center(
            child: Text(
              'No tienes tandas en esta sección',
              style: TextStyle(color: Colors.grey),
            ),
          )
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, top: 8), // espacio para FAB
      itemCount: tandas.length,
      itemBuilder: (context, index) {
        return _TandaCard(tanda: tandas[index]);
      },
    );
  }
}

class _TandaCard extends StatelessWidget {
  final Tanda tanda;

  const _TandaCard({required this.tanda});

  Color _getEstadoColor(TandaEstado estado) {
    switch (estado) {
      case TandaEstado.armando:
        return Colors.orange;
      case TandaEstado.activa:
        return Colors.green;
      case TandaEstado.finalizada:
        return Colors.grey;
      case TandaEstado.cancelada:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/tandas/${tanda.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner superior (Estado y Rol)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark 
                  ? theme.colorScheme.surfaceVariant 
                  : theme.colorScheme.primaryContainer.withOpacity(0.4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getEstadoColor(tanda.estado),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tanda.estado.name.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark 
                              ? _getEstadoColor(tanda.estado).withOpacity(0.9)
                              : _getEstadoColor(tanda.estado),
                        ),
                      ),
                    ],
                  ),
                  if (tanda.rolDelUsuario == TandaRol.admin)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star, size: 12, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'ADMIN',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Cuerpo de la tarjeta
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tanda.nombre,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoCol(
                        context, 
                        'Aportación', 
                        '\$${tanda.montoAportacion.toStringAsFixed(0)}',
                      ),
                      _buildInfoCol(
                        context, 
                        'Frecuencia', 
                        tanda.frecuencia.displayName,
                      ),
                      _buildInfoCol(
                        context, 
                        'Participantes', 
                        '${tanda.numMiembrosActuales}/${tanda.numParticipantes}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCol(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
