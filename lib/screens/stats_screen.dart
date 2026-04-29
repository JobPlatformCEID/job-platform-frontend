import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../server.dart';

class StatsScreen extends StatefulWidget {
  final Server server;
  const StatsScreen({Key? key, required this.server}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _filterController = TextEditingController();
  late final TabController _tabController;

  List<dynamic> _salaryDistribution = [];
  List<dynamic> _jobsByTitle = [];
  List<dynamic> _topSkills = [];
  List<dynamic> _topCompanies = [];
  List<dynamic> _avgSalaryByTitle = [];
  List<dynamic> _jobsOverTime = [];
  List<dynamic> _remoteVsOnsite = [];
  List<dynamic> _jobsByContract = [];
  List<dynamic> _avgSalaryByContract = [];
  List<dynamic> _candidatesByEducation = [];
  List<dynamic> _mostCompetitive = [];

  bool _isLoading = true;
  String? _error;
  String _activeFilter = '';

  static const _supportsFilter = {
    'salaryDistribution': true,
    'jobsByTitle': false,
    'topSkills': true,
    'topCompanies': true,
    'avgSalaryByTitle': false,
    'jobsOverTime': true,
    'remoteVsOnsite': true,
    'jobsByContract': true,
    'avgSalaryByContract': true,
    'candidatesByEducation': true,
    'mostCompetitive': false,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _filterController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _activeFilter = _filterController.text.trim();
    });

