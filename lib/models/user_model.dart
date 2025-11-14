class UserModel {
  final String id;

  // Basic info
  final String email;
  final String fullName;
  final String phoneNumber;
  final String location;
  final String role;

  // Profile metadata
  final bool profileCompleted;
  final bool acceptedTerms;
  final String? photoUrl;
  final String? cvUrl;

  // Professional info
  final String professionalSummary;
  final String professionalProfile;
  final String workExperience;
  final String seeking;

  // File maps
  final Map<String, dynamic>? image;
  final Map<String, dynamic>? resume;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.location,
    required this.role,
    required this.profileCompleted,
    required this.acceptedTerms,
    required this.professionalSummary,
    required this.professionalProfile,
    required this.workExperience,
    required this.seeking,
    this.photoUrl,
    this.cvUrl,
    this.image,
    this.resume,
  });

  // Convert Firestore → Dart model
  factory UserModel.fromJson(Map<String, dynamic> json, String docId) {
    return UserModel(
      id: docId,
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      location: json['location'] ?? '',
      role: json['role'] ?? 'employee',

      profileCompleted: json['profileCompleted'] ?? false,
      acceptedTerms: json['acceptedTerms'] ?? false,

      photoUrl: json['photoUrl'],
      cvUrl: json['cvUrl'],

      professionalSummary: json['professionalSummary'] ?? '',
      professionalProfile: json['professionalProfile'] ?? '',
      workExperience: json['workExperience'] ?? '',
      seeking: json['seeking'] ?? '',

      image: json['image'] as Map<String, dynamic>?,
      resume: json['resume'] as Map<String, dynamic>?,
    );
  }

  // Convert Dart → Firestore
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'location': location,
      'role': role,

      'profileCompleted': profileCompleted,
      'acceptedTerms': acceptedTerms,

      'photoUrl': photoUrl,
      'cvUrl': cvUrl,

      'professionalSummary': professionalSummary,
      'professionalProfile': professionalProfile,
      'workExperience': workExperience,
      'seeking': seeking,

      'image': image,
      'resume': resume,
    };
  }
}
