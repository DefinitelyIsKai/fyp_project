class AddAdminFormModel {
  final String name;
  final String email;
  final String password;
  final String confirmPassword;
  final String role;
  final String? location;
  final int? age;
  final String? phoneNumber;
  final String? gender;
  final String? currentPassword;
  final String? imageBase64;
  final String? imageFileType;

  AddAdminFormModel({
    required this.name,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.role,
    this.location,
    this.age,
    this.phoneNumber,
    this.gender,
    this.currentPassword,
    this.imageBase64,
    this.imageFileType,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'confirmPassword': confirmPassword,
      'role': role,
      'location': location,
      'age': age,
      'phoneNumber': phoneNumber,
      'gender': gender,
      'currentPassword': currentPassword,
      'imageBase64': imageBase64,
      'imageFileType': imageFileType,
    };
  }
}
