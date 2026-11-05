import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/vi_labels.dart';
import '../../models/checkout_schedule_window.dart';
import '../../models/facility_management_models.dart';
import '../../models/facility_operations_models.dart';
import '../../services/facility_ops_api_service.dart';

class AppointmentAssignmentScreen extends StatefulWidget {
  final String facilityId;
  final FacilityOpsApiService? service;
  const AppointmentAssignmentScreen(
      {super.key, required this.facilityId, this.service});

  @override
  State<AppointmentAssignmentScreen> createState() =>
      _AppointmentAssignmentScreenState();
}

class _AppointmentAssignmentScreenState
    extends State<AppointmentAssignmentScreen> {
  late final _api = widget.service ?? FacilityOpsApiService();
  DateTime _date = CheckoutScheduleWindow.vietnamNow();
  bool _week = false;
  late Future<List<DailyScheduleModel>> _schedule;
  late Future<List<FacilityStaffModel>> _staff;
  String? _updating;
  static const _ink = AppColors.onSurface;
  static const _muted = AppColors.onSurfaceVariant;
  final _dayFormat = DateFormat('dd/MM/yyyy');

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
  DateTime get _monday =>
      _day(_date).subtract(Duration(days: _date.weekday - 1));

  @override
  void initState() {
    super.initState();
    _staff = _api.getFacilityStaff(widget.facilityId);
    _schedule = _loadSchedule();
  }

  Future<List<DailyScheduleModel>> _loadSchedule() async {
    final week = _week;
    final selected = _day(_date);
    final first = selected.subtract(Duration(days: selected.weekday - 1));
    final dates = week
        ? List.generate(7, (i) => first.add(Duration(days: i)))
        : [selected];
    final batches = await Future.wait(dates.map((date) =>
        _api.getDailySchedule(facilityId: widget.facilityId, date: date)));
    final unique = <String, DailyScheduleModel>{};
    for (final item in batches.expand((items) => items)) {
      final time = item.scheduledTime;
      // Daily responses may repeat the same unresolved appointment on several dates.
      if (week &&
          time != null &&
          (time.isBefore(first) ||
              !time.isBefore(first.add(const Duration(days: 7))))) {
        continue;
      }
      unique['${item.bookingId}-${item.scheduleType}'] = item;
    }
    final items = unique.values.toList();
    items.sort((a, b) {
      final result = (a.scheduledTime ?? DateTime(9999))
          .compareTo(b.scheduledTime ?? DateTime(9999));
      return result == 0 ? a.bookingCode.compareTo(b.bookingCode) : result;
    });
    return items;
  }

  void _reload() {
    setState(() {
      _schedule = _loadSchedule();
    });
  }

  void _setDate(DateTime date, {bool week = false}) {
    setState(() {
      _date = date;
      _week = week;
      _schedule = _loadSchedule();
    });
  }

  Future<void> _chooseDate() async {
    final now = CheckoutScheduleWindow.vietnamNow();
    final selected = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: now.subtract(const Duration(days: 90)),
        lastDate: now.add(const Duration(days: 365)));
    if (selected != null && mounted) _setDate(selected);
  }

  Future<void> _assign(DailyScheduleModel item, String? staffId) async {
    setState(() => _updating = '${item.bookingId}-${item.scheduleType}');
    try {
      await _api.assignAppointment(
          facilityId: widget.facilityId, appointment: item, staffId: staffId);
      if (!mounted) return;
      _reload();
      await _schedule;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(staffId == null
              ? 'Đã bỏ phân công nhân viên.'
              : 'Đã cập nhật nhân viên phụ trách.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _updating = null);
    }
  }

  Widget _filter(String label, bool selected, VoidCallback choose) =>
      FilterChip(
        label: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : _ink,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        selected: selected,
        onSelected: (_) => choose(),
        selectedColor: AppColors.primary,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        labelPadding: EdgeInsets.zero,
        checkmarkColor: Colors.white,
        backgroundColor: Colors.white,
        side: BorderSide(
            color: selected ? AppColors.primary : AppColors.outlineVariant),
      );

  @override
  Widget build(BuildContext context) {
    final today = _day(CheckoutScheduleWindow.vietnamNow());
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch hẹn nhận/trả kho')),
      body: Column(children: [
        ListTile(
          title: Text(
              _week
                  ? '${_dayFormat.format(_monday)} – ${_dayFormat.format(_monday.add(const Duration(days: 6)))}'
                  : _dayFormat.format(_date),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(_week ? 'Lịch hẹn trong tuần' : 'Lịch hẹn trong ngày'),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: _chooseDate,
        ),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              _filter('Hôm nay', !_week && _day(_date) == today,
                  () => _setDate(today)),
              const SizedBox(width: 8),
              _filter(
                  'Ngày mai',
                  !_week && _day(_date) == today.add(const Duration(days: 1)),
                  () => _setDate(today.add(const Duration(days: 1)))),
              const SizedBox(width: 8),
              _filter('Tuần này', _week, () => _setDate(today, week: true)),
            ])),
        const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
                'Chọn nhân viên để lưu phân công. Lịch chưa phân công được hiển thị cho các nhân viên của cơ sở.',
                style: TextStyle(fontSize: 12, color: _muted, height: 1.5))),
        Expanded(
            child: FutureBuilder<List<FacilityStaffModel>>(
                future: _staff,
                builder: (context, staffSnapshot) {
                  if (staffSnapshot.hasError) {
                    return _error(
                        staffSnapshot.error,
                        () => setState(() {
                              _staff = _api.getFacilityStaff(widget.facilityId);
                              _schedule = _loadSchedule();
                            }));
                  }
                  if (!staffSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final staff = staffSnapshot.data!;
                  return FutureBuilder<List<DailyScheduleModel>>(
                      future: _schedule,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _error(snapshot.error, _reload);
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final items = snapshot.data!;
                        final checkIns = items.where((i) => i.isCheckIn).length;
                        final unassigned = items
                            .where((i) =>
                                i.assignedStaffId == null ||
                                i.assignedStaffId!.isEmpty)
                            .length;
                        return RefreshIndicator(
                            onRefresh: () async {
                              _reload();
                              await _schedule;
                            },
                            child: ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  if (staff.isEmpty)
                                    const Padding(
                                        padding: EdgeInsets.only(bottom: 12),
                                        child: Text(
                                            'Cơ sở chưa có nhân viên để phân công. Vào tab Nhân viên và thêm nhân viên trước.',
                                            style: TextStyle(color: _muted))),
                                  Wrap(spacing: 16, runSpacing: 4, children: [
                                    Text('${items.length} lịch hẹn',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                        '$checkIns nhận • ${items.length - checkIns} trả',
                                        style: const TextStyle(color: _muted)),
                                    Text('$unassigned chưa phân công',
                                        style: const TextStyle(color: _muted)),
                                  ]),
                                  const SizedBox(height: 12),
                                  if (items.isEmpty)
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 48),
                                        child: Column(children: [
                                          const Icon(
                                              Icons.event_available_outlined,
                                              size: 40,
                                              color: _muted),
                                          const SizedBox(height: 12),
                                          Text(
                                              _week
                                                  ? 'Chưa có lịch hẹn trong tuần này.'
                                                  : 'Chưa có lịch hẹn cần xử lý trong ngày này.',
                                              textAlign: TextAlign.center),
                                          const SizedBox(height: 6),
                                          const Text(
                                              'Bạn có thể chọn ngày khác hoặc kéo xuống để tải lại.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontSize: 12, color: _muted)),
                                        ])),
                                  for (final item in items)
                                    _appointment(item, staff),
                                ]));
                      });
                })),
      ]),
    );
  }

  Widget _error(Object? error, VoidCallback retry) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(error.toString().replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: retry, child: const Text('Thử lại'))
          ])));

  Widget _info(IconData icon, String value) => Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: _muted),
        const SizedBox(width: 8),
        Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 12, color: _muted, height: 1.5)))
      ]));

  Widget _appointment(DailyScheduleModel item, List<FacilityStaffModel> staff) {
    final chosen = staff.any((s) => s.id == item.assignedStaffId)
        ? item.assignedStaffId
        : null;
    final assigned = item.assignedStaffId?.isNotEmpty ?? false;
    final changing = _updating == '${item.bookingId}-${item.scheduleType}';
    final time = item.scheduledTime;
    String date(DateTime? value) =>
        value == null ? 'Chưa có' : _dayFormat.format(value);
    return Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(item.isCheckIn ? Icons.login : Icons.logout,
                          size: 18, color: _ink),
                      const SizedBox(width: 6),
                      Text(item.isCheckIn ? 'Nhận kho' : 'Trả kho',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                    Text(
                        time == null
                            ? 'Chưa có giờ hẹn'
                            : '${DateFormat('HH:mm').format(time)} • ${date(time)}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
              const SizedBox(height: 8),
              Text(assigned ? 'Đã phân công' : 'Chưa phân công',
                  style: const TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 12),
              Text(
                  item.customerName.isEmpty
                      ? 'Chưa có tên khách hàng'
                      : item.customerName,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              _info(
                  Icons.phone_outlined,
                  item.customerPhone.isEmpty
                      ? 'Chưa có số điện thoại'
                      : item.customerPhone),
              if (item.customerEmail.isNotEmpty)
                _info(Icons.mail_outline, item.customerEmail),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1)),
              Text('Ngăn ${item.unitCode}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              _info(
                  Icons.inventory_2_outlined,
                  [item.type, item.dimensions, item.floorLevel]
                      .where((s) => s.trim().isNotEmpty)
                      .join(' • ')),
              _info(Icons.date_range_outlined,
                  'Thời hạn thuê: ${date(item.startDate)} – ${date(item.endDate)}'),
              _info(Icons.description_outlined,
                  'Đơn ${item.bookingCode}\n${ViLabels.booking(item.bookingStatus)}'),
              if (item.isCheckIn && !item.unitAssignmentConfirmed)
                _info(Icons.info_outline,
                    'Chờ quản lý xác nhận ngăn kho trước khi nhân viên bàn giao.'),
              if (item.notes.trim().isNotEmpty)
                _info(Icons.notes_outlined, 'Ghi chú: ${item.notes}'),
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(
                    child: Text('Nhân viên phụ trách',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600))),
                if (changing)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
              ]),
              const SizedBox(height: 8),
              if (assigned && chosen == null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                        '${item.assignedStaffName ?? 'Nhân viên đã được phân công'} không còn trong danh sách nhân viên hiện tại. Vui lòng chọn lại.',
                        style: const TextStyle(fontSize: 12, color: _muted))),
              DropdownButtonFormField<String>(
                key: ValueKey(
                    '${item.bookingId}-${item.scheduleType}-${chosen ?? ''}'),
                initialValue: chosen ?? '',
                isExpanded: true,
                itemHeight: 64,
                decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                selectedItemBuilder: (context) => [
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Chưa phân công')),
                  for (final member in staff)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            member.fullName.isEmpty
                                ? member.email
                                : member.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                ],
                items: [
                  const DropdownMenuItem(
                      value: '', child: Text('Chưa phân công')),
                  ...staff.map((member) => DropdownMenuItem(
                      value: member.id,
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                member.fullName.isEmpty
                                    ? member.email
                                    : member.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            if (member.email.isNotEmpty)
                              Text(member.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11, color: _muted)),
                          ]))),
                ],
                onChanged: _updating != null || staff.isEmpty
                    ? null
                    : (id) => _assign(item, id == '' ? null : id),
              ),
            ])));
  }
}
