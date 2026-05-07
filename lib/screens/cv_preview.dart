import 'package:flutter/material.dart';
import 'cv_data.dart';

class CvPreview extends StatelessWidget {
  final CvData cv;
  const CvPreview({Key? key, required this.cv}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (cv.template) {
      case CvTemplate.modern:
        return _ModernTemplate(cv: cv);
      case CvTemplate.minimal:
        return _MinimalTemplate(cv: cv);
      case CvTemplate.classic:
      default:
        return _ClassicTemplate(cv: cv);
    }
  }
}

class _ClassicTemplate extends StatelessWidget {
  final CvData cv;
  const _ClassicTemplate({required this.cv});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(color: Color(0xFF212121)),
      child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cv.fullName.isNotEmpty ? cv.fullName : 'Your Name',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          if (cv.jobTitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(cv.jobTitle, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 2,
            children: [
              if (cv.email.isNotEmpty) _contactChip(cv.email),
              if (cv.phone.isNotEmpty) _contactChip(cv.phone),
              if (cv.location.isNotEmpty) _contactChip(cv.location),
              if (cv.linkedin.isNotEmpty) _contactChip(cv.linkedin),
              if (cv.website.isNotEmpty) _contactChip(cv.website),
            ],
          ),
          const Divider(height: 28, thickness: 1.5),
          if (cv.summary.isNotEmpty) ...[
            _sectionHeader('Profile'),
            const SizedBox(height: 6),
            Text(cv.summary, style: const TextStyle(fontSize: 12, height: 1.5)),
            const SizedBox(height: 16),
          ],
          if (cv.skills.isNotEmpty) ...[
            _sectionHeader('Skills'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: cv.skills
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFBBBBBB)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(s, style: const TextStyle(fontSize: 11)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (cv.experience.isNotEmpty) ...[
            _sectionHeader('Experience'),
            const SizedBox(height: 6),
            ...cv.experience.map((exp) => _experienceBlock(exp)),
          ],
          if (cv.education.isNotEmpty) ...[
            _sectionHeader('Education'),
            const SizedBox(height: 6),
            ...cv.education.map((edu) => _educationBlock(edu)),
          ],
          if (cv.certifications.isNotEmpty) ...[
            _sectionHeader('Certifications'),
            const SizedBox(height: 6),
            ...cv.certifications.map((c) => _certBlock(c)),
          ],
          if (cv.languages.isNotEmpty) ...[
            _sectionHeader('Languages'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: cv.languages
                  .map((l) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFBBBBBB)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(l, style: const TextStyle(fontSize: 11)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    ),  // SingleChildScrollView
    );  // DefaultTextStyle.merge
  }

  Widget _contactChip(String text) =>
      Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF444444)));

  Widget _sectionHeader(String title) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          const Divider(height: 8, thickness: 0.8),
        ],
      );

  Widget _experienceBlock(CvExperience exp) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(exp.position, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
            Text('${exp.startDate} – ${exp.endDate.isEmpty ? 'Present' : exp.endDate}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF777777))),
          ]),
          Text(exp.company, style: const TextStyle(fontSize: 11, color: Color(0xFF555555))),
          if (exp.description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(exp.description, style: const TextStyle(fontSize: 11, height: 1.4)),
          ],
        ]),
      );

  Widget _educationBlock(CvEducation edu) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: Text('${edu.degree} in ${edu.field}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
            Text('${edu.startDate} – ${edu.endDate.isEmpty ? 'Present' : edu.endDate}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF777777))),
          ]),
          Text(edu.institution, style: const TextStyle(fontSize: 11, color: Color(0xFF555555))),
          if (edu.description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(edu.description, style: const TextStyle(fontSize: 11, height: 1.4)),
          ],
        ]),
      );

  Widget _certBlock(CvCertification c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              Text(c.issuer, style: const TextStyle(fontSize: 11, color: Color(0xFF555555))),
            ]),
          ),
          if (c.date.isNotEmpty) Text(c.date, style: const TextStyle(fontSize: 10, color: Color(0xFF777777))),
        ]),
      );
}

