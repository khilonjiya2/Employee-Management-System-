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

enum AttendanceStatus {
  present,
  absent,
}

class AttendanceEntryScreen extends ConsumerStatefulWidget {
  final String? attendanceId;
  const AttendanceEntryScreen({super.key, this.attendanceId});

  @override
  ConsumerState<AttendanceEntryScreen> createState() => _AttendanceEntryScreenState();
}

class _AttendanceEntryScreenState extends ConsumerState<AttendanceEntryScreen> {
  final _workSiteController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
 List<LocationModel> _locations = [];
String? _selectedLocationId;
String? _selectedLocation;
  DateTime _selectedDate = DateTime.now();
  List<EmployeeModel> _allEmployees = [];
  List<EmployeeModel> _filteredEmployees = [];
  Map<String, AttendanceStatus> _attendance = {};
  bool _isLoading = false;
  bool _isLoadingEmployees = true;
  Position? _currentPosition;
  String? _currentAddress;
  bool _isCapturingLocation = false;

  bool get isEditing => widget.attendanceId != null;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _captureLocation();
    if (isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  Future<void> _loadExisting() async {
    final att = await ref
        .read(attendanceRepositoryProvider)
        .getById(widget.attendanceId!);
    if (att == null || !mounted) return;

    // Item 7: only the supervisor who originally submitted this
    // attendance (or an admin) may edit it. Other supervisors must not
    // be able to take over someone else's pending/approved record.
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile != null && profile.role != 'admin') {
      final client = ref.read(supabaseProvider);
      final sup = await client
          .from('supervisors')
          .select('id')
          .eq('profile_id', profile.id)
          .maybeSingle();
      final currentSupervisorId = sup?['id']?.toString();
      if (currentSupervisorId != null &&
          currentSupervisorId != att.supervisorId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'This attendance was submitted by another supervisor. You can only edit attendance you submitted yourself.'),
            backgroundColor: AppColors.error500,
          ));
          context.pop();
        }
        return;
      }
    }

    _selectedDate = att.attendanceDate;
    _selectedLocationId = att.locationId;
    _selectedLocation = att.locationName;
    _workSiteController.text = att.workSiteName ?? '';
    if (att.details != null) {
      for (final d in att.details!) {
        _attendance[d.employeeId] = d.status == 'present'
            ? AttendanceStatus.present
            : AttendanceStatus.absent;
      }
    }
    setState(() {});
    _applyFilters();
  }

  @override
