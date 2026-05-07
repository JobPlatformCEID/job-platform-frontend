// cv_builder_screen.dart
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../server_api.dart';
import '../auth.dart';
import 'cv_data.dart';
import 'cv_preview.dart';
import '../user.dart';

// Breakpoint below which the live preview panel is hidden
const double _kPreviewBreakpoint = 700.0;

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
  int _currentStep = 0;

  static const List<String> _steps = [
    'Template',
    'Personal',
    'Summary',
    'Experience',
    'Education',
    'Skills',
    'Extra',
  ];

  @override
  void initState() {
    super.initState();
    _cv = CvData();
    _loadFromUser();
  }

Future<void> _loadFromUser() async {
  final user = widget.auth.user;
  if (user == null || user is! Candidate) return;

  await Future.wait([
    user.fetchProfile(),
    user.fetchSkills(),
    user.fetchEducations(),
    user.fetchExperiences(),
  ]);

  setState(() {
    _cv = _cv.copyWith(
      fullName: user.fullName,
      email: user.email,
      phone: user.phone,
      location: user.location,
      summary: user.bio,
      skills: user.skills.map((s) => s.name).toList(),
      education: user.educations.map((e) => CvEducation(
        institution: e.institution,
        degree: _formatLevel(e.level),
        field: e.degree,
        startDate: '',
        endDate: e.graduationDate ?? '',
      )).toList(),
      experience: user.experiences.map((e) => CvExperience(
        company: e.company,
        position: e.title,
        startDate: e.startDate,
        endDate: e.endDate ?? '',
        description: e.description,
      )).toList(),
    );
  });
}

