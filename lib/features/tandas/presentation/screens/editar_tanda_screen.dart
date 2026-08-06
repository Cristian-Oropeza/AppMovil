import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/models/tanda.dart';
import '../providers/tanda_detalle_provider.dart';

class EditarTandaScreen extends StatefulWidget {
  final String tandaId;

  const EditarTandaScreen({super.key, required this.tandaId});

  @override
  State<EditarTandaScreen> createState() => _EditarTandaScreenState();
}

class _EditarTandaScreenState extends State<EditarTandaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = SecureStorageService();

  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();
  final _participantesController = TextEditingController();

  TandaFrecuencia _frecuenciaSeleccionada = TandaFrecuencia.quincenal;
  bool _camposRestringidos = false; // true si la tanda está ACTIVA o FINALIZADA
  bool _inicializado = false;

  double get _montoActual => double.tryParse(_montoController.text) ?? 0.0;
  int get _participantesActual => int.tryParse(_participantesController.text) ?? 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      _prefillForm();
    }
  }

  void _prefillForm() {
    final detalle = context.read<TandaDetalleProvider>().detalle;
    if (detalle == null) return;

    final tanda = detalle.tandaBase;
    _nombreController.text = tanda.nombre;
    _descripcionController.text = tanda.descripcion ?? '';
    _montoController.text = tanda.montoAportacion.toStringAsFixed(0);
    _participantesController.text = tanda.numParticipantes.toString();
    _frecuenciaSeleccionada = tanda.frecuencia;

    // La API bloquea editar monto y participantes si la tanda está activa o finalizada
    _camposRestringidos =
        tanda.estado == TandaEstado.activa || tanda.estado == TandaEstado.finalizada;

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _montoController.addListener(() => setState(() {}));
    _participantesController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _montoController.dispose();
    _participantesController.dispose();
    super.dispose();
  }

  void _incrementarParticipantes() {
    final current = _participantesActual;
    _participantesController.text = (current + 1).toString();
  }

  void _decrementarParticipantes() {
    final current = _participantesActual;
    if (current > 2) {
      _participantesController.text = (current - 1).toString();
    }
  }

  Future<void> _guardarCambios() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final userId = await _storage.getUserId();
    if (userId == null || !mounted) return;

    final provider = context.read<TandaDetalleProvider>();
    final tanda = provider.detalle!.tandaBase;

    // Solo mandamos los campos que realmente cambiaron
    final String? nuevoNombre =
        _nombreController.text.trim() != tanda.nombre ? _nombreController.text.trim() : null;

    final String rawDesc = _descripcionController.text.trim();
    final String? nuevaDesc =
        rawDesc != (tanda.descripcion ?? '') ? (rawDesc.isEmpty ? '' : rawDesc) : null;

    final double? nuevoMonto =
        !_camposRestringidos && _montoActual != tanda.montoAportacion ? _montoActual : null;

    final String? nuevaFrecuencia =
        _frecuenciaSeleccionada != tanda.frecuencia
            ? _frecuenciaSeleccionada.toBackendString()
            : null;

    final int? nuevosParticipantes =
        !_camposRestringidos && _participantesActual != tanda.numParticipantes
            ? _participantesActual
            : null;

    // Si no cambió nada, simplemente regresar
    if (nuevoNombre == null &&
        nuevaDesc == null &&
        nuevoMonto == null &&
        nuevaFrecuencia == null &&
        nuevosParticipantes == null) {
      if (mounted) context.pop();
      return;
    }

    final success = await provider.editarTanda(
      widget.tandaId,
      userId,
      nombre: nuevoNombre,
      descripcion: nuevaDesc,
      montoAportacion: nuevoMonto,
      frecuencia: nuevaFrecuencia,
      numParticipantes: nuevosParticipantes,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanda actualizada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Error al guardar los cambios'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TandaDetalleProvider>();
    final boteTotal = _montoActual * _participantesActual;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Tanda'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Aviso si los campos están bloqueados
                if (_camposRestringidos) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.error.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline,
                            color: theme.colorScheme.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'El monto y participantes no se pueden modificar porque la tanda ya está activa.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                CustomTextField(
                  controller: _nombreController,
                  label: 'Nombre de la tanda',
                  prefixIcon: Icons.group_work_outlined,
                  hint: 'Ej. Vacaciones, Computadora...',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa un nombre';
                    }
                    return null;
                  },
                ),

                CustomTextField(
                  controller: _descripcionController,
                  label: 'Descripción (Opcional)',
                  prefixIcon: Icons.description_outlined,
                  hint: '¿Para qué es esta tanda?',
                ),

                const SizedBox(height: 16),
                Text('Frecuencia de aportación',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<TandaFrecuencia>(
                  segments: const [
                    ButtonSegment(
                      value: TandaFrecuencia.semanal,
                      label: Text('Semanal'),
                    ),
                    ButtonSegment(
                      value: TandaFrecuencia.quincenal,
                      label: Text('Quincenal'),
                    ),
                    ButtonSegment(
                      value: TandaFrecuencia.mensual,
                      label: Text('Mensual'),
                    ),
                  ],
                  selected: {_frecuenciaSeleccionada},
                  onSelectionChanged: (Set<TandaFrecuencia> newSelection) {
                    setState(() {
                      _frecuenciaSeleccionada = newSelection.first;
                    });
                  },
                ),

                const SizedBox(height: 24),
                TextFormField(
                  controller: _montoController,
                  enabled: !_camposRestringidos,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  decoration: InputDecoration(
                    labelText: 'Monto de aportación',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: theme.colorScheme.outline.withOpacity(0.3)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Ingresa el monto';
                    final numValue = double.tryParse(value);
                    if (numValue == null || numValue <= 0) {
                      return 'El monto debe ser mayor a 0';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),
                Text('Número de participantes',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed:
                          _camposRestringidos ? null : _decrementarParticipantes,
                      icon: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _participantesController,
                        enabled: !_camposRestringidos,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color:
                                    theme.colorScheme.outline.withOpacity(0.3)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa participantes';
                          }
                          final numVal = int.tryParse(value);
                          if (numVal == null || numVal < 2) {
                            return 'Mínimo 2 participantes';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton.filledTonal(
                      onPressed:
                          _camposRestringidos ? null : _incrementarParticipantes,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                Card(
                  color: theme.colorScheme.primaryContainer,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: theme.colorScheme.onPrimaryContainer),
                            const SizedBox(width: 8),
                            Text(
                              'Resumen de la Tanda',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cada ${_frecuenciaSeleccionada.displayName}, cada participante aportará \$${_montoActual.toStringAsFixed(2)}.\n\nEl bote total por ciclo será de \$${boteTotal.toStringAsFixed(2)}.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                PrimaryButton(
                  text: 'Guardar cambios',
                  onPressed: _guardarCambios,
                  isLoading: provider.isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
