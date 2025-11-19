import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CountPieChart extends StatefulWidget {
  final int pending;
  final int pendingApproval;
  final int partial;
  final int complete;
  final void Function(int index) onTapIndex;

  const CountPieChart({
    required this.pending,
    required this.pendingApproval,
    required this.partial,
    required this.complete,
    required this.onTapIndex,
  });

  @override
  State<CountPieChart> createState() => _CountPieChartState();
}

class _CountPieChartState extends State<CountPieChart> {
  int? touchedIndex;

  @override
  Widget build(BuildContext context) {
    final total =
        widget.pending +
            widget.pendingApproval +
            widget.partial +
            widget.complete;

    return SizedBox(
      height: 140,
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 20,
                sections: _buildSections(total),
                pieTouchData: PieTouchData(
                  enabled: true,
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    if (pieTouchResponse != null &&
                        pieTouchResponse.touchedSection != null) {
                      final idx =
                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                      setState(() => touchedIndex = idx);
                      // Call tab change immediately without deferring
                      widget.onTapIndex(idx);
                    } else {
                      setState(() => touchedIndex = null);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _LegendItem('Pending', widget.pending, Colors.orange.shade400),
              _LegendItem(
                'Approval',
                widget.pendingApproval,
                Colors.purple.shade400,
              ),
              _LegendItem('Partial', widget.partial, Colors.blue.shade400),
              _LegendItem('Complete', widget.complete, Colors.green.shade400),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(int total) {
    if (total == 0) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 1,
          title: 'No data',
          radius: 40,
          titleStyle: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ];
    }

    return [
      PieChartSectionData(
        color: Colors.orange.shade400,
        value: widget.pending.toDouble(),
        title: widget.pending == 0
            ? ''
            : '${((widget.pending / total) * 100).round()}%',
        radius: touchedIndex == 0 ? 50 : 40,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: Colors.purple.shade400,
        value: widget.pendingApproval.toDouble(),
        title: widget.pendingApproval == 0
            ? ''
            : '${((widget.pendingApproval / total) * 100).round()}%',
        radius: touchedIndex == 1 ? 50 : 40,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: Colors.blue.shade400,
        value: widget.partial.toDouble(),
        title: widget.partial == 0
            ? ''
            : '${((widget.partial / total) * 100).round()}%',
        radius: touchedIndex == 2 ? 50 : 40,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: Colors.green.shade400,
        value: widget.complete.toDouble(),
        title: widget.complete == 0
            ? ''
            : '${((widget.complete / total) * 100).round()}%',
        radius: touchedIndex == 3 ? 50 : 40,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _LegendItem(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}
