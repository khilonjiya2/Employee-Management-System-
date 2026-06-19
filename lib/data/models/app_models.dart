import 'package:equatable/equatable.dart';

class ProfileModel extends Equatable {
  final String id;
  final String role;
  final String? companyId;
  final String? employeeCode;
  final String fullName;
  final String? mobile;
  final String? profilePhotoUrl;
  final bool isActive;
  final bool mustChangePassword;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProfileModel({
    required this.id,
    required this.role,
    this.companyId,
    this.employeeCode,
    required this.fullName,
    this.mobile,
    this.profilePhotoUrl,
    required this.isActive,
    required this.mustChangePassword,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
        id: json['id'] as String,
        role: json['role'] as String,
        companyId: json['company_id'] as String?,
        employeeCode: json['employee_code'] as String?,
        fullName: json['full_name'] as String,
        mobile: json['mobile'] as String?,
        profilePhotoUrl: json['profile_photo_url'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        mustChangePassword:
            json['must_change_password'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'company_id': companyId,
        'employee_code': employeeCode,
        'full_name': fullName,
        'mobile': mobile,
        'profile_photo_url': profilePhotoUrl,
        'is_active': isActive,
        'must_change_password': mustChangePassword,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  bool get isAdmin => role == 'admin';
  bool get isSupervisor => role == 'supervisor';
  bool get isEmployee => role == 'employee';
  bool get isPlatformAdmin => role == 'platform_admin';

  @override
  List<Object?> get props => [
        id,
        role,
        companyId,
        fullName,
        isActive,
        mustChangePassword,
      ];
}

class CompanyModel extends Equatable {
  final String id;
  final String companyName;
  final String? ownerProfileId;
  final String subscriptionPlan;
  final String status;
  final String? logoUrl;
  final String? address;
  final String? phone;
  final String? email;
  final String? gstin;
  final String currencySymbol;
  final String timezone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CompanyModel({
    required this.id,
    required this.companyName,
    this.ownerProfileId,
    required this.subscriptionPlan,
    required this.status,
    this.logoUrl,
    this.address,
    this.phone,
    this.email,
    this.gstin,
    required this.currencySymbol,
    required this.timezone,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) => CompanyModel(
        id: json['id'] as String,
        companyName: json['company_name'] as String,
        ownerProfileId: json['owner_profile_id'] as String?,
        subscriptionPlan: json['subscription_plan'] as String? ?? 'free',
        status: json['status'] as String? ?? 'active',
        logoUrl: json['logo_url'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        gstin: json['gstin'] as String?,
        currencySymbol: json['currency_symbol'] as String? ?? '₹',
        timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  bool get isActive => status == 'active';

  @override
  List<Object?> get props => [id, companyName, status];
}

class EmployeeModel extends Equatable {
  final String id;
  final String? profileId;
  final String employeeCode;
  final String name;
  final String? mobile;
  final String? address;
  final String? aadhaarNumber;
  final DateTime joiningDate;
  final String? departmentId;
  final String? departmentName;
  final String? designation;
  final double dailyWageRate;
  final String? employeePhotoUrl;
  final String status;
  final String? upiId;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? bankName;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployeeModel({
    required this.id,
    this.profileId,
    required this.employeeCode,
    required this.name,
    this.mobile,
    this.address,
    this.aadhaarNumber,
    required this.joiningDate,
    this.departmentId,
    this.departmentName,
    this.designation,
    required this.dailyWageRate,
    this.employeePhotoUrl,
    required this.status,
    this.upiId,
    this.bankAccountNumber,
    this.bankIfsc,
    this.bankName,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) => EmployeeModel(
    id: json['id'] as String,
    profileId: json['profile_id'] as String?,
    employeeCode: json['employee_code'] as String,
    name: json['name'] as String,
    mobile: json['mobile'] as String?,
    address: json['address'] as String?,
    aadhaarNumber: json['aadhaar_number'] as String?,
    joiningDate: DateTime.parse(json['joining_date'] as String),
    departmentId: json['department_id'] as String?,
    departmentName: json['departments'] != null ? (json['departments'] as Map)['name'] as String? : null,
    designation: json['designation'] as String?,
    dailyWageRate: (json['daily_wage_rate'] as num).toDouble(),
    employeePhotoUrl: json['employee_photo_url'] as String?,
    status: json['status'] as String,
    upiId: json['upi_id'] as String?,
    bankAccountNumber: json['bank_account_number'] as String?,
    bankIfsc: json['bank_ifsc'] as String?,
    bankName: json['bank_name'] as String?,
    createdBy: json['created_by'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'employee_code': employeeCode,
    'name': name,
    'mobile': mobile,
    'address': address,
    'aadhaar_number': aadhaarNumber,
    'joining_date': joiningDate.toIso8601String().split('T').first,
    'department_id': departmentId,
    'designation': designation,
    'daily_wage_rate': dailyWageRate,
    'employee_photo_url': employeePhotoUrl,
    'status': status,
    'upi_id': upiId,
    'bank_account_number': bankAccountNumber,
    'bank_ifsc': bankIfsc,
    'bank_name': bankName,
  };

  bool get isActive => status == 'active';
  bool get hasUpi => upiId != null && upiId!.trim().isNotEmpty;

  EmployeeModel copyWith({
    String? name,
    String? mobile,
    String? address,
    String? aadhaarNumber,
    DateTime? joiningDate,
    String? departmentId,
    String? designation,
    double? dailyWageRate,
    String? employeePhotoUrl,
    String? status,
    String? upiId,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankName,
  }) => EmployeeModel(
    id: id,
    profileId: profileId,
    employeeCode: employeeCode,
    name: name ?? this.name,
    mobile: mobile ?? this.mobile,
    address: address ?? this.address,
    aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
    joiningDate: joiningDate ?? this.joiningDate,
    departmentId: departmentId ?? this.departmentId,
    designation: designation ?? this.designation,
    dailyWageRate: dailyWageRate ?? this.dailyWageRate,
    employeePhotoUrl: employeePhotoUrl ?? this.employeePhotoUrl,
    status: status ?? this.status,
    upiId: upiId ?? this.upiId,
    bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
    bankIfsc: bankIfsc ?? this.bankIfsc,
    bankName: bankName ?? this.bankName,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  List<Object?> get props => [id, employeeCode, name, status];
}

class SupervisorModel extends Equatable {
  final String id;
  final String? profileId;
  final String supervisorCode;
  final String name;
  final String email;
  final String? mobile;
  final String? assignedArea;
  final String? profilePhotoUrl;
  final bool isActive;
  final String? upiId;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? bankName;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupervisorModel({
    required this.id,
    this.profileId,
    required this.supervisorCode,
    required this.name,
    required this.email,
    this.mobile,
    this.assignedArea,
    this.profilePhotoUrl,
    required this.isActive,
    this.upiId,
    this.bankAccountNumber,
    this.bankIfsc,
    this.bankName,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupervisorModel.fromJson(Map<String, dynamic> json) => SupervisorModel(
    id: json['id'] as String,
    profileId: json['profile_id'] as String?,
    supervisorCode: json['supervisor_code'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    mobile: json['mobile'] as String?,
    assignedArea: json['assigned_area'] as String?,
    profilePhotoUrl: json['profile_photo_url'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    upiId: json['upi_id'] as String?,
    bankAccountNumber: json['bank_account_number'] as String?,
    bankIfsc: json['bank_ifsc'] as String?,
    bankName: json['bank_name'] as String?,
    createdBy: json['created_by'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'supervisor_code': supervisorCode,
    'name': name,
    'email': email,
    'mobile': mobile,
    'assigned_area': assignedArea,
    'profile_photo_url': profilePhotoUrl,
    'is_active': isActive,
    'upi_id': upiId,
    'bank_account_number': bankAccountNumber,
    'bank_ifsc': bankIfsc,
    'bank_name': bankName,
  };

  bool get hasUpi => upiId != null && upiId!.trim().isNotEmpty;

  @override
  List<Object?> get props => [id, supervisorCode, email, isActive];
}

class AttendanceModel extends Equatable {
  final String id;
  final String supervisorId;
  final String? supervisorName;
  final String? locationId;
  final String? workSiteId;
  final String? workCategoryId;
  final DateTime attendanceDate;
  final String? locationName;
  final String? workSiteName;
  final String? workDescription;
  final String? remarks;
  final bool isApproved;
  final String? approvedBy;
  final DateTime? approvedAt;
  final double? latitude;
  final double? longitude;
  final String? submittedAddress;
  final List<AttendanceDetailModel>? details;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AttendanceModel({
    required this.id,
    required this.supervisorId,
    this.supervisorName,
    this.locationId,
    this.workSiteId,
    this.workCategoryId,
    required this.attendanceDate,
    this.locationName,
    this.workSiteName,
    this.workDescription,
    this.remarks,
    required this.isApproved,
    this.approvedBy,
    this.approvedAt,
    this.latitude,
    this.longitude,
    this.submittedAddress,
    this.details,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) => AttendanceModel(
    id: json['id'] as String,
    supervisorId: json['supervisor_id'] as String,
    supervisorName: json['supervisors'] != null ? (json['supervisors'] as Map)['name'] as String? : null,
    locationId: json['location_id'] as String?,
    workSiteId: json['work_site_id'] as String?,
    workCategoryId: json['work_category_id'] as String?,
    attendanceDate: DateTime.parse(json['attendance_date'] as String),
    locationName: json['location_name'] as String?,
    workSiteName: json['work_site_name'] as String?,
    workDescription: json['work_description'] as String?,
    remarks: json['remarks'] as String?,
    isApproved: json['is_approved'] as bool? ?? false,
    approvedBy: json['approved_by'] as String?,
    approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at'] as String) : null,
    latitude: json['submitted_latitude'] != null ? (json['submitted_latitude'] as num).toDouble() : null,
    longitude: json['submitted_longitude'] != null ? (json['submitted_longitude'] as num).toDouble() : null,
    submittedAddress: json['submitted_address'] as String?,
    details: json['attendance_details'] != null
        ? (json['attendance_details'] as List).map((d) => AttendanceDetailModel.fromJson(d as Map<String, dynamic>)).toList()
        : null,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  @override
  List<Object?> get props => [id, supervisorId, attendanceDate, isApproved];
}

class AttendanceDetailModel extends Equatable {
  final String id;
  final String attendanceId;
  final String employeeId;
  final String? employeeName;
  final String? employeeCode;
  final String status;
  final double overtimeHours;
  final String? remarks;
  final DateTime createdAt;

  const AttendanceDetailModel({
    required this.id,
    required this.attendanceId,
    required this.employeeId,
    this.employeeName,
    this.employeeCode,
    required this.status,
    required this.overtimeHours,
    this.remarks,
    required this.createdAt,
  });

  factory AttendanceDetailModel.fromJson(Map<String, dynamic> json) => AttendanceDetailModel(
    id: json['id'] as String,
    attendanceId: json['attendance_id'] as String,
    employeeId: json['employee_id'] as String,
    employeeName: json['employees'] != null ? (json['employees'] as Map)['name'] as String? : null,
    employeeCode: json['employees'] != null ? (json['employees'] as Map)['employee_code'] as String? : null,
    status: json['status'] as String,
    overtimeHours: (json['overtime_hours'] as num?)?.toDouble() ?? 0,
    remarks: json['remarks'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'attendance_id': attendanceId,
    'employee_id': employeeId,
    'status': status,
    'overtime_hours': overtimeHours,
    'remarks': remarks,
  };

  @override
  List<Object?> get props => [id, employeeId, status];
}

class ExpenseModel extends Equatable {
  final String id;
  final String supervisorId;
  final String? supervisorName;
  final DateTime expenseDate;
  final String category;
  final String expenseName;
  final String? description;
  final double amount;
  final String status;
  final String? adminRemarks;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String paymentStatus;
  final String? paymentMethod;
  final String? utrReference;
  final DateTime? paymentInitiatedAt;
  final DateTime? paymentConfirmedAt;
  final List<ExpenseAttachmentModel>? attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpenseModel({
    required this.id,
    required this.supervisorId,
    this.supervisorName,
    required this.expenseDate,
    required this.category,
    required this.expenseName,
    this.description,
    required this.amount,
    required this.status,
    this.adminRemarks,
    this.reviewedBy,
    this.reviewedAt,
    this.paymentStatus = 'unpaid',
    this.paymentMethod,
    this.utrReference,
    this.paymentInitiatedAt,
    this.paymentConfirmedAt,
    this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
    id: json['id'] as String,
    supervisorId: json['supervisor_id'] as String,
    supervisorName: json['supervisors'] != null ? (json['supervisors'] as Map)['name'] as String? : null,
    expenseDate: DateTime.parse(json['expense_date'] as String),
    category: json['category'] as String,
    expenseName: json['expense_name'] as String,
    description: json['description'] as String?,
    amount: (json['amount'] as num).toDouble(),
    status: json['status'] as String,
    adminRemarks: json['admin_remarks'] as String?,
    reviewedBy: json['reviewed_by'] as String?,
    reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at'] as String) : null,
    paymentStatus: json['payment_status'] as String? ?? 'unpaid',
    paymentMethod: json['payment_method'] as String?,
    utrReference: json['utr_reference'] as String?,
    paymentInitiatedAt: json['payment_initiated_at'] != null ? DateTime.parse(json['payment_initiated_at'] as String) : null,
    paymentConfirmedAt: json['payment_confirmed_at'] != null ? DateTime.parse(json['payment_confirmed_at'] as String) : null,
    attachments: json['expense_attachments'] != null
        ? (json['expense_attachments'] as List).map((a) => ExpenseAttachmentModel.fromJson(a as Map<String, dynamic>)).toList()
        : null,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPaid => paymentStatus == 'paid';
  bool get canPay => isApproved && !isPaid;

  @override
  List<Object?> get props => [id, supervisorId, expenseName, status, amount, paymentStatus];
}

class ExpenseAttachmentModel extends Equatable {
  final String id;
  final String expenseId;
  final String fileUrl;
  final String? fileName;
  final String? fileType;
  final int? fileSize;
  final bool isReceipt;
  final DateTime uploadedAt;

  const ExpenseAttachmentModel({
    required this.id,
    required this.expenseId,
    required this.fileUrl,
    this.fileName,
    this.fileType,
    this.fileSize,
    required this.isReceipt,
    required this.uploadedAt,
  });

  factory ExpenseAttachmentModel.fromJson(Map<String, dynamic> json) => ExpenseAttachmentModel(
    id: json['id'] as String,
    expenseId: json['expense_id'] as String,
    fileUrl: json['file_url'] as String,
    fileName: json['file_name'] as String?,
    fileType: json['file_type'] as String?,
    fileSize: json['file_size'] as int?,
    isReceipt: json['is_receipt'] as bool? ?? false,
    uploadedAt: DateTime.parse(json['uploaded_at'] as String),
  );

  bool get isPdf => fileType == 'application/pdf';
  bool get isImage => fileType?.startsWith('image/') ?? false;

  @override
  List<Object?> get props => [id, fileUrl];
}

class PayrollModel extends Equatable {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String? employeeCode;
  final int payrollMonth;
  final int payrollYear;
  final double dailyWageRate;
  final double presentDays;
  final double halfDays;
  final double absentDays;
  final double leaveDays;
  final double overtimeHours;
  final double overtimeAmount;
  final double grossWage;
  final double advanceDeduction;
  final double penaltyDeduction;
  final double bonus;
  final double netWage;
  final String status;
  final String? processedBy;
  final DateTime? processedAt;
  final DateTime? paidAt;
  final String? remarks;
  final String paymentStatus;
  final String? paymentMethod;
  final String? utrReference;
  final DateTime? paymentInitiatedAt;
  final DateTime? paymentConfirmedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PayrollModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.employeeCode,
    required this.payrollMonth,
    required this.payrollYear,
    required this.dailyWageRate,
    required this.presentDays,
    required this.halfDays,
    required this.absentDays,
    required this.leaveDays,
    required this.overtimeHours,
    required this.overtimeAmount,
    required this.grossWage,
    required this.advanceDeduction,
    required this.penaltyDeduction,
    required this.bonus,
    required this.netWage,
    required this.status,
    this.processedBy,
    this.processedAt,
    this.paidAt,
    this.remarks,
    this.paymentStatus = 'unpaid',
    this.paymentMethod,
    this.utrReference,
    this.paymentInitiatedAt,
    this.paymentConfirmedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PayrollModel.fromJson(Map<String, dynamic> json) => PayrollModel(
    id: json['id'] as String,
    employeeId: json['employee_id'] as String,
    employeeName: json['employees'] != null ? (json['employees'] as Map)['name'] as String? : null,
    employeeCode: json['employees'] != null ? (json['employees'] as Map)['employee_code'] as String? : null,
    payrollMonth: json['payroll_month'] as int,
    payrollYear: json['payroll_year'] as int,
    dailyWageRate: (json['daily_wage_rate'] as num).toDouble(),
    presentDays: (json['present_days'] as num?)?.toDouble() ?? 0,
    halfDays: (json['half_days'] as num?)?.toDouble() ?? 0,
    absentDays: (json['absent_days'] as num?)?.toDouble() ?? 0,
    leaveDays: (json['leave_days'] as num?)?.toDouble() ?? 0,
    overtimeHours: (json['overtime_hours'] as num?)?.toDouble() ?? 0,
    overtimeAmount: (json['overtime_amount'] as num?)?.toDouble() ?? 0,
    grossWage: (json['gross_wage'] as num?)?.toDouble() ?? 0,
    advanceDeduction: (json['advance_deduction'] as num?)?.toDouble() ?? 0,
    penaltyDeduction: (json['penalty_deduction'] as num?)?.toDouble() ?? 0,
    bonus: (json['bonus'] as num?)?.toDouble() ?? 0,
    netWage: (json['net_wage'] as num?)?.toDouble() ?? 0,
    status: json['status'] as String,
    processedBy: json['processed_by'] as String?,
    processedAt: json['processed_at'] != null ? DateTime.parse(json['processed_at'] as String) : null,
    paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null,
    remarks: json['remarks'] as String?,
    paymentStatus: json['payment_status'] as String? ?? 'unpaid',
    paymentMethod: json['payment_method'] as String?,
    utrReference: json['utr_reference'] as String?,
    paymentInitiatedAt: json['payment_initiated_at'] != null ? DateTime.parse(json['payment_initiated_at'] as String) : null,
    paymentConfirmedAt: json['payment_confirmed_at'] != null ? DateTime.parse(json['payment_confirmed_at'] as String) : null,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  double get effectiveDays => presentDays + (halfDays * 0.5);
  bool get isPaid => paymentStatus == 'paid' || status == 'paid';
  bool get canPay => !isPaid;

  @override
  List<Object?> get props => [id, employeeId, payrollMonth, payrollYear, status, paymentStatus];
}

class PaymentLogModel extends Equatable {
  final String id;
  final String referenceType;
  final String referenceId;
  final String? employeeId;
  final String? supervisorId;
  final double amount;
  final String? upiId;
  final String paymentMethod;
  final String paymentStatus;
  final String? utrReference;
  final String? initiatedBy;
  final DateTime initiatedAt;
  final DateTime? confirmedAt;
  final String? remarks;

  const PaymentLogModel({
    required this.id,
    required this.referenceType,
    required this.referenceId,
    this.employeeId,
    this.supervisorId,
    required this.amount,
    this.upiId,
    required this.paymentMethod,
    required this.paymentStatus,
    this.utrReference,
    this.initiatedBy,
    required this.initiatedAt,
    this.confirmedAt,
    this.remarks,
  });

  factory PaymentLogModel.fromJson(Map<String, dynamic> json) => PaymentLogModel(
    id: json['id'] as String,
    referenceType: json['reference_type'] as String,
    referenceId: json['reference_id'] as String,
    employeeId: json['employee_id'] as String?,
    supervisorId: json['supervisor_id'] as String?,
    amount: (json['amount'] as num).toDouble(),
    upiId: json['upi_id'] as String?,
    paymentMethod: json['payment_method'] as String? ?? 'upi',
    paymentStatus: json['payment_status'] as String? ?? 'initiated',
    utrReference: json['utr_reference'] as String?,
    initiatedBy: json['initiated_by'] as String?,
    initiatedAt: DateTime.parse(json['initiated_at'] as String),
    confirmedAt: json['confirmed_at'] != null ? DateTime.parse(json['confirmed_at'] as String) : null,
    remarks: json['remarks'] as String?,
  );

  @override
  List<Object?> get props => [id, referenceType, referenceId, paymentStatus];
}

class DepartmentModel extends Equatable {
  final String id;
  final String name;
  final String? description;
  final bool isActive;

  const DepartmentModel({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) => DepartmentModel(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    isActive: json['is_active'] as bool? ?? true,
  );

  @override
  List<Object?> get props => [id, name];
}

class LocationModel extends Equatable {
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final bool isActive;

  const LocationModel({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    required this.isActive,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String?,
    latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
    longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
    isActive: json['is_active'] as bool? ?? true,
  );

  @override
  List<Object?> get props => [id, name];
}

class NotificationModel extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String? type;
  final String? referenceId;
  final String? referenceType;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type,
    this.referenceId,
    this.referenceType,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    type: json['type'] as String?,
    referenceId: json['reference_id'] as String?,
    referenceType: json['reference_type'] as String?,
    isRead: json['is_read'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  @override
  List<Object?> get props => [id, isRead];
}


// Add to app_models.dart — append at bottom

class CompanyModel extends Equatable {
  final String id;
  final String companyName;
  final String? ownerProfileId;
  final String subscriptionPlan;
  final String status;
  final String? logoUrl;
  final String? address;
  final String? phone;
  final String? email;
  final String? gstin;
  final String currencySymbol;
  final String timezone;
  final bool paymentModuleEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CompanyModel({
    required this.id,
    required this.companyName,
    this.ownerProfileId,
    required this.subscriptionPlan,
    required this.status,
    this.logoUrl,
    this.address,
    this.phone,
    this.email,
    this.gstin,
    required this.currencySymbol,
    required this.timezone,
    this.paymentModuleEnabled = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) => CompanyModel(
        id: json['id'] as String,
        companyName: json['company_name'] as String,
        ownerProfileId: json['owner_profile_id'] as String?,
        subscriptionPlan: json['subscription_plan'] as String? ?? 'free',
        status: json['status'] as String? ?? 'active',
        logoUrl: json['logo_url'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        gstin: json['gstin'] as String?,
        currencySymbol: json['currency_symbol'] as String? ?? '₹',
        timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
        paymentModuleEnabled: json['payment_module_enabled'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  bool get isActive => status == 'active';

  @override
  List<Object?> get props => [id, companyName, status, paymentModuleEnabled];
}

class SupervisorPayrollModel extends Equatable {
  final String id;
  final String supervisorId;
  final int payrollMonth;
  final int payrollYear;
  final double monthlySalary;
  final double bonus;
  final double deduction;
  final double netAmount;
  final String status;
  final String paymentStatus;
  final String? paymentMethod;
  final String? utrReference;
  final DateTime? paymentConfirmedAt;
  final DateTime? paidAt;
  final String? remarks;
  final DateTime createdAt;

  const SupervisorPayrollModel({
    required this.id,
    required this.supervisorId,
    required this.payrollMonth,
    required this.payrollYear,
    required this.monthlySalary,
    required this.bonus,
    required this.deduction,
    required this.netAmount,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod,
    this.utrReference,
    this.paymentConfirmedAt,
    this.paidAt,
    this.remarks,
    required this.createdAt,
  });

  factory SupervisorPayrollModel.fromJson(Map<String, dynamic> json) =>
      SupervisorPayrollModel(
        id: json['id'] as String,
        supervisorId: json['supervisor_id'] as String,
        payrollMonth: json['payroll_month'] as int,
        payrollYear: json['payroll_year'] as int,
        monthlySalary: (json['monthly_salary'] as num?)?.toDouble() ?? 0,
        bonus: (json['bonus'] as num?)?.toDouble() ?? 0,
        deduction: (json['deduction'] as num?)?.toDouble() ?? 0,
        netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'pending',
        paymentStatus: json['payment_status'] as String? ?? 'unpaid',
        paymentMethod: json['payment_method'] as String?,
        utrReference: json['utr_reference'] as String?,
        paymentConfirmedAt: json['payment_confirmed_at'] != null
            ? DateTime.parse(json['payment_confirmed_at'] as String)
            : null,
        paidAt: json['paid_at'] != null
            ? DateTime.parse(json['paid_at'] as String)
            : null,
        remarks: json['remarks'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  bool get isPaid => paymentStatus == 'paid' || status == 'paid';

  @override
  List<Object?> get props =>
      [id, supervisorId, payrollMonth, payrollYear, status, paymentStatus];
}