class _ModernTemplate extends StatelessWidget {
  final CvData cv;
  const _ModernTemplate({required this.cv});

  static const Color accent = Color(0xFF1E5F74);

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(color: Color(0xFF212121)),
      child: SingleChildScrollView(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left sidebar
            Container(
              width: 160,
              color: accent,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cv.fullName.isNotEmpty ? cv.fullName : 'Your Name',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                  ),
                  if (cv.jobTitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(cv.jobTitle,
                        style: const TextStyle(fontSize: 10, color: Color(0xFFCCE0E8))),
                  ],
                  const SizedBox(height: 16),
                  _sideSection('Contact'),
                  if (cv.email.isNotEmpty) _sideItem(cv.email),
                  if (cv.phone.isNotEmpty) _sideItem(cv.phone),
                  if (cv.location.isNotEmpty) _sideItem(cv.location),
                  if (cv.linkedin.isNotEmpty) _sideItem(cv.linkedin),
                  if (cv.website.isNotEmpty) _sideItem(cv.website),
                  if (cv.skills.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _sideSection('Skills'),
                    ...cv.skills.map((s) => _sideItem(s)),
                  ],
                  if (cv.languages.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _sideSection('Languages'),
                    ...cv.languages.map((l) => _sideItem(l)),
                  ],
                ],
              ),
            ),
            // Right main content
            Expanded(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cv.summary.isNotEmpty) ...[
                      _mainSection('Profile'),
                      Text(cv.summary, style: const TextStyle(fontSize: 11, height: 1.5)),
                      const SizedBox(height: 14),
                    ],
                    if (cv.experience.isNotEmpty) ...[
                      _mainSection('Experience'),
                      ...cv.experience.map((exp) => _experienceBlock(exp)),
                    ],
                    if (cv.education.isNotEmpty) ...[
                      _mainSection('Education'),
                      ...cv.education.map((edu) => _educationBlock(edu)),
                    ],
                    if (cv.certifications.isNotEmpty) ...[
                      _mainSection('Certifications'),
                      ...cv.certifications.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(c.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                                Text(c.issuer,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
                              ])),
                              if (c.date.isNotEmpty)
                                Text(c.date, style: const TextStyle(fontSize: 10, color: Color(0xFF999999))),
                            ]),
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),   // SingleChildScrollView
    );   // DefaultTextStyle.merge
  }

  Widget _sideSection(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(title,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
      );

  Widget _sideItem(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text(text, style: const TextStyle(fontSize: 9.5, color: Color(0xFFDDEEF4))),
      );

  Widget _mainSection(String title) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: accent, letterSpacing: 0.5)),
          const Divider(height: 8, thickness: 1, color: accent),
          const SizedBox(height: 4),
        ],
      );

  Widget _experienceBlock(CvExperience exp) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: Text(exp.position,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
            Text('${exp.startDate} – ${exp.endDate.isEmpty ? 'Present' : exp.endDate}',
                style: const TextStyle(fontSize: 9, color: Color(0xFF888888))),
          ]),
          Text(exp.company, style: const TextStyle(fontSize: 10, color: Color(0xFF555555))),
          if (exp.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(exp.description, style: const TextStyle(fontSize: 10, height: 1.4)),
            ),
        ]),
      );

  Widget _educationBlock(CvEducation edu) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: Text('${edu.degree} in ${edu.field}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
            Text('${edu.startDate} – ${edu.endDate.isEmpty ? 'Present' : edu.endDate}',
                style: const TextStyle(fontSize: 9, color: Color(0xFF888888))),
          ]),
          Text(edu.institution, style: const TextStyle(fontSize: 10, color: Color(0xFF555555))),
          if (edu.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(edu.description, style: const TextStyle(fontSize: 10, height: 1.4)),
            ),
        ]),
      );
}

