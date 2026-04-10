import 'server.dart';

class JobPosting {
  final int id;
  final int employer;
  final String title;
  final String description;
  final String requirements;
  final int? salaryMin;
  final int? salaryMax;
  final String location;
  final double? latitude;
  final double? longitude;
  final bool isRemote;
  final String contractType;
  final bool isActive;
  final String createdAt;

  const JobPosting({
    required this.id,
    required this.employer,
    required this.title,
    required this.description,
    required this.requirements,
    this.salaryMin,
    this.salaryMax,
    required this.location,
    this.latitude,
    this.longitude,
    required this.isRemote,
    required this.contractType,
    required this.isActive,
    required this.createdAt,
  });

  factory JobPosting.fromJson(Map<String, dynamic> json) {
    return JobPosting(
      id: json['id'] as int,
      employer: json['employer'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      requirements: json['requirements'] as String? ?? '',
      salaryMin: json['salary_min'] as int?,
      salaryMax: json['salary_max'] as int?,
      location: json['location'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isRemote: json['is_remote'] as bool? ?? false,
      contractType: json['contract_type'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String,
    );
  }

  // Fetches all active job postings
  static Future<List<JobPosting>> fetchAll(Server server, String token) async {
    final list = await server.sendGetList('/api/jobs/', token: token);
    return list.map((j) => JobPosting.fromJson(j)).toList();
  }

  // Fetches a job posting by ID
  static Future<JobPosting> fetchById(Server server, String token, int jobId) async {
    final data = await server.sendGet('/api/jobs/$jobId/', token: token);
    return JobPosting.fromJson(data);
  }

  // Creates a new job posting (employer only)
  static Future<JobPosting> create(
    Server server,
    String token, {
    required String title,
    required String description,
    required String requirements,
    required String contractType,
    String location = '',
    int? salaryMin,
    int? salaryMax,
    bool isRemote = false,
  }) async {
    final data = await server.sendPost('/api/jobs/', {
      'title': title,
      'description': description,
      'requirements': requirements,
      'contract_type': contractType,
      'location': location,
      if (salaryMin != null) 'salary_min': salaryMin,
      if (salaryMax != null) 'salary_max': salaryMax,
      'is_remote': isRemote,
    }, token: token);
    return JobPosting.fromJson(data);
  }

  // Applies for this job posting (candidate only)
  Future<void> apply(Server server, String token) async {
    await server.sendPost('/api/jobs/$id/apply/', {}, token: token);
  }

  // Updates this job posting (employer only)
  Future<JobPosting> update(
    Server server,
    String token, {
    required String title,
    required String description,
    required String requirements,
    required String contractType,
    String location = '',
    int? salaryMin,
    int? salaryMax,
    bool isRemote = false,
  }) async {
    final data = await server.sendPut('/api/jobs/$id/', {
      'title': title,
      'description': description,
      'requirements': requirements,
      'contract_type': contractType,
      'location': location,
      if (salaryMin != null) 'salary_min': salaryMin,
      if (salaryMax != null) 'salary_max': salaryMax,
      'is_remote': isRemote,
    }, token: token);
    return JobPosting.fromJson(data);
  }

  // Deletes this job posting (employer only)
  Future<void> delete(Server server, String token) async {
    await server.sendDelete('/api/jobs/$id/', token: token);
  }
}

class JobApplication {
  final int id;
  final int candidate;
  final String? candidateUsername;
  final String? candidateFullName;
  final int? candidateUserId;
  final String? candidateAvatar;
  final int job;
  final String? jobTitle;
  final String? companyName;
  final int? employerId;
  String status;
  final String createdAt;

  JobApplication({
    required this.id,
    required this.candidate,
    required this.candidateUsername,
    required this.candidateFullName,
    required this.candidateUserId,
    required this.candidateAvatar,
    required this.job,
    required this.jobTitle,
    required this.companyName,
    required this.employerId,
    required this.status,
    required this.createdAt,
  });

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    return JobApplication(
      id: json['id'] as int,
      candidate: json['candidate'] as int,
      candidateUsername: json['candidate_username'] as String?,
      candidateFullName: json['candidate_full_name'] as String?,
      candidateUserId: json['candidate_user_id'] as int?,
      candidateAvatar: json['candidate_avatar'] as String?,
      job: json['job'] as int,
      jobTitle: json['job_title'] as String?,
      companyName: json['company_name'] as String?,
      employerId: json['employer_id'] as int?,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
    );
  }

  // Fetches all applications (employers: for all their job postings, candidates: all their applications)
  static Future<List<JobApplication>> fetchApplications(Server server, String token) async {
    final list = await server.sendGetList('/api/jobs/applications/', token: token);
    return list.map((a) => JobApplication.fromJson(a)).toList();
  }

  // Accepts or rejects this application (employer only)
  Future<void> updateStatus(Server server, String token, String newStatus) async {
    await server.sendPatch('/api/jobs/applications/$id/status/', {
      'status': newStatus,
    }, token: token);
    status = newStatus;
  }
}
