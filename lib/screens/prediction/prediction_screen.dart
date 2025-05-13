import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../services/prediction_service.dart';

class PredictionScreen extends StatefulWidget {
  final String userGender;
  final String audioPath;

  const PredictionScreen({
    Key? key,
    required this.userGender,
    required this.audioPath,
  }) : super(key: key);

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  double? _score;

  @override
  void initState() {
    super.initState();
    _runPrediction();
  }

  Future<void> _runPrediction() async {
    final result = await PredictionService()
        .analyzeScoreOnly(widget.audioPath, widget.userGender);
    setState(() {
      _score = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_score ?? 0.0).clamp(0.0, 1.0);
    final percentageText = (percent * 100).round().toString();

    return Scaffold(
      appBar: AppBar(title: const Text('나는 솔로 기반 호감도 예측 결과')),
      body: Center(
        child: _score == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularPercentIndicator(
                    radius: 120.0,
                    lineWidth: 15.0,
                    percent: percent,
                    animation: true,
                    center: Text(
                      "$percentageText%",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    progressColor: Colors.pinkAccent,
                    backgroundColor: Colors.grey.shade300,
                    circularStrokeCap: CircularStrokeCap.round,
                  ),
                  const SizedBox(height: 30),
                  Text(
                    _getComment(percent),
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

  String _getComment(double percent) {
    if (percent > 0.8) {
      return "✨ 완벽한 케미! 좋은 인연이 될 수 있어요.";
    } else if (percent > 0.6) {
      return "🙂 꽤 잘 맞아요. 더 알아가보세요!";
    } else {
      return "🤔 아직은 거리감이 있어요. 천천히 다가가요.";
    }
  }
}
