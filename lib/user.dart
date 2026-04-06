import 'package:logging/logging.dart';
import 'server.dart';

abstract class User {
  final Server server;
  final String token;
  final String username;
  final int userId;
  final String firstName;
  final String lastName;
  final String email;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : username;
  }

  // Constructor
  User({
    required this.server,
    required this.username,
    required this.token,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  Future<void> fetchProfile();
  Future<void> updateProfile();
}

class Candidate extends User {
  int? candidateProfileId;
  String phone = '';
  String location = '';
  String bio = '';
//  String? cv;
//  double score = 0;

  // Constructor
  Candidate({
    required super.server,
    required super.username,
    required super.token,
    required super.userId,
    required super.firstName,
    required super.lastName,
    required super.email,
  });

  @override
  Future<void> fetchProfile() async {
    final data = await server.sendGet('/api/candidates/me/', token: token);
    candidateProfileId = data['id'] as int;
    phone = data['phone'] as String? ?? '';
    location = data['location'] as String? ?? '';
    bio = data['bio'] as String? ?? '';
//  cv = data['cv'] as String?;
//  score = (data['score'] as num).toDouble();
  }

  @override
  Future<void> updateProfile() async {
    await server.sendPut('/api/candidates/me/', {
      'phone': phone,
      'location': location,
      'bio': bio,
    }, token: token);
  }
}

class Employer extends User {
  int? employerProfileId;
  String companyName = '';
  String description = '';
  String location = '';
  String website = '';

  // Constructor
  Employer({
    required super.server,
    required super.username,
    required super.token,
    required super.userId,
    required super.firstName,
    required super.lastName,
    required super.email,
    });

  @override
  Future<void> fetchProfile() async {
    final data = await server.sendGet('/api/employers/me/', token: token);
    employerProfileId = data['id'] as int;
    companyName = data['company_name'] as String? ?? '';
    description = data['description'] as String? ?? '';
    location = data['location'] as String? ?? '';
    website = data['website'] as String? ?? '';
  }

  @override
  Future<void> updateProfile() async {
    await server.sendPut('/api/employers/me/', {
      'company_name': companyName,
      'description': description,
      'location': location,
      'website': website,
    }, token: token);
  }
}
