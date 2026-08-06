import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/models/tanda.dart';
import '../providers/tandas_provider.dart';

class CrearTandaScreen extends StatefulWidget {
  const CrearTandaScreen({super.key});

  @override
  State<CrearTandaScreen> createState() => _CrearTandaScreenState();
}

class _CrearTandaScreenState extends State<CrearTandaScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();
  final _participantesController = TextEditingController(text: '10');

  TandaFrecuencia _frecuenciaSeleccionada = TandaFrecuencia.quincenal;
  bool _unirseComoMiembro = false;
  
  double get _montoActual {
    final val = double.tryParse(_montoController.text) ?? 0.0;
    return val;
  }
  
  int get _participantesActual {
    final val = int.tryParse(_participantesController.text) ?? 0;
    return val;
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
    int current = _participantesActual;
    _participantesController.text = (current + 1).toString();
  }

  void _decrementarParticipantes() {
    int current = _participantesActual;
    if (current > 2) {
      _participantesController.text = (current - 1).toString();
    }
  }

  void _crearTanda() async {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      
      final tandasProvider = context.read<TandasProvider>();
      final success = await tandasProvider.crearTanda(
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim().isEmpty ? null : _descripcionController.text.trim(),
        montoAportacion: _montoActual,
        frecuencia: _frecuenciaSeleccionada.toBackendString(),
        numParticipantes: _participantesActual,
        unirseComoMiembro: _unirseComoMiembro,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tanda creada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tandasProvider.errorMessage ?? 'Error al crear tanda'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tandasProvider = context.watch<TandasProvider>();
    final boteTotal = _montoActual * _participantesActual;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Tanda'),
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
                Text('Frecuencia de aportación', style: theme.textTheme.titleMedium),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  decoration: InputDecoration(
                    labelText: 'Monto de aportación',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa el monto';
                    }
                    final numValue = double.tryParse(value);
                    if (numValue == null || numValue <= 0) {
                      return 'El monto debe ser mayor a 0';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 24),
                Text('Número de participantes', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _decrementarParticipantes,
                      icon: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _participantesController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
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
                      onPressed: _incrementarParticipantes,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: CheckboxListTile(
                    value: _unirseComoMiembro,
                    onChanged: (value) => setState(() => _unirseComoMiembro = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Quiero participar como miembro'),
                    subtitle: const Text(
                      'Si lo activas, tú también ocuparás un turno en la rotación. '
                      'Si lo dejas apagado, solo administrarás la tanda y podrás decidir '
                      'unirte después.',
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Card(
                  color: theme.colorScheme.primaryContainer,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: theme.colorScheme.onPrimaryContainer),
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
                  text: 'Crear tanda',
                  onPressed: _crearTanda,
                  isLoading: tandasProvider.isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
