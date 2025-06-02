class UserProfile {
  // Datos básicos (existentes)
  String? email;
  String? firstName;
  String? lastName;
  String? imageUrl;
  String? descripcion;
  String? role;

  // Nuevos datos personales
  Map<String, dynamic>? personalData;

  // Datos existentes
  List<Map<String, dynamic>>? categories;
  List<Map<String, dynamic>>? skills;

  UserProfile({
    this.email,
    this.firstName,
    this.lastName,
    this.imageUrl,
    this.descripcion,
    this.role,
    this.personalData,
    this.categories,
    this.skills,
  });

  // Getters de conveniencia para datos personales
  String? get phone => personalData?['phone'];
  String? get birthDate => personalData?['birth_date'];
  String? get maritalStatus => personalData?['marital_status'];
  String? get gender => personalData?['gender'];
  String? get address => personalData?['address'];
  String? get city => personalData?['city'];
  String? get country => personalData?['country'];
  String? get region => personalData?['region'];
  String? get emergencyContact => personalData?['emergency_contact'];
  String? get emergencyPhone => personalData?['emergency_phone'];
  int? get age => personalData?['age'];

  // Getter para nombre completo
  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    }
    return 'Usuario';
  }

  // Método para verificar si los datos básicos están completos
  bool get hasBasicProfile => firstName != null &&
        lastName != null &&
        role != null &&
        firstName!.trim().isNotEmpty &&
        lastName!.trim().isNotEmpty &&
        role!.trim().isNotEmpty;

  // Método para verificar si los datos personales están completos
  bool get hasPersonalData => personalData != null &&
        personalData!['phone'] != null &&
        personalData!['birth_date'] != null &&
        personalData!['marital_status'] != null &&
        personalData!['gender'] != null &&
        personalData!['city'] != null &&
        personalData!['country'] != null;

  // Método para verificar si tiene categorías y habilidades
  bool get hasSkillsAndCategories => categories != null &&
        categories!.isNotEmpty &&
        skills != null;

  // Método para verificar si el perfil está completo
  bool get isComplete => hasBasicProfile && hasPersonalData && hasSkillsAndCategories;

  // Método para obtener el porcentaje de completitud del perfil
  int get completionPercentage {
    var completed = 0;
    final total = 3;

    if (hasBasicProfile) completed++;
    if (hasPersonalData) completed++;
    if (hasSkillsAndCategories) completed++;

    return ((completed / total) * 100).round();
  }

  // Método para convertir a Map para envío a API
  Map<String, dynamic> toMap() => {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'imageUrl': imageUrl,
      'descripcion': descripcion,
      'role': role,
      'personalData': personalData,
      'categories': categories,
      'skills': skills,
    };

  // Método para crear desde Map (para recibir de API)
  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
      email: map['email'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      imageUrl: map['imageUrl'],
      descripcion: map['descripcion'],
      role: map['role'],
      personalData: map['personalData'],
      categories: map['categories'] != null
          ? List<Map<String, dynamic>>.from(map['categories'])
          : null,
      skills: map['skills'] != null
          ? List<Map<String, dynamic>>.from(map['skills'])
          : null,
    );

  // Método toString para debugging
  @override
  String toString() => 'UserProfile(email: $email, fullName: $fullName, role: $role, '
        'hasPersonalData: $hasPersonalData, completionPercentage: $completionPercentage%)';
}