import 'package:flutter/material.dart';
import '../../services/facility_ops_api_service.dart';
import '../../widgets/refund_review_widgets.dart';
import 'refund_detail_screen.dart';

class RefundReviewScreen extends StatefulWidget {
  final String facilityId;
  final FacilityOpsApiService? service;
  const RefundReviewScreen({super.key, required this.facilityId, this.service});
  @override
  State<RefundReviewScreen> createState() => _RefundReviewScreenState();
}

class _RefundReviewScreenState extends State<RefundReviewScreen> {
  late final _api = widget.service ?? FacilityOpsApiService();
  late Future<Map<String, dynamic>> _requests;
  int _page = 0;
  String _filter = 'ALL';
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload({bool resetPage = false}) => setState(() {
        if (resetPage) _page = 0;
        _requests = _api.getFacilityRefunds(widget.facilityId,
            page: _page, size: 10, filter: _filter);
      });
  Future<void> _refresh() async {
    _reload(resetPage: true);
    try {
      await _requests;
    } catch (_) {}
  }

  Future<void> _open(RefundViewData refund) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => RefundDetailScreen(
                facilityId: widget.facilityId,
                initial: refund.raw,
                service: _api)));
    if (mounted) _reload(resetPage: true);
  }

  Widget _tab(String label, String value, int count) {
    final selected = _filter == value;
    return Expanded(
        child: Padding(
            padding: const EdgeInsets.all(3),
            child: Material(
                color: selected ? const Color(0xFFE6EEFF) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      _filter = value;
                      _reload(resetPage: true);
                    },
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 12),
                        child: Text('$label $count',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                color: selected ? refundBlue : refundMuted,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500)))))));
  }

  Widget _card(RefundViewData refund) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE1E7EF)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x050F172A), blurRadius: 8, offset: Offset(0, 3))
          ]),
      child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: () => _open(refund),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Text(refund.text('bookingCode'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: refundInk))),
                              const SizedBox(width: 8),
                              Flexible(child: RefundStatusBadge(refund.status)),
                            ]),
                        const SizedBox(height: 10),
                        RefundInfoLine(
                            Icons.person_outline,
                            refund.info('customerName').isEmpty
                                ? 'Chưa có tên khách hàng'
                                : refund.info('customerName'),
                            strong: true),
                        if (refund.info('customerPhone').isNotEmpty)
                          Padding(
                              padding:
                                  const EdgeInsets.only(left: 25, bottom: 4),
                              child: Text(refund.info('customerPhone'),
                                  style: const TextStyle(
                                      fontSize: 12, color: refundMuted))),
                        RefundInfoLine(
                            Icons.location_on_outlined,
                            refund.facilityUnit.isEmpty
                                ? 'Chưa có thông tin cơ sở'
                                : refund.facilityUnit),
                        RefundInfoLine(Icons.sell_outlined, refund.kind),
                        const Divider(height: 22, color: Color(0xFFE8EDF4)),
                        RefundAmountRow(
                            refund.completed ? 'Tổng đã hoàn' : 'Tổng cần hoàn',
                            refund.raw['amount'],
                            strong: true),
                        const SizedBox(height: 5),
                        RefundInfoLine(
                            Icons.schedule_outlined,
                            refund.completed
                                ? 'Đã chuyển: ${refundTime(refund.details['completedAt'])}'
                                : 'Hạn hoàn: ${refundTime(refund.raw['dueAt'])}'),
                        if (refund.overdueText.isNotEmpty)
                          Text(refund.overdueText,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB45309))),
                        const Divider(height: 20, color: Color(0xFFE8EDF4)),
                        const Row(children: [
                          Expanded(
                              child: Text('Xem chi tiết đối soát',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: refundBlue,
                                      fontWeight: FontWeight.w600))),
                          Icon(Icons.chevron_right, size: 20, color: refundBlue)
                        ]),
                      ])))));
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: refundBackground,
      appBar: AppBar(
          title: const Text('Yêu cầu hoàn tiền',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          backgroundColor: Colors.white,
          foregroundColor: refundInk,
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(
                tooltip: 'Tải lại',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh))
          ]),
      body: FutureBuilder<Map<String, dynamic>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.cloud_off_outlined,
                            color: refundMuted, size: 36),
                        const SizedBox(height: 12),
                        Text('${snapshot.error}', textAlign: TextAlign.center),
                        TextButton(
                            onPressed: _refresh, child: const Text('Thử lại'))
                      ])));
            }
            final result = snapshot.data ?? {};
            final rows = (result['content'] as List? ?? [])
                .map((e) => RefundViewData(Map<String, dynamic>.from(e as Map)))
                .toList();
            final total =
                (result['totalElements'] as num?)?.toInt() ?? rows.length;
            final pages = (result['totalPages'] as num?)?.toInt() ?? 0;
            final all = (result['allCount'] as num?)?.toInt() ?? total;
            final completed = (result['completedCount'] as num?)?.toInt() ??
                rows.where((r) => r.completed).length;
            final pending =
                (result['pendingCount'] as num?)?.toInt() ?? all - completed;
            return Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE1E7EF))),
                      child: Row(children: [
                        _tab('Tất cả', 'ALL', all),
                        _tab('Chờ hoàn', 'PENDING', pending),
                        _tab('Đã hoàn', 'COMPLETED', completed)
                      ]))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('$pending yêu cầu đang chờ xử lý',
                          style: const TextStyle(
                              fontSize: 13, color: refundMuted)))),
              Expanded(
                  child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            if (rows.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 60),
                                  child: Center(
                                      child: Text('Không có yêu cầu phù hợp.',
                                          style:
                                              TextStyle(color: refundMuted)))),
                            ...rows.map(_card),
                          ]))),
              SafeArea(
                  top: false,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                      child: Row(children: [
                        IconButton(
                            tooltip: 'Trang trước',
                            onPressed: _page > 0
                                ? () {
                                    _page--;
                                    _reload();
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left)),
                        Expanded(
                            child: Text(
                                'Trang ${pages == 0 ? 0 : _page + 1} / $pages · $total yêu cầu',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12, color: refundMuted))),
                        IconButton(
                            tooltip: 'Trang sau',
                            onPressed: _page + 1 < pages
                                ? () {
                                    _page++;
                                    _reload();
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_right)),
                      ]))),
            ]);
          }));
}
