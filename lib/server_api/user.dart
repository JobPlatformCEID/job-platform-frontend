import 'package:logging/logging.dart';
import 'server.dart';

abstract class User {
  final Server server;
  final String token;
  final String username;
  final int userId;
  String firstName;
  String lastName;
  String email;
  String? avatarUrl;

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
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.avatarUrl,
  });

  // Get all user info from the server
  Future<void> fetchMe() async {
    final data = await server.sendGet('/api/users/me/', token: token);
    firstName = data['first_name'] as String? ?? '';
    lastName = data['last_name'] as String? ?? '';
    email = data['email'] as String? ?? '';
  
    // Replace localhost with the actual server URL
    final rawAvatar = data['avatar'] as String?;
    if (rawAvatar != null) {
      final serverHost = Uri.parse(server.getServerUrl()!).host;
      //this is only for dev in prod localhost wont appear
      avatarUrl = rawAvatar.replaceFirst('localhost', serverHost);
    } else {
      avatarUrl = null;
    }
  }

  // Updates user info
  Future<void> updateMe() async {
    await server.sendPatch('/api/users/me/', {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
    }, token: token);
  }

  // Uploads an avatar for the current user
  Future<void> updateAvatar(List<int> bytes, String filename) async {
    await server.sendMultipartPatch(
      '/api/users/me/',
      'avatar',
      bytes,
      filename,
      token: token,
    );
    await fetchMe();
  }

  static Future<List<Map<String, dynamic>>> searchUsers(Server server, String token, String q) async {
    final list = await server.sendGetList('/api/users/?search=${Uri.encodeComponent(q)}', token: token);
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> fetchProfile();
  Future<void> updateProfile();
}

class Skill {
  final int? id;
  String name;

  Skill({this.id, required this.name});

  factory Skill.fromJson(Map<String, dynamic> json) =>
      Skill(id: json['id'] as int?, name: json['name'] as String);

  Map<String, dynamic> toJson() => {'name': name};
}

class Education {
  final int? id;
  String institution;
  String degree;
  String level; // high_school | bachelor | master | phd
  String? graduationDate; // yyyy-MM-dd

  Education({
    this.id,
    required this.institution,
    required this.degree,
    required this.level,
    this.graduationDate,
  });

  factory Education.fromJson(Map<String, dynamic> json) => Education(
        id: json['id'] as int?,
        institution: json['institution'] as String,
        degree: json['degree'] as String,
        level: json['level'] as String,
        graduationDate: json['graduation_date'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'institution': institution,
        'degree': degree,
        'level': level,
        if (graduationDate != null) 'graduation_date': graduationDate,
      };
}

class WorkExperience {
  final int? id;
  String title;
  String company;
  String startDate; // yyyy-MM-dd
  String? endDate;
  String description;
  String employmentType; // full_time | part_time | freelance | internship | contract

  WorkExperience({
    this.id,
    required this.title,
    required this.company,
    required this.startDate,
    this.endDate,
    this.description = '',
    this.employmentType = 'full_time',
  });

  factory WorkExperience.fromJson(Map<String, dynamic> json) => WorkExperience(
        id: json['id'] as int?,
        title: json['title'] as String,
        company: json['company'] as String,
        startDate: json['start_date'] as String,
        endDate: json['end_date'] as String?,
        description: json['description'] as String? ?? '',
        employmentType: json['employment_type'] as String? ?? 'full_time',
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'company': company,
        'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        'description': description,
        'employment_type': employmentType,
      };
}

class Candidate extends User {
  int? candidateProfileId;
  String phone = '';
  String location = '';
  String bio = '';
  String? cvUrl;

  List<Skill> skills = [];
  List<Education> educations = [];
  List<WorkExperience> experiences = [];

  static const _base = '/api/candidates/background';

  // Constructor
  Candidate({
    required super.server,
    required super.username,
    required super.token,
    required super.userId,
  });

  @override
  Future<void> fetchProfile() async {
    final data = await server.sendGet('/api/candidates/me/', token: token);
    candidateProfileId = data['id'] as int;
    phone = data['phone'] as String? ?? '';
    location = data['location'] as String? ?? '';
    bio = data['bio'] as String? ?? '';
    cvUrl = data['cv'] as String?;

  }

  @override
  Future<void> updateProfile() async {
    await server.sendPut('/api/candidates/me/', {
      'phone': phone,
      'location': location,
      'bio': bio,
    }, token: token);
  }

  // Uploads a CV for the current candidate
  Future<void> uploadCV(List<int> bytes, String filename) async {
    await server.sendMultipartPatch(
      '/api/candidates/me/',
      'cv',
      bytes,
      filename,
      token: token,
    );
    // Mostly for profile screen to see the new cv imideatly
    await fetchProfile();
  }

  // Skills 

  Future<void> fetchSkills() async {
    final list = await server.sendGetList('$_base/skills/', token: token);
    skills = list.map((e) => Skill.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Skill> addSkill(String name) async {
    final data = await server.sendPost('$_base/skills/', {'name': name}, token: token);
    final skill = Skill.fromJson(data);
    skills.add(skill);
    return skill;
  }

  Future<void> deleteSkill(int id) async {
    await server.sendDelete('$_base/skills/$id/', token: token);
    skills.removeWhere((s) => s.id == id);
  }

  // Education

  Future<void> fetchEducations() async {
    final list = await server.sendGetList('$_base/education/', token: token);
    educations = list.map((e) => Education.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Education> addEducation(Education edu) async {
    final data = await server.sendPost('$_base/education/', edu.toJson(), token: token);
    final saved = Education.fromJson(data);
    educations.add(saved);
    return saved;
  }

  Future<void> deleteEducation(int id) async {
    await server.sendDelete('$_base/education/$id/', token: token);
    educations.removeWhere((e) => e.id == id);
  }

  // Work Experience

  Future<void> fetchExperiences() async {
    final list = await server.sendGetList('$_base/experience/', token: token);
    experiences = list.map((e) => WorkExperience.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WorkExperience> addExperience(WorkExperience exp) async {
    final data = await server.sendPost('$_base/experience/', exp.toJson(), token: token);
    final saved = WorkExperience.fromJson(data);
    experiences.add(saved);
    return saved;
  }

  Future<void> deleteExperience(int id) async {
    await server.sendDelete('$_base/experience/$id/', token: token);
    experiences.removeWhere((e) => e.id == id);
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