    try {
      final query = _activeFilter.isNotEmpty
          ? '?title=${Uri.encodeComponent(_activeFilter)}'
          : '';

      final futures = <Future<List<dynamic>>>[
        widget.server.sendGetList('/api/salary-range-distribution/$query'),
        widget.server.sendGetList('/api/jobs-by-title/'),
        widget.server.sendGetList('/api/top-skills/$query'),
        widget.server.sendGetList('/api/top-companies/$query'),
        widget.server.sendGetList('/api/avg-salary-by-title/'),
        _activeFilter.isNotEmpty
            ? widget.server.sendGetList('/api/jobs-over-time/$query')
            : Future.value(<dynamic>[]),
        widget.server.sendGetList('/api/remote-vs-onsite/$query'),
        widget.server.sendGetList('/api/jobs-by-contract-type/$query'),
        widget.server.sendGetList('/api/avg-salary-by-contract-type/$query'),
        widget.server.sendGetList('/api/candidates-by-education/$query'),
        widget.server.sendGetList('/api/most-competitive-jobs/'),
      ];

      final results = await Future.wait(futures);

      setState(() {
        _salaryDistribution = results[0];
        _jobsByTitle = results[1];
        _topSkills = results[2];
        _topCompanies = results[3];
        _avgSalaryByTitle = results[4];
        _jobsOverTime = results[5];
        _remoteVsOnsite = results[6];
        _jobsByContract = results[7];
        _avgSalaryByContract = results[8];
        _candidatesByEducation = results[9];
        _mostCompetitive = results[10];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('ServerException', '').trim();
        _isLoading = false;
      });
      debugPrint('Stats load error: $e');
    }
  }

  bool _shouldShowChart(String key) {
    if (_activeFilter.isEmpty) return true;
    return _supportsFilter[key] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Statistics'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.attach_money), text: 'Compensation'),
            Tab(icon: Icon(Icons.work), text: 'Job Market'),
            Tab(icon: Icon(Icons.school), text: 'Skills & Candidates'),
            Tab(icon: Icon(Icons.business_center), text: 'Work Arrangements'),
            Tab(icon: Icon(Icons.trending_up), text: 'Trends'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadStats,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _filterController,
                    decoration: InputDecoration(
                      hintText: 'Filter by job title...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _loadStats(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadStats,
                  icon: const Icon(Icons.filter_alt, size: 18),
                  label: const Text('Apply'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                if (_activeFilter.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _filterController.clear();
                      _loadStats();
                    },
                    tooltip: 'Clear filter',
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCompensationTab(),
                          _buildJobMarketTab(),
                          _buildSkillsCandidatesTab(),
                          _buildWorkArrangementsTab(),
                          _buildTrendsTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompensationTab() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_shouldShowChart('salaryDistribution'))
            _buildChartCard(
              title: 'Salary Range Distribution',
              subtitle: 'Entry-level salary brackets',
              chart: () => _buildVerticalBarChart(
                _salaryDistribution,
                'range',
                'count',
                Colors.blue.shade700,
              ),
              data: _salaryDistribution,
              height: 320,
            ),
          if (_shouldShowChart('avgSalaryByTitle'))
            _buildChartCard(
              title: 'Average Salary by Job Title',
              subtitle: 'Min/Max ranges across all positions',
              chart: () => _buildSalaryRangeList(
                _avgSalaryByTitle,
                'title',
                'avg_min',
                'avg_max',
              ),
              data: _avgSalaryByTitle,
              height: 280,
            ),
          if (_shouldShowChart('avgSalaryByContract'))
            _buildChartCard(
              title: 'Average Salary by Contract Type',
              subtitle: 'Compensation by employment type',
              chart: () => _buildSalaryRangeList(
                _avgSalaryByContract,
                'contract_type',
                'avg_min',
                'avg_max',
              ),
              data: _avgSalaryByContract,
              height: 220,
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildJobMarketTab() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_shouldShowChart('jobsByTitle'))
            _buildChartCard(
              title: 'Most Posted Job Titles',
              subtitle: 'Global demand across all positions',
              chart: () => _buildHorizontalBarChartWithBottomLabels(
                _jobsByTitle,
                'title',
                'count',
                Colors.blue,
              ),
              data: _jobsByTitle,
              height: 340,
            ),
          if (_shouldShowChart('topCompanies'))
            _buildChartCard(
              title: 'Top Hiring Companies',
              subtitle: 'Most active employers',
              chart: () => _buildHorizontalBarChartWithBottomLabels(
                _topCompanies,
                'company',
                'count',
                Colors.teal,
              ),
              data: _topCompanies,
              height: 340,
            ),
          if (_shouldShowChart('mostCompetitive'))
            _buildSimpleListCard(
              title: 'Most Competitive Positions',
              subtitle: 'Jobs with highest application counts',
              data: _mostCompetitive,
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSkillsCandidatesTab() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_shouldShowChart('topSkills'))
            _buildChartCard(
              title: 'Most In-Demand Skills',
              subtitle: 'Top required technical skills',
              chart: () => _buildHorizontalBarChartWithBottomLabels(
                _topSkills,
                'skill',
                'count',
                Colors.purple,
              ),
              data: _topSkills,
              height: 340,
            ),
          if (_shouldShowChart('candidatesByEducation'))
            _buildChartCard(
              title: 'Candidates by Education Level',
              subtitle: 'Distribution of applicant qualifications',
              chart: () => _buildDonutChartWithLegend(
                _candidatesByEducation,
                'level',
                [Colors.cyan, Colors.deepPurple, Colors.pink, Colors.brown],
              ),
              data: _candidatesByEducation,
              height: 300,
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildWorkArrangementsTab() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              if (_shouldShowChart('remoteVsOnsite'))
                Expanded(
                  child: _buildChartCard(
                    title: 'Remote vs On-site',
                    subtitle: 'Work location distribution',
                    chart: () => _buildDonutChartWithLegend(
                      _remoteVsOnsite,
                      'type',
                      [Colors.green, Colors.orange],
                    ),
                    data: _remoteVsOnsite,
                    height: 280,
                  ),
                ),
              if (_shouldShowChart('jobsByContract')) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildChartCard(
                    title: 'Contract Types',
                    subtitle: 'Employment agreement breakdown',
                    chart: () => _buildDonutChartWithLegend(
                      _jobsByContract,
                      'contract_type',
                      [Colors.indigo, Colors.amber, Colors.red, Colors.teal],
                    ),
                    data: _jobsByContract,
                    height: 280,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTrendsTab() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_activeFilter.isEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade400, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Enter a job title filter to view posting trends over time',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          if (_shouldShowChart('jobsOverTime'))
            _buildChartCard(
              title: 'Job Postings Over Time',
              subtitle: 'Daily posting volume for "${_activeFilter}"',
              chart: _buildLineChart,
              data: _jobsOverTime,
              height: 300,
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error loading statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    String? subtitle,
    required Widget Function() chart,
    required List<dynamic> data,
    required double height,
  }) {
    if (data.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(Icons.bar_chart, color: Colors.grey.shade400, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No data available',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(height: height, child: chart()),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleListCard({
    required String title,
    String? subtitle,
    required List<dynamic> data,
  }) {
    if (data.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No data available',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...data.take(10).map((item) {
              final title = item['title']?.toString() ?? 'Unknown';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          '#${data.indexOf(item) + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalBarChartWithBottomLabels(
    List<dynamic> data,
    String labelKey,
    String valueKey,
    Color color,
  ) {
    if (data.isEmpty) return _emptyState();
    final items = data.take(8).toList();
    final values =
        items.map((e) => (e[valueKey] as num).toDouble()).toList();
    final maxValue = values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);
    final safeMax = (maxValue > 0 ? maxValue * 1.15 : 10.0).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: safeMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: const EdgeInsets.all(10),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final idx = group.x.toInt();
              if (idx < 0 || idx >= items.length) return null;
              final item = items[idx];
              return BarTooltipItem(
                '${item[labelKey]}\n${item[valueKey]} postings',
                const TextStyle(color: Colors.white, fontSize: 13),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= items.length) return const SizedBox();
                final item = items[index];
                final label = item[labelKey]?.toString() ?? '';
                final displayLabel =
                    label.length > 12 ? '${label.substring(0, 12)}...' : label;
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    displayLabel,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: items.asMap().entries.map((entry) {
          final index = entry.key;
          final value = values[index];
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value,
                color: color,
                width: 24,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVerticalBarChart(
    List<dynamic> data,
    String labelKey,
    String valueKey,
    Color baseColor,
  ) {
    if (data.isEmpty) return _emptyState();
    final counts =
        data.map((e) => (e[valueKey] as num).toDouble()).toList();
    final maxValue = counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b);
    final safeMax = (maxValue > 0 ? maxValue * 1.15 : 10.0).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: safeMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.grey.shade300),
            bottom: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: const EdgeInsets.all(10),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final idx = group.x.toInt();
              if (idx < 0 || idx >= data.length) return null;
              final item = data[idx];
              return BarTooltipItem(
                '${item[labelKey]}\n${item[valueKey]} jobs',
                const TextStyle(color: Colors.white, fontSize: 13),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox();
                final item = data[index];
                final label = item[labelKey]?.toString() ?? '';
                final parts = label.split(RegExp(r'[-\s]'));
                final displayLabel = parts.length > 2
                    ? '${parts[0]}\n${parts.skip(1).join(' ')}'
                    : label;
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 6,
                  child: Text(
                    displayLabel,
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: data.asMap().entries.map((entry) {
          final index = entry.key;
          final count = counts[index];
          final colorOpacity = 0.6 + (count / safeMax) * 0.4;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: count,
                color: baseColor.withOpacity(colorOpacity.clamp(0.0, 1.0)),
                width: 22,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: safeMax,
                  color: Colors.grey.shade100,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDonutChartWithLegend(
    List<dynamic> data,
    String labelKey,
    List<Color> colors,
  ) {
    if (data.isEmpty) return _emptyState();
    final total = data
        .map((e) => (e['count'] as num?)?.toDouble() ?? 0.0)
        .reduce((a, b) => a + b);
    if (total == 0) return _emptyState();

    final sections = data.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final value = (item['count'] as num?)?.toDouble() ?? 0.0;
      final percentage = total > 0 ? ((value / total) * 100).toInt() : 0;
      return PieChartSectionData(
        value: value,
        title: '$percentage%',
        color: colors[index % colors.length],
        radius: 55,
        titleStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    // Build legend items
    final legendItems = data.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final label = item[labelKey]?.toString() ?? 'Unknown';
      final value = (item['count'] as num?)?.toDouble() ?? 0.0;
      final percentage = total > 0 ? ((value / total) * 100).toInt() : 0;
      
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: colors[index % colors.length],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ($percentage%)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      );
    }).toList();

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 45,
              sectionsSpace: 3,
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: legendItems.toList(),
        ),
      ],
    );
  }

  Widget _buildLineChart() {
    if (_jobsOverTime.isEmpty) return _emptyState('No trend data');
    final spots = _jobsOverTime.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        (entry.value['count'] as num).toDouble(),
      );
    }).toList();

    if (spots.isEmpty) return _emptyState();

    final maxYValue = spots.isEmpty
        ? 10.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final safeMax = (maxYValue > 0 ? maxYValue * 1.2 : 10.0).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _jobsOverTime.length) {
                  return const SizedBox();
                }
                final dateStr = _jobsOverTime[index]['date']?.toString() ?? '';
                final parts = dateStr.split('-');
                if (parts.length >= 3) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      '${parts[1]}/${parts[2]}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipPadding: const EdgeInsets.all(10),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= _jobsOverTime.length) return null;
                final item = _jobsOverTime[index];
                return LineTooltipItem(
                  '${item['date']}\n${item['count']} jobs',
                  const TextStyle(color: Colors.white, fontSize: 13),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.15),
            ),
          ),
        ],
        minY: 0,
        maxY: safeMax,
        minX: 0,
        maxX: (spots.length - 1).toDouble().clamp(0, double.infinity),
      ),
    );
  }

  Widget _buildSalaryRangeList(
    List<dynamic> data,
    String labelKey,
    String minKey,
    String maxKey,
  ) {
    if (data.isEmpty) return _emptyState();
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: data.take(7).length,
      itemBuilder: (context, index) {
        final item = data[index];
        final label = item[labelKey]?.toString() ?? 'Unknown';
        final avgMin = (item[minKey] as num?)?.toDouble() ?? 0.0;
        final avgMax = (item[maxKey] as num?)?.toDouble() ?? 0.0;
        final progress = avgMax > 0 ? (avgMin / avgMax).clamp(0.0, 1.0) : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '€${avgMin.toInt()} - €${avgMax.toInt()}',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState([String? message]) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, color: Colors.grey.shade400, size: 36),
          const SizedBox(height: 10),
          Text(
            message ?? 'No data available',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}