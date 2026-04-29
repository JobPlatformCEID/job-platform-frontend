class CvEducation {
  String institution;
  String degree;
  String field;
  String startDate;
  String endDate;
  String description;

  CvEducation({
    required this.institution,
    required this.degree,
    required this.field,
    required this.startDate,
    this.endDate = '',
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
        'institution': institution,
        'degree': degree,
        'field': field,
        'start_date': startDate,
        'end_date': endDate,
        'description': description,
      };

  CvEducation copyWith({
    String? institution,
    String? degree,
    String? field,
    String? startDate,
    String? endDate,
    String? description,
  }) {
    return CvEducation(
      institution: institution ?? this.institution,
      degree: degree ?? this.degree,
      field: field ?? this.field,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
    );
  }
}

class CvExperience {
  String company;
  String position;
  String startDate;
  String endDate;
  String description;

  CvExperience({
    required this.company,
    required this.position,
    required this.startDate,
    this.endDate = '',
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'company': company,
        'position': position,
        'start_date': startDate,
        'end_date': endDate,
        'description': description,
      };

  CvExperience copyWith({
    String? company,
    String? position,
    String? startDate,
    String? endDate,
    String? description,
  }) {
    return CvExperience(
      company: company ?? this.company,
      position: position ?? this.position,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
    );
  }
}

class CvData {
  String fullName;
  String email;
  String phone;
  String location;
  String linkedin;
  String github;
  String summary;
  List<String> skills;
  List<CvEducation> education;
  List<CvExperience> experience;

  CvData({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.linkedin = '',
    this.github = '',
    this.summary = '',
    this.skills = const [],
    this.education = const [],
    this.experience = const [],
  });

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'location': location,
        'linkedin': linkedin,
        'github': github,
        'summary': summary,
        'skills': skills,
        'education': education.map((e) => e.toJson()).toList(),
        'experience': experience.map((e) => e.toJson()).toList(),
      };

  CvData copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? location,
    String? linkedin,
    String? github,
    String? summary,
    List<String>? skills,
    List<CvEducation>? education,
    List<CvExperience>? experience,
  }) {
    return CvData(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      linkedin: linkedin ?? this.linkedin,
      github: github ?? this.github,
      summary: summary ?? this.summary,
      skills: skills ?? this.skills,
      education: education ?? this.education,
      experience: experience ?? this.experience,
    );
  }
}