class _MinimalTemplate extends StatelessWidget {
  final CvData cv;
  const _MinimalTemplate({required this.cv});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(color: Color(0xFF212121)),
      child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(children: [
              Text(
                cv.fullName.isNotEmpty ? cv.fullName : 'Your Name',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w300, letterSpacing: 3),
              ),
              if (cv.jobTitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(cv.jobTitle.toUpperCase(),
                    style: const TextStyle(fontSize: 9, letterSpacing: 2.5, color: Color(0xFF888888))),
              ],
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  if (cv.email.isNotEmpty) _contactItem(cv.email),
                  if (cv.phone.isNotEmpty) _contactItem(cv.phone),
                  if (cv.location.isNotEmpty) _contactItem(cv.location),
                  if (cv.linkedin.isNotEmpty) _contactItem(cv.linkedin),
                  if (cv.website.isNotEmpty) _contactItem(cv.website),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 20),
          if (cv.summary.isNotEmpty) ...[
            _minSection('PROFILE'),
            Text(cv.summary,
                textAlign: TextAlign.justify, style: const TextStyle(fontSize: 11, height: 1.6)),
            const SizedBox(height: 16),
          ],
          if (cv.experience.isNotEmpty) ...[
            _minSection('EXPERIENCE'),
            ...cv.experience.map((exp) => _expBlock(exp)),
          ],
          if (cv.education.isNotEmpty) ...[
            _minSection('EDUCATION'),
            ...cv.education.map((edu) => _eduBlock(edu)),
          ],
          if (cv.skills.isNotEmpty) ...[
            _minSection('SKILLS'),
            Text(cv.skills.join('   ·   '),
                style: const TextStyle(fontSize: 11, height: 1.7, color: Color(0xFF333333))),
            const SizedBox(height: 16),
          ],
          if (cv.languages.isNotEmpty) ...[
            _minSection('LANGUAGES'),
            Text(cv.languages.join('   ·   '),
                style: const TextStyle(fontSize: 11, color: Color(0xFF333333))),
            const SizedBox(height: 16),
          ],
          if (cv.certifications.isNotEmpty) ...[
            _minSection('CERTIFICATIONS'),
            ...cv.certifications.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(
                        child: Text('${c.name}, ${c.issuer}',
                            style: const TextStyle(fontSize: 11))),
                    if (c.date.isNotEmpty)
                      Text(c.date, style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                  ]),
                )),
          ],
        ],
      ),
    ),   // SingleChildScrollView
    );   // DefaultTextStyle.merge
  }

  Widget _contactItem(String text) =>
      Text(text, style: const TextStyle(fontSize: 10, color: Color(0xFF666666)));

  Widget _minSection(String title) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2.5, color: Color(0xFF555555))),
          const Divider(height: 10, thickness: 0.5),
          const SizedBox(height: 4),
        ],
      );

  Widget _expBlock(CvExperience exp) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 90,
            child: Text('${exp.startDate}\n${exp.endDate.isEmpty ? 'Present' : exp.endDate}',
                style: const TextStyle(fontSize: 9.5, color: Color(0xFF888888), height: 1.4)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(exp.position, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
              Text(exp.company, style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
              if (exp.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(exp.description, style: const TextStyle(fontSize: 10, height: 1.4)),
                ),
            ]),
          ),
        ]),
      );

  Widget _eduBlock(CvEducation edu) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 90,
            child: Text('${edu.startDate}\n${edu.endDate.isEmpty ? 'Present' : edu.endDate}',
                style: const TextStyle(fontSize: 9.5, color: Color(0xFF888888), height: 1.4)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${edu.degree} in ${edu.field}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
              Text(edu.institution, style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
              if (edu.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(edu.description, style: const TextStyle(fontSize: 10, height: 1.4)),
                ),
            ]),
          ),
        ]),
      );
}