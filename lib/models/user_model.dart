class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String age;
  final String gender;
  final String photoUrl;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.age = '',
    this.gender = '',
    this.photoUrl = '',
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) => UserModel(
        uid: uid,
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        phone: map['phone'] ?? '',
        age: map['age'] ?? '',
        gender: map['gender'] ?? '',
        photoUrl: map['photoUrl'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'age': age,
        'gender': gender,
        'photoUrl': photoUrl,
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? age,
    String? gender,
    String? photoUrl,
  }) =>
      UserModel(
        uid: uid,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        photoUrl: photoUrl ?? this.photoUrl,
      );
}
