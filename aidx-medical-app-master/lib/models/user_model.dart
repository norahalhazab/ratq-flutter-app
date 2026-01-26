class UserModel {
  final String id;
  final String email;
  final String name;
  final String? gender;
  final String? age;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.gender,
    this.age,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    final profile = data['profile'] ?? {};
    
    return UserModel(
      id: id,
      email: profile['email'] ?? '',
      name: profile['name'] ?? '',
      gender: profile['gender'],
      age: profile['age'],
      photoUrl: profile['photo'],
      createdAt: profile['createdAt'] != null 
          ? (profile['createdAt'] as dynamic).toDate() 
          : null,
      updatedAt: profile['updatedAt'] != null 
          ? (profile['updatedAt'] as dynamic).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'profile': {
        'email': email,
        'name': name,
        'gender': gender,
        'age': age,
        'photo': photoUrl,
        'updatedAt': DateTime.now(),
      }
    };
  }

  UserModel copyWith({
    String? name,
    String? gender,
    String? age,
    String? photoUrl,
  }) {
    return UserModel(
      id: id,
      email: email,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
} 