void dispose() {
  _workSiteController.dispose();
  _searchController.dispose();
  super.dispose();
}

  Future<void> _loadEmployees() async {
  try {
    final client = ref.read(supabaseProvider);
    final profile = ref.read(currentProfileProvider).valueOrNull;

    if (profile == null) {
      setState(() => _isLoadingEmployees = false);
      return;
    }

    final sup = await client
        .from('supervisors')
        .select('id')
        .eq('profile_id', profile.id)
        .maybeSingle();

    if (sup == null) {
      setState(() => _isLoadingEmployees = false);
      return;
    }

    final supervisorId = sup['id'].toString();

    final links = await client
        .from('supervisor_employees')
        .select('employee_id')
        .eq('supervisor_id', supervisorId);

    final employeeIds = (links as List)
    .map<String>((e) => e['employee_id'].toString())
    .toList();
    List<EmployeeModel> employees = [];

    if (employeeIds.isNotEmpty) {
      final employeeData = await client
          .from('employees')
          .select('*, departments(name)')
          .inFilter('id', employeeIds);

      employees = (employeeData as List)
          .map((e) => EmployeeModel.fromJson(e))
          .toList();
    }

    final locationData = await client
        .from('locations')
        .select()
        .eq('is_active', true)
        .order('name');

    final locations = (locationData as List)
        .map((e) => LocationModel.fromJson(e))
        .toList();

    setState(() {
      _allEmployees = employees;
      _filteredEmployees = List.from(employees);

      _locations = locations;

      _attendance.clear();

      for (final employee in employees) {
        _attendance[employee.id] = AttendanceStatus.present;
      }

      _isLoadingEmployees = false;
    });
  } catch (e) {
    debugPrint('Load employees error: $e');

    setState(() {
      _isLoadingEmployees = false;
    });
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
    _applyFilters(searchQuery: query);
  }

  void _applyFilters({String? searchQuery}) {
    final query = searchQuery ?? _searchController.text;
    setState(() {
      _filteredEmployees = _allEmployees.where((e) {
        final matchesSearch = query.isEmpty ||
            e.name.toLowerCase().contains(query.toLowerCase());
        // Only show employees linked to the selected location. If an
        // employee has no location set, we still show them (treat as
        // unassigned/shared) rather than silently hiding them â€” admins
        // can set employees.location_id to tighten this further.
        final matchesLocation = _selectedLocationId == null ||
            e.locationId == null ||
            e.locationId == _selectedLocationId;
        return matchesSearch && matchesLocation;
      }).toList();
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
      final supervisorId = sup?['id']?.toString();
      if (supervisorId == null) throw Exception('Supervisor not found');

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Items 4 & 7: only ONE attendance record may exist per
      // (location, date), regardless of which supervisor submits it.
      // If one already exists, block creating a duplicate â€” the
      // supervisor who owns it must EDIT it instead (and any other
      // supervisor is blocked outright while it's pending/approved).
      if (!isEditing && _selectedLocationId != null) {
        final existing = await client
            .from('attendance')
            .select('id, supervisor_id')
            .eq('location_id', _selectedLocationId!)
            .eq('attendance_date', dateStr)
            .maybeSingle();

        if (existing != null) {
          final isOwnRecord = existing['supervisor_id'] == supervisorId;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isOwnRecord
                  ? 'You already submitted attendance for this location and date. Please edit that record instead.'
                  : 'Another supervisor has already submitted attendance for this location and date.'),
              backgroundColor: AppColors.error500,
            ));
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      final attendanceData = {
  'supervisor_id': supervisorId,
  'location_id': _selectedLocationId,
  'location_name': _selectedLocation,
  'attendance_date': dateStr,
  'work_site_name':
      _workSiteController.text.trim(),
  'work_description': null,
  'remarks': null,
  'submitted_latitude':
      _currentPosition?.latitude,
  'submitted_longitude':
      _currentPosition?.longitude,
  'submitted_address':
      _currentAddress,
};

      final detailsData = _allEmployees.map((e) => {
  'employee_id': e.id,
  'status': _statusToString(
    _attendance[e.id] ?? AttendanceStatus.present,
  ),
}).toList();

      if (isEditing) {
        await ref.read(attendanceRepositoryProvider).updateDetails(
            widget.attendanceId!, attendanceData, detailsData);
      } else {
        await ref.read(attendanceRepositoryProvider).createWithDetails(
            attendanceData, detailsData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
          content: Text(isEditing
              ? 'Attendance updated and sent for re-approval'
              : 'Attendance submitted successfully'),
          backgroundColor: AppColors.success500,
        ),
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
    case AttendanceStatus.present:
      return 'present';
    case AttendanceStatus.absent:
      return 'absent';
  }
}
  @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);

  final presentCount = _attendance.values
      .where((s) => s == AttendanceStatus.present)
      .length;

  final absentCount = _attendance.values
      .where((s) => s == AttendanceStatus.absent)
      .length;

  return Scaffold(
    appBar: AppBar(
        title: Text(isEditing ? 'Edit Attendance' : 'Mark Attendance'),
      ),

    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            child: const Text('Submit Attendance'),
          ),
        ),
      ),
    ),

    body: w.LoadingOverlay(
      isLoading: _isLoading,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_currentAddress != null ||
                _isCapturingLocation)
              Container(
                color: AppColors.primary50,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _isCapturingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.primary600,
                            size: 16,
                          ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isCapturingLocation
                            ? 'Capturing location...'
                            : (_currentAddress ?? ''),
                        overflow:
                            TextOverflow.ellipsis,
                        style: theme
                            .textTheme.bodySmall
                            ?.copyWith(
                          color:
                              AppColors.primary700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration:
                          const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(
                          Icons
                              .calendar_today_outlined,
                        ),
                      ),
                      child: Text(
                        DateFormat(
                          'dd MMMM yyyy',
                        ).format(_selectedDate),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
  value: _selectedLocationId,
  decoration: const InputDecoration(
    labelText: 'Location Name *',
    prefixIcon: Icon(Icons.location_city_outlined),
  ),
  items: _locations
      .map(
        (location) => DropdownMenuItem<String>(
          value: location.id,
          child: Text(location.name),
        ),
      )
      .toList(),
  onChanged: (value) {
    final selected = _locations.firstWhere(
      (e) => e.id == value,
    );

    setState(() {
      _selectedLocationId = selected.id;
      _selectedLocation = selected.name;
    });
    _applyFilters();
  },
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Please select a location';
    }
    return null;
  },
),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller:
                        _workSiteController,
                    decoration:
                        const InputDecoration(
                      labelText: 'Work Site',
                      prefixIcon: Icon(
                        Icons
                            .construction_outlined,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              color: theme.colorScheme.surface,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: Row(
                children: [
                  _SummaryChip(
                    label: 'Present',
                    count: presentCount,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _SummaryChip(
                    label: 'Absent',
                    count: absentCount,
                    color: Colors.red,
                  ),
                  const Spacer(),
                  PopupMenuButton<
                      AttendanceStatus>(
                    onSelected: _bulkMarkAll,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value:
                            AttendanceStatus
                                .present,
                        child: Text(
                          'Mark All Present',
                        ),
                      ),
                      PopupMenuItem(
                        value:
                            AttendanceStatus
                                .absent,
                        child: Text(
                          'Mark All Absent',
                        ),
                      ),
                    ],
                    child: const Row(
                      children: [
                        Icon(
                          Icons
                              .select_all_rounded,
                        ),
                        SizedBox(width: 4),
                        Text('Bulk'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                0,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterEmployees,
                decoration:
                    const InputDecoration(
                  hintText:
                      'Search employee...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: _isLoadingEmployees
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : _filteredEmployees
                          .isEmpty
                      ? const Center(
                          child: Text(
                            'No employees found',
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets
                                  .fromLTRB(
                            16,
                            0,
                            16,
                            100,
                          ),
                          itemCount:
                              _filteredEmployees
                                  .length,
                          itemBuilder:
                              (_, index) {
                            final emp =
                                _filteredEmployees[
                                    index];

                            return _EmployeeAttendanceRow(
                              employee: emp,
                              status: _attendance[
                                      emp.id] ??
                                  AttendanceStatus
                                      .present,
                              onStatusChanged:
                                  (status) {
                                setState(() {
                                  _attendance[
                                      emp.id] = status;
                                });
                              },
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
  final ValueChanged<AttendanceStatus> onStatusChanged;

  const _EmployeeAttendanceRow({
    super.key,
    required this.employee,
    required this.status,
    required this.onStatusChanged,
  });

  Color get _statusColor {
    switch (status) {
      case AttendanceStatus.present:
        return Colors.blue;
      case AttendanceStatus.absent:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _statusColor.withOpacity(0.30),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary100,
            child: Text(
              employee.name.isNotEmpty
                  ? employee.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.primary600,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              employee.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),

          const SizedBox(width: 8),

          SizedBox(
            width: 110,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => onStatusChanged(
                      AttendanceStatus.present,
                    ),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: status ==
                                AttendanceStatus.present
                            ? Colors.green
                            : Colors.green.withOpacity(0.10),
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: Text(
                        'P',
                        style: TextStyle(
                          color: status ==
                                  AttendanceStatus.present
                              ? Colors.white
                              : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: InkWell(
                    onTap: () => onStatusChanged(
                      AttendanceStatus.absent,
                    ),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: status ==
                                AttendanceStatus.absent
                            ? Colors.red
                            : Colors.red.withOpacity(0.10),
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: Text(
                        'A',
                        style: TextStyle(
                          color: status ==
                                  AttendanceStatus.absent
                              ? Colors.white
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                            const Text('Google Maps\n', style: TextStyle(color: AppColors.secondary400, fontSize: 12), textAlign: TextAlign.center),
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