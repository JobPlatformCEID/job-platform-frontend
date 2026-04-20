/// Filter parameter classes that map to the django-filter backends
/// on the JobPosting and JobApplication API endpoints.

class JobPostingFilter {
  final String? title;
  final String? location;
  final String? contractType;
  final bool? isRemote;
  final bool? isActive;
  final int? salaryMin;
  final int? salaryMax;

  const JobPostingFilter({
    this.title,
    this.location,
    this.contractType,
    this.isRemote,
    this.isActive,
    this.salaryMin,
    this.salaryMax,
  });

  /// Converts non-null fields into URL query parameters matching
  /// the backend JobPostingFilter field names.
  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (title != null && title!.isNotEmpty) params['title'] = title!;
    if (location != null && location!.isNotEmpty) params['location'] = location!;
    if (contractType != null) params['contract_type'] = contractType!;
    if (isRemote != null) params['is_remote'] = isRemote.toString();
    if (isActive != null) params['is_active'] = isActive.toString();
    if (salaryMin != null) params['salary_min'] = salaryMin.toString();
    if (salaryMax != null) params['salary_max'] = salaryMax.toString();
    return params;
  }

  JobPostingFilter copyWith({
    String? title,
    String? location,
    String? contractType,
    bool? isRemote,
    bool? isActive,
    int? salaryMin,
    int? salaryMax,
  }) {
    return JobPostingFilter(
      title: title ?? this.title,
      location: location ?? this.location,
      contractType: contractType ?? this.contractType,
      isRemote: isRemote ?? this.isRemote,
      isActive: isActive ?? this.isActive,
      salaryMin: salaryMin ?? this.salaryMin,
      salaryMax: salaryMax ?? this.salaryMax,
    );
  }

  /// Returns true when every filter field is null/empty (i.e. no filtering).
  bool get isEmpty =>
      (title == null || title!.isEmpty) &&
      (location == null || location!.isEmpty) &&
      contractType == null &&
      isRemote == null &&
      isActive == null &&
      salaryMin == null &&
      salaryMax == null;
}

class JobApplicationFilter {
  final String? status;
  final int? job;
  final String? jobTitle;
  final String? jobContractType;
  final String? jobLocation;
  final bool? jobIsRemote;

  const JobApplicationFilter({
    this.status,
    this.job,
    this.jobTitle,
    this.jobContractType,
    this.jobLocation,
    this.jobIsRemote,
  });

  /// Converts non-null fields into URL query parameters matching
  /// the backend JobApplicationFilter field names.
  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    if (status != null) params['status'] = status!;
    if (job != null) params['job'] = job.toString();
    if (jobTitle != null && jobTitle!.isNotEmpty) params['job_title'] = jobTitle!;
    if (jobContractType != null) params['job_contract_type'] = jobContractType!;
    if (jobLocation != null && jobLocation!.isNotEmpty) params['job_location'] = jobLocation!;
    if (jobIsRemote != null) params['job_is_remote'] = jobIsRemote.toString();
    return params;
  }

  JobApplicationFilter copyWith({
    String? status,
    int? job,
    String? jobTitle,
    String? jobContractType,
    String? jobLocation,
    bool? jobIsRemote,
  }) {
    return JobApplicationFilter(
      status: status ?? this.status,
      job: job ?? this.job,
      jobTitle: jobTitle ?? this.jobTitle,
      jobContractType: jobContractType ?? this.jobContractType,
      jobLocation: jobLocation ?? this.jobLocation,
      jobIsRemote: jobIsRemote ?? this.jobIsRemote,
    );
  }

  /// Returns true when every filter field is null/empty.
  bool get isEmpty =>
      (status == null || status!.isEmpty) &&
      job == null &&
      (jobTitle == null || jobTitle!.isEmpty) &&
      (jobContractType == null || jobContractType!.isEmpty) &&
      (jobLocation == null || jobLocation!.isEmpty) &&
      jobIsRemote == null;
}
