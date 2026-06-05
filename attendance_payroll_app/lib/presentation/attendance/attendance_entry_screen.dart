import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

enum AttendanceStatus { present, absent, halfDay, leave }

class AttendanceEntryScreen extends ConsumerStatefulWidget {
  const AttendanceEntryScreen({super.key});

  @override
  ConsumerState<AttendanceEntryScreen> createState() => _AttendanceEntryScreenState();
}

class _AttendanceEntryScreenState extends ConsumerState<AttendanceEntryScreen> {
  final _locationNameController = TextEditingController();
  final _workSiteController = TextEditingController();
  final _workDescController = TextEditingController();
  final _remarksController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  List<EmployeeModel> _allEmployees = [];
  List<EmployeeModel> _filteredEmployees = [];
  Map<String, AttendanceStatus> _attendance = {};
  Map<String, double> _overtime = {};
  Map<String, String> _employeeRemarks = {};
  bool _isLoading = false;
  bool _isLoadingEmployees = true;
  Position? _currentPosition;
  String? _currentAddress;
  bool _isCapturingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _captureLocation();
  }

  @override
  void dispose() {
    _locationNameController.dispose();
    _workSiteController.dispose();
    _workDescController.dispose();
    _remarksController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final client = ref.read(supabaseProvider);
      final profile = ref.read(currentProfileProvider).valueOrNull;
      if (profile == null) return;

      final sup = await client.from('supervisors').select('id').eq('profile_id', profile.id).maybeSingle();
      if (sup == null) {
        setState(() => _isLoadingEmployees = false);
        return;
      }

      final employees = await ref.read(supervisorRepositoryProvider).getAssignedEmployees(sup['id'] as String);
      setState(() {
        _allEmployees = employees.where((e) => e.isActive).toList();
        _filteredEmployees = List.from(_allEmployees);
        for (final e in _allEmployees) {
          _attendance[e.id] = AttendanceStatus.present;
          _overtime[e.id] = 0;
        }
        _isLoadingEmployees = false;
      });
    } catch (e) {
      setState(() => _isLoadingEmployees = false);
    }
  }

  Future<void> _captureLocation() async {
    setState(() => _isCapturingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      final placemark = placemarks.isNotEmpty ? placemarks.first : null;
      final address = placemark != null
          ? '${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}'
          : '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

      setState(() {
        _currentPosition = position;
        _currentAddress = address;
      });
    } catch (_) {} finally {
      setState(() => _isCapturingLocation = false);
    }
  }

  void _filterEmployees(String query) {
    setState(() {
      _filteredEmployees = query.isEmpty
          ? List.from(_allEmployees)
          : _allEmployees.where((e) =>
              e.name.toLowerCase().contains(query.toLowerCase()) ||
              e.employeeCode.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  void _bulkMarkAll(AttendanceStatus status) {
    setState(() {
      for (final e in _allEmployees) {
        _attendance[e.id] = status;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_allEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No employees assigned'), backgroundColor: AppColors.error500),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final client = ref.read(supabaseProvider);
      final profile = ref.read(currentProfileProvider).valueOrNull;

      final sup = await client.from('supervisors').select('id').eq('profile_id', profile!.id).maybeSingle();
      final supervisorId = sup?['id'] as String?;
      if (supervisorId == null) throw Exception('Supervisor not found');

      final attendanceData = {
        'supervisor_id': supervisorId,
        'attendance_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'location_name': _locationNameController.text.trim(),
        'work_site_name': _workSiteController.text.trim(),
        'work_description': _workDescController.text.trim(),
        'remarks': _remarksController.text.trim(),
        'submitted_latitude': _currentPosition?.latitude,
        'submitted_longitude': _currentPosition?.longitude,
        'submitted_address': _currentAddress,
      };

      final detailsData = _allEmployees.map((e) => {
        'employee_id': e.id,
        'status': _statusToString(_attendance[e.id] ?? AttendanceStatus.absent),
        'overtime_hours': _overtime[e.id] ?? 0,
        'remarks': _employeeRemarks[e.id],
      }).toList();

      await ref.read(attendanceRepositoryProvider).createWithDetails(attendanceData, detailsData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance submitted successfully'), backgroundColor: AppColors.success500),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error500),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _statusToString(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present: return 'present';
      case AttendanceStatus.absent: return 'absent';
      case AttendanceStatus.halfDay: return 'half_day';
      case AttendanceStatus.leave: return 'leave';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presentCount = _attendance.values.where((s) => s == AttendanceStatus.present).length;
    final absentCount = _attendance.values.where((s) => s == AttendanceStatus.absent).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        actions: [
          TextButton(onPressed: _isLoading ? null : _submit, child: const Text('Submit')),
        ],
      ),
      body: w.LoadingOverlay(
        isLoading: _isLoading,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Location header
              if (_currentAddress != null || _isCapturingLocation)
                Container(
                  color: AppColors.primary50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      _isCapturingLocation
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.location_on_rounded, color: AppColors.primary600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isCapturingLocation ? 'Capturing location...' : _currentAddress ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              // Form fields
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Date picker
                      InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date *', prefixIcon: Icon(Icons.calendar_today_outlined)),
                          child: Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _locationNameController,
                        decoration: const InputDecoration(labelText: 'Location Name *', prefixIcon: Icon(Icons.location_city_outlined)),
                        validator: (v) => ValidationUtils.validateRequired(v, 'Location'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _workSiteController,
                        decoration: const InputDecoration(labelText: 'Work Site', prefixIcon: Icon(Icons.construction_outlined)),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _workDescController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Work Description', prefixIcon: Icon(Icons.description_outlined)),
                      ),
                    ],
                  ),
                ),
              ),
              // Summary bar
              Container(
                color: theme.colorScheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _SummaryChip(label: 'P', count: presentCount, color: AppColors.success500),
                    const SizedBox(width: 8),
                    _SummaryChip(label: 'A', count: absentCount, color: AppColors.error500),
                    const SizedBox(width: 8),
                    _SummaryChip(
                      label: 'H',
                      count: _attendance.values.where((s) => s == AttendanceStatus.halfDay).length,
                      color: AppColors.accent500,
                    ),
                    const Spacer(),
                    PopupMenuButton<AttendanceStatus>(
                      child: Row(children: [const Icon(Icons.select_all_rounded, size: 18), const SizedBox(width: 4), const Text('Bulk', style: TextStyle(fontSize: 13, fontFamily: 'Inter'))]),
                      onSelected: _bulkMarkAll,
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: AttendanceStatus.present, child: Text('Mark All Present')),
                        const PopupMenuItem(value: AttendanceStatus.absent, child: Text('Mark All Absent')),
                        const PopupMenuItem(value: AttendanceStatus.halfDay, child: Text('Mark All Half Day')),
                        const PopupMenuItem(value: AttendanceStatus.leave, child: Text('Mark All Leave')),
                      ],
                    ),
                  ],
                ),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterEmployees,
                  decoration: const InputDecoration(
                    hintText: 'Search employee...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Employee list
              Expanded(
                child: _isLoadingEmployees
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredEmployees.isEmpty
                        ? const Center(child: Text('No employees found'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _filteredEmployees.length,
                            itemBuilder: (_, i) {
                              final emp = _filteredEmployees[i];
                              return _EmployeeAttendanceRow(
                                employee: emp,
                                status: _attendance[emp.id] ?? AttendanceStatus.present,
                                overtime: _overtime[emp.id] ?? 0,
                                onStatusChanged: (s) => setState(() => _attendance[emp.id] = s),
                                onOvertimeChanged: (v) => setState(() => _overtime[emp.id] = v),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _selectedDate = date);
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text('$label: $count', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
    );
  }
}

class _EmployeeAttendanceRow extends StatelessWidget {
  final EmployeeModel employee;
  final AttendanceStatus status;
  final double overtime;
  final ValueChanged<AttendanceStatus> onStatusChanged;
  final ValueChanged<double> onOvertimeChanged;

  const _EmployeeAttendanceRow({
    required this.employee,
    required this.status,
    required this.overtime,
    required this.onStatusChanged,
    required this.onOvertimeChanged,
  });

  Color get _statusColor {
    switch (status) {
      case AttendanceStatus.present: return AppColors.success500;
      case AttendanceStatus.absent: return AppColors.error500;
      case AttendanceStatus.halfDay: return AppColors.accent500;
      case AttendanceStatus.leave: return AppColors.primary500;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _statusColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary100,
                  child: Text(employee.name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary600, fontWeight: FontWeight.w700, fontFamily: 'Inter', fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employee.name, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                      Text(employee.employeeCode, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary500)),
                    ],
                  ),
                ),
                _buildStatusSelector(context),
              ],
            ),
            if (status == AttendanceStatus.present) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: AppColors.secondary400),
                  const SizedBox(width: 6),
                  Text('Overtime hrs:', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: TextFormField(
                      initialValue: overtime.toString(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 13, fontFamily: 'Inter'),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        isDense: true,
                      ),
                      onChanged: (v) => onOvertimeChanged(double.tryParse(v) ?? 0),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSelector(BuildContext context) {
    return SegmentedButton<AttendanceStatus>(
      segments: const [
        ButtonSegment(value: AttendanceStatus.present, label: Text('P', style: TextStyle(fontSize: 11, fontFamily: 'Inter'))),
        ButtonSegment(value: AttendanceStatus.absent, label: Text('A', style: TextStyle(fontSize: 11, fontFamily: 'Inter'))),
        ButtonSegment(value: AttendanceStatus.halfDay, label: Text('H', style: TextStyle(fontSize: 11, fontFamily: 'Inter'))),
        ButtonSegment(value: AttendanceStatus.leave, label: Text('L', style: TextStyle(fontSize: 11, fontFamily: 'Inter'))),
      ],
      selected: {status},
      onSelectionChanged: (s) => onStatusChanged(s.first),
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: MaterialStateProperty.all(EdgeInsets.zero),
      ),
    );
  }
}

class AttendanceMapScreen extends ConsumerWidget {
  final String attendanceId;
  const AttendanceMapScreen({super.key, required this.attendanceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<AttendanceModel?>(
      future: ref.read(attendanceRepositoryProvider).getById(attendanceId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final att = snapshot.data;
        if (att == null) return const Scaffold(body: Center(child: Text('Not found')));

        return Scaffold(
          appBar: AppBar(title: const Text('Attendance Location')),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.primary50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GPS Location', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    if (att.latitude != null)
                      Text('Lat: ${att.latitude?.toStringAsFixed(6)}, Lng: ${att.longitude?.toStringAsFixed(6)}', style: Theme.of(context).textTheme.bodySmall),
                    if (att.submittedAddress != null)
                      Text(att.submittedAddress!, style: Theme.of(context).textTheme.bodyMedium),
                    if (att.latitude == null)
                      const Text('Location not captured', style: TextStyle(color: AppColors.error500)),
                  ],
                ),
              ),
              Expanded(
                child: att.latitude != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppColors.error500, size: 64),
                            const SizedBox(height: 16),
                            Text('${att.latitude?.toStringAsFixed(6)}, ${att.longitude?.toStringAsFixed(6)}', style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 8),
                            Text(att.submittedAddress ?? '', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            const Text('Integrate Google Maps Flutter plugin\nfor full map view', style: TextStyle(color: AppColors.secondary400, fontSize: 12), textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    : const Center(child: Text('No location data available')),
              ),
            ],
          ),
        );
      },
    );
  }
}
