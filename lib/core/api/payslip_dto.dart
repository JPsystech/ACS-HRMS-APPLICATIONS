import 'package:intl/intl.dart';

class PayslipDto {
  PayslipDto({
    required this.id,
    required this.salaryMonth,
    required this.salaryYear,
    required this.payslipDate,
    required this.netSalary,
    required this.status,
    this.downloadEndpoint,
  });

  final String id;
  final int salaryMonth;
  final int salaryYear;
  final DateTime? payslipDate;
  final double netSalary;
  final String status;
  final String? downloadEndpoint;

  static PayslipDto fromJson(Map<String, dynamic> json) {
    final month = _asInt(json['salary_month'] ?? json['salaryMonth']) ?? 1;
    final year = _asInt(json['salary_year'] ?? json['salaryYear']) ?? 2000;
    final date = _asDate(json['payslip_date'] ?? json['payslipDate']);
    final net = _asDouble(json['net_salary'] ?? json['netSalary']) ?? 0.0;
    final rawStatus = (json['status'] ?? json['generation_status'] ?? json['generationStatus'])
        ?.toString()
        .trim();

    return PayslipDto(
      id: (json['id'] ?? '').toString(),
      salaryMonth: month,
      salaryYear: year,
      payslipDate: date,
      netSalary: net,
      status: (rawStatus == null || rawStatus.isEmpty) ? 'UNKNOWN' : rawStatus,
      downloadEndpoint: (json['download_endpoint'] ??
              json['downloadEndpoint'] ??
              json['file_url'] ??
              json['fileUrl'])
          ?.toString(),
    );
  }

  String get monthYearLabel {
    final dt = DateTime(salaryYear, salaryMonth, 1);
    return DateFormat('MMM yyyy').format(dt);
  }

  String get payslipDateLabel {
    final d = payslipDate;
    if (d == null) return '—';
    return DateFormat('dd MMM yyyy').format(d);
  }

  String get netSalaryLabel {
    return netSalary.toStringAsFixed(2);
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return DateTime.tryParse(v.toString());
  }
}
