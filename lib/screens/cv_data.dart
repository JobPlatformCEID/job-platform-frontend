enum CvTemplate { classic, modern, minimal }

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

class CvCertification {
  String name;
  String issuer;
  String date;

  CvCertification({
    required this.name,
    required this.issuer,
    this.date = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'issuer': issuer,
        'date': date,
      };

  CvCertification copyWith({
    String? name,
    String? issuer,
    String? date,
  }) {
    return CvCertification(
      name: name ?? this.name,
      issuer: issuer ?? this.issuer,
      date: date ?? this.date,
    );
  }
}

class CvData {
  String fullName;
  String jobTitle;
  String email;
  String phone;
  String location;
  String linkedin;
  String website;
  String summary;
  List<String> skills;
  List<String> languages;
  List<CvEducation> education;
  List<CvExperience> experience;
  List<CvCertification> certifications;
  CvTemplate template;

  CvData({
    this.fullName = '',
    this.jobTitle = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.linkedin = '',
    this.website = '',
    this.summary = '',
    this.skills = const [],
    this.languages = const [],
    this.education = const [],
    this.experience = const [],
    this.certifications = const [],
    this.template = CvTemplate.classic,
  });

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'job_title': jobTitle,
        'email': email,
        'phone': phone,
        'location': location,
        'linkedin': linkedin,
        'website': website,
        'summary': summary,
        'skills': skills,
        'languages': languages,
        'education': education.map((e) => e.toJson()).toList(),
        'experience': experience.map((e) => e.toJson()).toList(),
        'certifications': certifications.map((c) => c.toJson()).toList(),
        'template': template.name,
      };

  CvData copyWith({
    String? fullName,
    String? jobTitle,
    String? email,
    String? phone,
    String? location,
    String? linkedin,
    String? website,
    String? summary,
    List<String>? skills,
    List<String>? languages,
    List<CvEducation>? education,
    List<CvExperience>? experience,
    List<CvCertification>? certifications,
    CvTemplate? template,
  }) {
    return CvData(
      fullName: fullName ?? this.fullName,
      jobTitle: jobTitle ?? this.jobTitle,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      linkedin: linkedin ?? this.linkedin,
      website: website ?? this.website,
      summary: summary ?? this.summary,
      skills: skills ?? this.skills,
      languages: languages ?? this.languages,
      education: education ?? this.education,
      experience: experience ?? this.experience,
      certifications: certifications ?? this.certifications,
      template: template ?? this.template,
    );
  }
}