// Converts the stored level key into a readable degree label
String _formatLevel(String level) {
  switch (level) {
    case 'high_school':   return 'High School Diploma';
    case 'bachelor':      return "Bachelor's";
    case 'master':        return "Master's";
    case 'phd':           return 'PhD';
    default:              return level;
  }
}

  // PDF generation & direct download (no share sheet)
  Future<void> _generateAndDownloadPdf() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isGenerating = true);

    try {
      // Load Noto Sans — full Unicode coverage including Greek
      final fontRegular = await PdfGoogleFonts.notoSansRegular();
      final fontBold    = await PdfGoogleFonts.notoSansBold();
      final fontItalic  = await PdfGoogleFonts.notoSansItalic();

      // Build a theme so every pw.Text in every template inherits the font
      final theme = pw.ThemeData.withFont(
        base:   fontRegular,
        bold:   fontBold,
        italic: fontItalic,
      );

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          build: (pw.Context context) {
            switch (_cv.template) {
              case CvTemplate.modern:
                return _buildModernPdf(_cv);
              case CvTemplate.minimal:
                return _buildMinimalPdf(_cv);
              case CvTemplate.classic:
              default:
                return _buildClassicPdf(_cv);
            }
          },
        ),
      );

      final bytes = await pdf.save();

      final name = _cv.fullName.isNotEmpty
          ? _cv.fullName.trim().replaceAll(' ', '_')
          : 'cv';

      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: '${name}_cv.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
  
  // PDF builders
  pw.Widget _buildClassicPdf(CvData cv) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(28),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(cv.fullName.isNotEmpty ? cv.fullName : 'Your Name',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          if (cv.jobTitle.isNotEmpty)
            pw.Text(cv.jobTitle, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 6),
          pw.Text(
            [cv.email, cv.phone, cv.location, cv.linkedin, cv.website]
                .where((s) => s.isNotEmpty)
                .join('   |   '),
            style: pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 10),
          pw.Container(height: 0.8, color: PdfColors.grey500),
          pw.SizedBox(height: 8),
          if (cv.summary.isNotEmpty) ...[
            _pdfSectionTitle('Profile'),
            pw.Text(cv.summary, style: pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 10),
          ],
          if (cv.skills.isNotEmpty) ...[
            _pdfSectionTitle('Skills'),
            pw.Text(cv.skills.join('   ·   '), style: pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 10),
          ],
          if (cv.experience.isNotEmpty) ...[
            _pdfSectionTitle('Experience'),
            ...cv.experience.map((exp) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text(exp.position, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('${exp.startDate} - ${exp.endDate.isEmpty ? 'Present' : exp.endDate}',
                          style: pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
                    ]),
                    pw.Text(exp.company, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 9)),
                    if (exp.description.isNotEmpty)
                      pw.Text(exp.description, style: pw.TextStyle(fontSize: 8)),
                  ]),
                )),
          ],
          if (cv.education.isNotEmpty) ...[
            _pdfSectionTitle('Education'),
            ...cv.education.map((edu) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('${edu.degree} in ${edu.field}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('${edu.startDate} - ${edu.endDate.isEmpty ? 'Present' : edu.endDate}',
                          style: pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
                    ]),
                    pw.Text(edu.institution, style: pw.TextStyle(color: PdfColors.grey700, fontSize: 9)),
                  ]),
                )),
          ],
          if (cv.certifications.isNotEmpty) ...[
            _pdfSectionTitle('Certifications'),
            ...cv.certifications.map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(c.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text(c.issuer, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ]),
                    if (c.date.isNotEmpty)
                      pw.Text(c.date, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ]),
                )),
          ],
          if (cv.languages.isNotEmpty) ...[
            _pdfSectionTitle('Languages'),
            pw.Text(cv.languages.join('  ·  '), style: pw.TextStyle(fontSize: 9)),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildModernPdf(CvData cv) {
    const PdfColor accent = PdfColor.fromInt(0xFF1E5F74);
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      // Sidebar
      pw.Container(
        width: 150,
        color: accent,
        padding: const pw.EdgeInsets.all(16),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(cv.fullName.isNotEmpty ? cv.fullName : 'Your Name',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          if (cv.jobTitle.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(cv.jobTitle, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey300)),
          ],
          pw.SizedBox(height: 14),
          pw.Text('CONTACT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 1)),
          pw.SizedBox(height: 4),
          if (cv.email.isNotEmpty) pw.Text(cv.email, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey300)),
          if (cv.phone.isNotEmpty) pw.Text(cv.phone, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey300)),
          if (cv.location.isNotEmpty) pw.Text(cv.location, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey300)),
          if (cv.linkedin.isNotEmpty) pw.Text(cv.linkedin, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey300)),
          if (cv.website.isNotEmpty) pw.Text(cv.website, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey300)),
          if (cv.skills.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('SKILLS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 1)),
            pw.SizedBox(height: 4),
            ...cv.skills.map((s) => pw.Text(s, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey300))),
          ],
          if (cv.languages.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('LANGUAGES', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 1)),
            pw.SizedBox(height: 4),
            ...cv.languages.map((l) => pw.Text(l, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey300))),
          ],
        ]),
      ),
      pw.SizedBox(width: 16),
      // Main
      pw.Expanded(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (cv.summary.isNotEmpty) ...[
            _modernPdfSection('Profile', accent),
            pw.Text(cv.summary, style: pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 10),
          ],
          if (cv.experience.isNotEmpty) ...[
            _modernPdfSection('Experience', accent),
            ...cv.experience.map((exp) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text(exp.position, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('${exp.startDate} - ${exp.endDate.isEmpty ? 'Present' : exp.endDate}',
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ]),
                    pw.Text(exp.company, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    if (exp.description.isNotEmpty) pw.Text(exp.description, style: pw.TextStyle(fontSize: 8)),
                  ]),
                )),
          ],
          if (cv.education.isNotEmpty) ...[
            _modernPdfSection('Education', accent),
            ...cv.education.map((edu) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('${edu.degree} in ${edu.field}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('${edu.startDate} - ${edu.endDate.isEmpty ? 'Present' : edu.endDate}',
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ]),
                    pw.Text(edu.institution, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ]),
                )),
          ],
          if (cv.certifications.isNotEmpty) ...[
            _modernPdfSection('Certifications', accent),
            ...cv.certifications.map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(c.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text(c.issuer, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ]),
                    if (c.date.isNotEmpty)
                      pw.Text(c.date, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ]),
                )),
          ],
        ]),
      ),
    ]);
  }

  pw.Widget _buildMinimalPdf(CvData cv) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Center(
            child: pw.Column(children: [
              pw.Text(cv.fullName.isNotEmpty ? cv.fullName : 'Your Name',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.normal, letterSpacing: 3)),
              if (cv.jobTitle.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(cv.jobTitle.toUpperCase(),
                    style: pw.TextStyle(fontSize: 8, letterSpacing: 2.5, color: PdfColors.grey600)),
              ],
              pw.SizedBox(height: 6),
              pw.Text(
                [cv.email, cv.phone, cv.location]
                    .where((s) => s.isNotEmpty)
                    .join('   |   '),
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ]),
          ),
          pw.SizedBox(height: 18),
          if (cv.summary.isNotEmpty) ...[
            _minimalPdfSection('PROFILE'),
            pw.Text(cv.summary, style: pw.TextStyle(fontSize: 9, lineSpacing: 4)),
            pw.SizedBox(height: 12),
          ],
          if (cv.experience.isNotEmpty) ...[
            _minimalPdfSection('EXPERIENCE'),
            ...cv.experience.map((exp) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.SizedBox(
                        width: 80,
                        child: pw.Text(
                            '${exp.startDate}\n${exp.endDate.isEmpty ? 'Present' : exp.endDate}',
                            style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600))),
                    pw.Expanded(
                        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(exp.position, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      pw.Text(exp.company, style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                      if (exp.description.isNotEmpty) pw.Text(exp.description, style: pw.TextStyle(fontSize: 8)),
                    ])),
                  ]),
                )),
          ],
          if (cv.education.isNotEmpty) ...[
            _minimalPdfSection('EDUCATION'),
            ...cv.education.map((edu) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.SizedBox(
                        width: 80,
                        child: pw.Text(
                            '${edu.startDate}\n${edu.endDate.isEmpty ? 'Present' : edu.endDate}',
                            style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600))),
                    pw.Expanded(
                        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text('${edu.degree} in ${edu.field}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      pw.Text(edu.institution, style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    ])),
                  ]),
                )),
          ],
          if (cv.skills.isNotEmpty) ...[
            _minimalPdfSection('SKILLS'),
            pw.Text(cv.skills.join('   ·   '), style: pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 12),
          ],
          if (cv.languages.isNotEmpty) ...[
            _minimalPdfSection('LANGUAGES'),
            pw.Text(cv.languages.join('   ·   '), style: pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 12),
          ],
          if (cv.certifications.isNotEmpty) ...[
            _minimalPdfSection('CERTIFICATIONS'),
            ...cv.certifications.map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(c.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      pw.Text(c.issuer, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ]),
                    if (c.date.isNotEmpty)
                      pw.Text(c.date, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ]),
                )),
          ],
        ],
      ),
    );
  }

  pw.Widget _pdfSectionTitle(String title) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Container(height: 0.8, color: PdfColors.grey500),
          pw.SizedBox(height: 5),
        ],
      );

  pw.Widget _modernPdfSection(String title, PdfColor color) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 3),
          pw.Container(height: 0.8, color: color),
          pw.SizedBox(height: 5),
        ],
      );

  pw.Widget _minimalPdfSection(String title) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, letterSpacing: 2, color: PdfColors.grey600)),
          pw.SizedBox(height: 3),
          pw.Container(height: 0.4, color: PdfColors.grey500),
          pw.SizedBox(height: 4),
        ],
      );


  /// Opens a full-screen live preview (used on narrow screens).
  void _openPreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenPreview(cv: _cv),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < _kPreviewBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('CV Builder'),
        elevation: 0,
        actions: [
          // On narrow screens show a "Preview" button
          if (isNarrow)
            TextButton.icon(
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Preview'),
              onPressed: _openPreview,
            ),
          TextButton.icon(
            icon: _isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: const Text('Export PDF'),
            onPressed: _isGenerating ? null : _generateAndDownloadPdf,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isNarrow
          ? Column(
              children: [
                _buildStepBar(),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: _buildCurrentStep(),
                  ),
                ),
                _buildNavButtons(),
              ],
            )
          : Row(
              children: [
                // Left: step-nav + form
                SizedBox(
                  width: screenWidth * 0.55,
                  child: Column(
                    children: [
                      _buildStepBar(),
                      Expanded(
                        child: Form(
                          key: _formKey,
                          child: _buildCurrentStep(),
                        ),
                      ),
                      _buildNavButtons(),
                    ],
                  ),
                ),
                // Right: live preview panel
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 12,
                          offset: Offset(-4, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          color: const Color(0xFFEEEEEE),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: const Center(
                            child: Text(
                              'Live Preview',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF555555),
                              ),
                            ),
                          ),
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

  // Step bar
  Widget _buildStepBar() {
    return Container(
      height: 52,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _steps.length,
        itemBuilder: (context, i) {
          final isActive = i == _currentStep;
          return GestureDetector(
            onTap: () => setState(() => _currentStep = i),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive ? Theme.of(context).primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                _steps[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? Colors.white : const Color(0xFF666666),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  
  Widget _buildNavButtons() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: () => setState(() => _currentStep--),
              child: const Text('Back'),
            )
          else
            const SizedBox.shrink(),
          if (_currentStep < _steps.length - 1)
            ElevatedButton(
              onPressed: () => setState(() => _currentStep++),
              child: const Text('Next'),
            )
          else
            ElevatedButton(
              onPressed: _isGenerating ? null : _generateAndDownloadPdf,
              child: const Text('Export PDF'),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _stepTemplate();
      case 1: return _stepPersonal();
      case 2: return _stepSummary();
      case 3: return _stepExperience();
      case 4: return _stepEducation();
      case 5: return _stepSkills();
      case 6: return _stepExtra();
      default: return const SizedBox.shrink();
    }
  }

  // Step 0: Template 
  Widget _stepTemplate() {
    final templates = [
      (CvTemplate.classic, 'Classic', 'Traditional layout with clear sections and a clean header.'),
      (CvTemplate.modern, 'Modern', 'Two-column design with an accent sidebar for a bold look.'),
      (CvTemplate.minimal, 'Minimal', 'Typography-first, centered header, understated and elegant.'),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _stepTitle('Choose a Template'),
        const SizedBox(height: 12),
        ...templates.map((t) {
          final selected = _cv.template == t.$1;
          return GestureDetector(
            onTap: () => setState(() => _cv = _cv.copyWith(template: t.$1)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? Theme.of(context).primaryColor : const Color(0xFFDDDDDD),
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.15), blurRadius: 8)]
                    : [],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Radio<CvTemplate>(
                  value: t.$1,
                  groupValue: _cv.template,
                  onChanged: (v) => setState(() => _cv = _cv.copyWith(template: v)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF212121))),
                    const SizedBox(height: 2),
                    Text(t.$3, style: const TextStyle(fontSize: 12, color: Color(0xFF777777))),
                  ]),
                ),
              ]),
            ),
          );
        }),
      ],
    );
  }

  // Step 1: Personal Info
  Widget _stepPersonal() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _stepTitle('Personal Information'),
        _field('Full Name', _cv.fullName, (v) => _cv = _cv.copyWith(fullName: v),
            validator: (v) => v!.isEmpty ? 'Required' : null),
        _field('Job Title', _cv.jobTitle, (v) => _cv = _cv.copyWith(jobTitle: v),
            hint: 'e.g. Marketing Manager, Teacher, Designer'),
        _field('Email', _cv.email, (v) => _cv = _cv.copyWith(email: v),
            validator: (v) => v!.isNotEmpty && !v.contains('@') ? 'Invalid email' : null),
        _field('Phone', _cv.phone, (v) => _cv = _cv.copyWith(phone: v)),
        _field('Location', _cv.location, (v) => _cv = _cv.copyWith(location: v),
            hint: 'City, Country'),
        _field('LinkedIn', _cv.linkedin, (v) => _cv = _cv.copyWith(linkedin: v),
            hint: 'linkedin.com/in/yourname'),
        _field('Website / Portfolio', _cv.website, (v) => _cv = _cv.copyWith(website: v),
            hint: 'yourwebsite.com'),
      ],
    );
  }

  // Step 2: Summary 
  Widget _stepSummary() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _stepTitle('Professional Summary'),
        const Text(
          'A short paragraph (2–4 sentences) describing who you are, your background, and what you bring to a role.',
          style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
        ),
        const SizedBox(height: 16),
        _textArea('Summary', _cv.summary, (v) => _cv = _cv.copyWith(summary: v), maxLines: 6),
      ],
    );
  }

  // Step 3: Experience 
  Widget _stepExperience() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _stepTitle('Work Experience'),
        ..._cv.experience.asMap().entries.map((e) => _experienceCard(
              e.value,
              (updated) {
                final list = List<CvExperience>.from(_cv.experience);
                list[e.key] = updated;
                setState(() => _cv = _cv.copyWith(experience: list));
              },
              () {
                final list = List<CvExperience>.from(_cv.experience);
                list.removeAt(e.key);
                setState(() => _cv = _cv.copyWith(experience: list));
              },
            )),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => setState(() => _cv = _cv.copyWith(
                experience: [
                  ..._cv.experience,
                  CvExperience(company: '', position: '', startDate: '', description: ''),
                ],
              )),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Position'),
        ),
      ],
    );
  }

  // Step 4: Education
  Widget _stepEducation() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _stepTitle('Education'),
        ..._cv.education.asMap().entries.map((e) => _educationCard(
              e.value,
              (updated) {
                final list = List<CvEducation>.from(_cv.education);
                list[e.key] = updated;
                setState(() => _cv = _cv.copyWith(education: list));
              },
              () {
                final list = List<CvEducation>.from(_cv.education);
                list.removeAt(e.key);
                setState(() => _cv = _cv.copyWith(education: list));
              },
            )),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => setState(() => _cv = _cv.copyWith(
                education: [
                  ..._cv.education,
                  CvEducation(institution: '', degree: '', field: '', startDate: ''),
                ],
              )),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Education'),
        ),
      ],
    );
  }

  // Step 5: Skills
  Widget _stepSkills() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _stepTitle('Skills'),
        const Text('Enter your skills separated by commas.',
            style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
        const SizedBox(height: 12),
        _field(
          'Skills',
          _cv.skills.join(', '),
          (v) => _cv = _cv.copyWith(
              skills: v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()),
          hint: 'e.g. Project Management, Public Speaking, Data Analysis',
        ),
      ],
    );
  }

  // Step 6: Extra (Certifications + Languages)
  Widget _stepExtra() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _stepTitle('Additional Information'),
        _subTitle('Languages'),
        const Text('Languages you speak, separated by commas.',
            style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
        const SizedBox(height: 8),
        _field(
          'Languages',
          _cv.languages.join(', '),
          (v) => _cv = _cv.copyWith(
              languages: v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()),
          hint: 'e.g. English (Fluent), Spanish (Intermediate)',
        ),
        const SizedBox(height: 16),
        _subTitle('Certifications'),
        ..._cv.certifications.asMap().entries.map((e) => _certCard(
              e.value,
              (updated) {
                final list = List<CvCertification>.from(_cv.certifications);
                list[e.key] = updated;
                setState(() => _cv = _cv.copyWith(certifications: list));
              },
              () {
                final list = List<CvCertification>.from(_cv.certifications);
                list.removeAt(e.key);
                setState(() => _cv = _cv.copyWith(certifications: list));
              },
            )),
        OutlinedButton.icon(
          onPressed: () => setState(() => _cv = _cv.copyWith(
                certifications: [
                  ..._cv.certifications,
                  CvCertification(name: '', issuer: ''),
                ],
              )),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Certification'),
        ),
      ],
    );
  }

  // Shared form helpers 
  Widget _stepTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF212121))),
      );

  Widget _subTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF212121))),
      );

  Widget _field(String label, String value, Function(String) onChanged,
      {String? hint, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        initialValue: value,
        style: const TextStyle(color: Color(0xFF212121)),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: Color(0xFF555555)),
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        ),
        onChanged: (v) => setState(() => onChanged(v)),
        validator: validator,
      ),
    );
  }

  Widget _textArea(String label, String value, Function(String) onChanged, {int maxLines = 4}) {
    return TextFormField(
      initialValue: value,
      style: const TextStyle(color: Color(0xFF212121)),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        alignLabelWithHint: true,
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: Color(0xFF555555)),
      ),
      onChanged: (v) => setState(() => onChanged(v)),
      maxLines: maxLines,
      textAlignVertical: TextAlignVertical.top,
    );
  }

  Widget _experienceCard(CvExperience exp, Function(CvExperience) onUpdate, VoidCallback onDelete) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color.fromARGB(166, 0, 212, 184),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Position', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF212121))),
            IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints()),
          ]),
          const SizedBox(height: 8),
          _field('Company / Organisation', exp.company, (v) => onUpdate(exp.copyWith(company: v))),
          _field('Position / Role', exp.position, (v) => onUpdate(exp.copyWith(position: v))),
          Row(children: [
            Expanded(child: _field('Start Date', exp.startDate, (v) => onUpdate(exp.copyWith(startDate: v)))),
            const SizedBox(width: 10),
            Expanded(child: _field('End Date', exp.endDate, (v) => onUpdate(exp.copyWith(endDate: v)),
                hint: 'Leave blank if current')),
          ]),
          _textArea('Description', exp.description, (v) => onUpdate(exp.copyWith(description: v))),
        ]),
      ),
    );
  }

  Widget _educationCard(CvEducation edu, Function(CvEducation) onUpdate, VoidCallback onDelete) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color.fromARGB(166, 0, 212, 184),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Qualification', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF212121))),
            IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints()),
          ]),
          const SizedBox(height: 8),
          _field('Institution', edu.institution, (v) => onUpdate(edu.copyWith(institution: v))),
          Row(children: [
            Expanded(child: _field('Degree / Award', edu.degree, (v) => onUpdate(edu.copyWith(degree: v)))),
            const SizedBox(width: 10),
            Expanded(child: _field('Subject / Field', edu.field, (v) => onUpdate(edu.copyWith(field: v)))),
          ]),
          Row(children: [
            Expanded(child: _field('Start Date', edu.startDate, (v) => onUpdate(edu.copyWith(startDate: v)))),
            const SizedBox(width: 10),
            Expanded(child: _field('End Date', edu.endDate, (v) => onUpdate(edu.copyWith(endDate: v)),
                hint: 'Leave blank if current')),
          ]),
          _textArea('Notes', edu.description, (v) => onUpdate(edu.copyWith(description: v))),
        ]),
      ),
    );
  }

  Widget _certCard(CvCertification cert, Function(CvCertification) onUpdate, VoidCallback onDelete) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color.fromARGB(166, 0, 212, 184),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Certification', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF212121))),
            IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints()),
          ]),
          const SizedBox(height: 8),
          _field('Certificate Name', cert.name, (v) => onUpdate(cert.copyWith(name: v))),
          Row(children: [
            Expanded(child: _field('Issuing Body', cert.issuer, (v) => onUpdate(cert.copyWith(issuer: v)))),
            const SizedBox(width: 10),
            Expanded(child: _field('Date', cert.date, (v) => onUpdate(cert.copyWith(date: v)))),
          ]),
        ]),
      ),
    );
  }
}

// Full-screen preview page (used on narrow / phone screens)
class _FullScreenPreview extends StatelessWidget {
  final CvData cv;
  const _FullScreenPreview({required this.cv});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      appBar: AppBar(
        title: const Text('Preview'),
        elevation: 0,
        // The default back button returns to the exact scroll position in the
        // builder because the builder is still alive in the navigation stack.
      ),
      body: CvPreview(cv: cv),
    );
  }
}