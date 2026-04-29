import 'package:flutter/material.dart';
import 'cv_data.dart';

class CvPreview extends StatelessWidget {
  final CvData cv;
  const CvPreview({Key? key, required this.cv}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(cv.fullName.isNotEmpty ? cv.fullName : 'Your Name',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          if (cv.email.isNotEmpty || cv.phone.isNotEmpty || cv.location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (cv.email.isNotEmpty) Text('${cv.email}', style: const TextStyle(fontSize: 12)),
                if (cv.phone.isNotEmpty) Text('${cv.phone}', style: const TextStyle(fontSize: 12)),
                if (cv.location.isNotEmpty) Text('${cv.location}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
          if (cv.linkedin.isNotEmpty || cv.github.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              children: [
                if (cv.linkedin.isNotEmpty) Text('${cv.linkedin}', style: const TextStyle(fontSize: 12)),
                if (cv.github.isNotEmpty) Text('${cv.github}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
          const Divider(height: 32),
          // Summary
          if (cv.summary.isNotEmpty) ...[
            Text('Profile', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(cv.summary, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
          ],
          // Skills
          if (cv.skills.isNotEmpty) ...[
            Text('Skills', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cv.skills.map((s) => Chip(
                label: Text(s, style: const TextStyle(fontSize: 11)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],
          // Experience
          if (cv.experience.isNotEmpty) ...[
            Text('Experience', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...cv.experience.map((exp) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(exp.position, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${exp.startDate} – ${exp.endDate.isEmpty ? 'Present' : exp.endDate}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ]),
                  Text(exp.company, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  if (exp.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(exp.description, style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            )),
            const SizedBox(height: 16),
          ],
          // Education
          if (cv.education.isNotEmpty) ...[
            Text('Education', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...cv.education.map((edu) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${edu.degree} in ${edu.field}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${edu.startDate} – ${edu.endDate.isEmpty ? 'Present' : edu.endDate}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ]),
                  Text(edu.institution, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  if (edu.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(edu.description, style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}