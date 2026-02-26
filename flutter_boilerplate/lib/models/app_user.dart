enum UserType { student, resident }

enum VerificationStatus { pending, verified, rejected }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.userType,
    required this.verificationStatus,
  });

  final String id;
  final String email;
  final UserType userType;
  final VerificationStatus verificationStatus;

  bool get isIllinoisEmail => email.toLowerCase().endsWith('@illinois.edu');

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      userType: (json['user_type'] as String) == 'student'
          ? UserType.student
          : UserType.resident,
      verificationStatus: switch (json['id_verification_status'] as String) {
        'verified' => VerificationStatus.verified,
        'rejected' => VerificationStatus.rejected,
        _ => VerificationStatus.pending,
      },
    );
  }
}
