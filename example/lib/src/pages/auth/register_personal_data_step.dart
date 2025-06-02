import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/user_service.dart';
import '../../widgets/user_profile.dart';

class RegisterPersonalDataStep extends StatefulWidget {
  final UserProfile userProfile;
  final VoidCallback onCompleted;

  const RegisterPersonalDataStep({
    super.key,
    required this.userProfile,
    required this.onCompleted,
  });

  @override
  State<RegisterPersonalDataStep> createState() => _RegisterPersonalDataStepState();
}

class _RegisterPersonalDataStepState extends State<RegisterPersonalDataStep> {
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();

  // Controladores
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  // Variables de estado
  DateTime? _selectedBirthDate;
  String? _selectedMaritalStatus;
  String? _selectedGender;
  String? _selectedCountry;
  String? _selectedRegion;
  bool _isLoading = false;

  // Opciones para los dropdowns
  final List<String> _maritalStatusOptions = [
    'Soltero/a',
    'Casado/a',
    'Divorciado/a',
    'Viudo/a',
    'Unión libre',
  ];

  final List<String> _genderOptions = [
    'Masculino',
    'Femenino',
    'Otro',
    'Prefiero no decir',
  ];

  // Datos de Chile (puedes expandir esto con una API o base de datos)
  final Map<String, List<String>> _chileRegions = {
    'Chile': [
      'Región de Arica y Parinacota',
      'Región de Tarapacá',
      'Región de Antofagasta',
      'Región de Atacama',
      'Región de Coquimbo',
      'Región de Valparaíso',
      'Región Metropolitana de Santiago',
      'Región del Libertador General Bernardo O\'Higgins',
      'Región del Maule',
      'Región de Ñuble',
      'Región del Biobío',
      'Región de La Araucanía',
      'Región de Los Ríos',
      'Región de Los Lagos',
      'Región Aysén del General Carlos Ibáñez del Campo',
      'Región de Magallanes y de la Antártica Chilena',
    ],
  };

  final List<String> _countries = ['Chile', 'Argentina', 'Perú', 'Bolivia', 'Colombia', 'Ecuador'];

  @override
  void initState() {
    super.initState();
    _selectedCountry = 'Chile'; // Por defecto Chile
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)), // 25 años por defecto
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)), // Hace 100 años
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)), // Mínimo 16 años
      locale: const Locale('es', 'ES'),
      // Removemos la configuración personalizada del Theme
    );

    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _savePersonalData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validación de fecha de nacimiento
    if (_selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona tu fecha de nacimiento'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Preparar los datos para guardar
      final personalData = {
        'phone': _phoneController.text.trim(),
        'birth_date': _selectedBirthDate!.toIso8601String().split('T')[0],
        'marital_status': _selectedMaritalStatus,
        'gender': _selectedGender,
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'country': _selectedCountry,
        'region': _selectedRegion,
      };

      // Guardar en la base de datos
      await _userService.savePersonalData(personalData);

      // Actualizar el perfil del usuario
      widget.userProfile.personalData = personalData;

      if (kDebugMode) {
        print('✅ Datos personales guardados exitosamente');
        print('🔍 Rol del usuario: ${widget.userProfile.role}');
      }

      if (mounted) {
        widget.onCompleted(); // Usar el callback normal
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al guardar datos personales: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar datos: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Datos Personales'),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
    ),
    body: Container(
      color: Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mensaje informativo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.person_outline, color: Colors.blue.shade700, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        'Información Personal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Esta información nos ayuda a personalizar tu experiencia y conectarte mejor con oportunidades laborales.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Información básica
                const Text(
                  'Información Básica',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Teléfono
                TextFormField(
                  controller: _phoneController,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono *',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                    helperText: 'Ej: +56 9 1234 5678',
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El teléfono es obligatorio';
                    }
                    if (value.length < 8) {
                      return 'Ingresa un teléfono válido';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Fecha de nacimiento
                InkWell(
                  onTap: _isLoading ? null : _selectBirthDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Fecha de nacimiento *',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: const OutlineInputBorder(),
                      suffixText: _selectedBirthDate != null
                          ? '(${_calculateAge(_selectedBirthDate!)} años)'
                          : null,
                    ),
                    child: Text(
                      _selectedBirthDate == null
                          ? 'Seleccionar fecha'
                          : _formatDate(_selectedBirthDate!),
                      style: TextStyle(
                        color: _selectedBirthDate == null ? Colors.grey : Colors.black,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Género
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Género *',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  items: _genderOptions.map((String gender) => DropdownMenuItem<String>(
                    value: gender,
                    child: Text(gender),
                  ),).toList(),
                  onChanged: _isLoading ? null : (String? newValue) {
                    setState(() {
                      _selectedGender = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor selecciona tu género';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Estado civil
                DropdownButtonFormField<String>(
                  value: _selectedMaritalStatus,
                  decoration: const InputDecoration(
                    labelText: 'Estado civil *',
                    prefixIcon: Icon(Icons.favorite),
                    border: OutlineInputBorder(),
                  ),
                  items: _maritalStatusOptions.map((String status) => DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  ),).toList(),
                  onChanged: _isLoading ? null : (String? newValue) {
                    setState(() {
                      _selectedMaritalStatus = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor selecciona tu estado civil';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Ubicación
                const Text(
                  'Ubicación',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // País
                DropdownButtonFormField<String>(
                  value: _selectedCountry,
                  decoration: const InputDecoration(
                    labelText: 'País *',
                    prefixIcon: Icon(Icons.public),
                    border: OutlineInputBorder(),
                  ),
                  items: _countries.map((String country) => DropdownMenuItem<String>(
                    value: country,
                    child: Text(country),
                  ),).toList(),
                  onChanged: _isLoading ? null : (String? newValue) {
                    setState(() {
                      _selectedCountry = newValue;
                      _selectedRegion = null; // Reset región cuando cambia país
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor selecciona tu país';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Región (solo si es Chile) - Con solución al overflow
                if (_selectedCountry == 'Chile')
                  DropdownButtonFormField<String>(
                    value: _selectedRegion,
                    decoration: const InputDecoration(
                      labelText: 'Región *',
                      prefixIcon: Icon(Icons.map),
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true, // Esto soluciona el overflow
                    items: _chileRegions[_selectedCountry!]?.map((String region) => DropdownMenuItem<String>(
                      value: region,
                      child: Text(
                        region,
                        overflow: TextOverflow.ellipsis, // Manejo adicional del overflow
                      ),
                    ),).toList() ?? [],
                    onChanged: _isLoading ? null : (String? newValue) {
                      setState(() {
                        _selectedRegion = newValue;
                      });
                    },
                    validator: _selectedCountry == 'Chile' ? (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor selecciona tu región';
                      }
                      return null;
                    } : null,
                  ),

                if (_selectedCountry == 'Chile') const SizedBox(height: 16),

                // Ciudad
                TextFormField(
                  controller: _cityController,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Ciudad *',
                    prefixIcon: Icon(Icons.location_city),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa tu ciudad';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Dirección
                TextFormField(
                  controller: _addressController,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Dirección (opcional)',
                    prefixIcon: Icon(Icons.home),
                    border: OutlineInputBorder(),
                    helperText: 'Calle, número, comuna',
                  ),
                  maxLines: 2,
                ),

                const SizedBox(height: 32),

                // Nota sobre campos obligatorios
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Los campos marcados con (*) son obligatorios',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Botón continuar
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _savePersonalData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'CONTINUAR',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Botón volver
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'VOLVER',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}