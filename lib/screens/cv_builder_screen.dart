import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../server.dart';
import '../auth.dart';
import 'cv_data.dart';
import 'cv_preview.dart';

class CvBuilderScreen extends StatefulWidget {
  final Server server;
  final Auth auth;
  const CvBuilderScreen({Key? key, required this.server, required this.auth}) : super(key: key);

  @override
  State<CvBuilderScreen> createState() => _CvBuilderScreenState();
}

class _CvBuilderScreenState extends State<CvBuilderScreen> {
  late CvData _cv;
  final _formKey = GlobalKey<FormState>();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _cv = CvData();
    _loadFromUser();
  }

  void _loadFromUser() {
    final user = widget.auth.user;
    if (user != null) {
      setState(() {
        _cv = _cv.copyWith(
          fullName: user.fullName,
          email: user.email,
          // Add more fields if your User model has them
        );
      });
    }
  }

  Future<void> _generateAndDownloadPdf() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isGenerating = true);

    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => _buildPdfContent(_cv),
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/cv_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        await Printing.sharePdf(bytes: await pdf.save(), filename: 'my_cv.pdf');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  pw.Widget _buildPdfContent(CvData cv) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(24),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(cv.fullName.isNotEmpty ? cv.fullName : 'Your Name',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          if (cv.email.isNotEmpty || cv.phone.isNotEmpty || cv.location.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (cv.email.isNotEmpty) pw.Text('${cv.email}', style: pw.TextStyle(fontSize: 10)),
                if (cv.phone.isNotEmpty) pw.Text('${cv.phone}', style: pw.TextStyle(fontSize: 10)),
                if (cv.location.isNotEmpty) pw.Text('${cv.location}', style: pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
          pw.Divider(height: 24),
          if (cv.summary.isNotEmpty) ...[
            pw.Text('Profile', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(cv.summary, style: pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
          ],
          if (cv.skills.isNotEmpty) ...[
            pw.Text('Skills', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Wrap(
              spacing: 8,
              runSpacing: 4,
              children: cv.skills.map((s) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text(s, style: pw.TextStyle(fontSize: 9)),
              )).toList(),
            ),
            pw.SizedBox(height: 12),
          ],
          if (cv.experience.isNotEmpty) ...[
            pw.Text('Experience', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            ...cv.experience.map((exp) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text(exp.position, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text('${exp.startDate} – ${exp.endDate.isEmpty ? 'Present' : exp.endDate}',
                        style: pw.TextStyle(color: PdfColors.grey600, fontSize: 9)),
                  ]),
                  pw.Text(exp.company, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
                  if (exp.description.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(exp.description, style: pw.TextStyle(fontSize: 9)),
                  ],
                ],
              ),
            )),
          ],
          if (cv.education.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Education', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            ...cv.education.map((edu) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('${edu.degree} in ${edu.field}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text('${edu.startDate} – ${edu.endDate.isEmpty ? 'Present' : edu.endDate}',
                        style: pw.TextStyle(color: PdfColors.grey600, fontSize: 9)),
                  ]),
                  pw.Text(edu.institution, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Build Your CV'),
        actions: [
          IconButton(
            icon: _isGenerating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
            onPressed: _isGenerating ? null : _generateAndDownloadPdf,
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: Row(
        children: [
          // Form Panel (60%)
          Expanded(
            flex: 3,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle('Personal Info'),
                  _textField('Full Name', _cv.fullName, (v) => setState(() => _cv = _cv.copyWith(fullName: v)), validator: (v) => v!.isEmpty ? 'Required' : null),
                  _textField('Email', _cv.email, (v) => setState(() => _cv = _cv.copyWith(email: v)), validator: (v) => v!.isNotEmpty && !v.contains('@') ? 'Invalid email' : null),
                  _textField('Phone', _cv.phone, (v) => setState(() => _cv = _cv.copyWith(phone: v))),
                  _textField('Location', _cv.location, (v) => setState(() => _cv = _cv.copyWith(location: v))),
                  _textField('LinkedIn', _cv.linkedin, (v) => setState(() => _cv = _cv.copyWith(linkedin: v))),
                  _textField('GitHub', _cv.github, (v) => setState(() => _cv = _cv.copyWith(github: v))),
                  const SizedBox(height: 16),
                  _sectionTitle('Professional Summary'),
                  _textArea('Summary', _cv.summary, (v) => setState(() => _cv = _cv.copyWith(summary: v))),
                  const SizedBox(height: 16),
                  _sectionTitle('Skills (comma-separated)'),
                  _textField('e.g. Flutter, Django, Python', _cv.skills.join(', '),
                      (v) => setState(() => _cv = _cv.copyWith(skills: v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()))),
                  const SizedBox(height: 16),
                  _sectionTitle('Experience'),
                  ..._cv.experience.asMap().entries.map((e) => _experienceItem(e.value, (updated) {
                        final list = List<CvExperience>.from(_cv.experience);
                        list[e.key] = updated;
                        setState(() => _cv = _cv.copyWith(experience: list));
                      }, () {
                        final list = List<CvExperience>.from(_cv.experience);
                        list.removeAt(e.key);
                        setState(() => _cv = _cv.copyWith(experience: list));
                      })),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _cv = _cv.copyWith(experience: [..._cv.experience, CvExperience(company: '', position: '', startDate: '', description: '')])),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Experience'),
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle('Education'),
                  ..._cv.education.asMap().entries.map((e) => _educationItem(e.value, (updated) {
                        final list = List<CvEducation>.from(_cv.education);
                        list[e.key] = updated;
                        setState(() => _cv = _cv.copyWith(education: list));
                      }, () {
                        final list = List<CvEducation>.from(_cv.education);
                        list.removeAt(e.key);
                        setState(() => _cv = _cv.copyWith(education: list));
                      })),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _cv = _cv.copyWith(education: [..._cv.education, CvEducation(institution: '', degree: '', field: '', startDate: '')])),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Education'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // Preview Panel (40%)
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey.shade100,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Preview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(child: CvPreview(cv: _cv)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _textField(String label, String value, Function(String) onChanged, {String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  Widget _textArea(String label, String value, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, alignLabelWithHint: true),
        onChanged: onChanged,
        maxLines: 4,
        textAlignVertical: TextAlignVertical.top,
      ),
    );
  }

  Widget _experienceItem(CvExperience exp, Function(CvExperience) onUpdate, VoidCallback onDelete) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Experience', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: onDelete, tooltip: 'Remove'),
              ],
            ),
            _textField('Company', exp.company, (v) => onUpdate(exp.copyWith(company: v))),
            _textField('Position', exp.position, (v) => onUpdate(exp.copyWith(position: v))),
            Row(
              children: [
                Expanded(child: _textField('Start Date', exp.startDate, (v) => onUpdate(exp.copyWith(startDate: v)))),
                const SizedBox(width: 8),
                Expanded(child: _textField('End Date', exp.endDate, (v) => onUpdate(exp.copyWith(endDate: v)))),
              ],
            ),
            _textArea('Description', exp.description, (v) => onUpdate(exp.copyWith(description: v))),
          ],
        ),
      ),
    );
  }

  Widget _educationItem(CvEducation edu, Function(CvEducation) onUpdate, VoidCallback onDelete) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Education', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: onDelete, tooltip: 'Remove'),
              ],
            ),
            _textField('Institution', edu.institution, (v) => onUpdate(edu.copyWith(institution: v))),
            Row(
              children: [
                Expanded(child: _textField('Degree', edu.degree, (v) => onUpdate(edu.copyWith(degree: v)))),
                const SizedBox(width: 8),
                Expanded(child: _textField('Field', edu.field, (v) => onUpdate(edu.copyWith(field: v)))),
              ],
            ),
            Row(
              children: [
                Expanded(child: _textField('Start Date', edu.startDate, (v) => onUpdate(edu.copyWith(startDate: v)))),
                const SizedBox(width: 8),
                Expanded(child: _textField('End Date', edu.endDate, (v) => onUpdate(edu.copyWith(endDate: v)))),
              ],
            ),
            _textArea('Description', edu.description, (v) => onUpdate(edu.copyWith(description: v))),
          ],
        ),
      ),
    );
  }
}