import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const HealthStreakApp());
}

class HealthStreakApp extends StatelessWidget {
  const HealthStreakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Streak',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const StreakHomePage(title: 'Daily Health Streak 🔥'),
    );
  }
}

class StreakHomePage extends StatefulWidget {
  const StreakHomePage({super.key, required this.title});

  final String title;

  @override
  State<StreakHomePage> createState() => _StreakHomePageState();
}

class _StreakHomePageState extends State<StreakHomePage> {
  int _currentStreak = 0;
  int _dailySteps = 0;
  final int _targetSteps = 6000; // Daily step goal
  bool _goalAchieved = false;
  bool _isLoading = false;

  // Define types to read from Health Connect / Samsung Health
  final types = [HealthDataType.STEPS];

  @override
  void initState() {
    super.initState();
    _loadStreakData();
    _fetchHealthData();
  }

  // Load saved streak from local storage
  Future<void> _loadStreakData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentStreak = prefs.getInt('current_streak') ?? 0;
    });
  }

  // Save streak to local storage
  Future<void> _saveStreakData(int streak) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_streak', streak);
  }

  // Fetch steps from Samsung Health via Health Connect
  Future<void> _fetchHealthData() async {
    setState(() {
      _isLoading = true;
    });

    final health = Health();

    // Request permissions
    bool requested = await health.requestAuthorization(types);

    if (requested) {
      // Get today's start and end time
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      try {
        // Fetch steps for today
        int? steps = await health.getTotalStepsInInterval(midnight, now);

        setState(() {
          _dailySteps = steps ?? 0;
          if (_dailySteps >= _targetSteps) {
            _goalAchieved = true;
            // If goal achieved, increase streak if not already counted today
            _checkAndIncrementStreak();
          } else {
            _goalAchieved = false;
          }
        });
      } catch (e) {
        debugPrint("Error fetching health data: $e");
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _checkAndIncrementStreak() async {
    final prefs = await SharedPreferences.getInstance();
    String lastDateChecked = prefs.getString('last_streak_date') ?? '';
    String todayStr = DateTime.now().toIso8601String().substring(0, 10);

    if (lastDateChecked != todayStr && _goalAchieved) {
      setState(() {
        _currentStreak += 1;
      });
      await _saveStreakData(_currentStreak);
      await prefs.setString('last_streak_date', todayStr);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Streak Badge
              const Icon(Icons.local_fire_department, size: 80, color: Colors.deepOrange),
              const SizedBox(height: 10),
              Text(
                '$_currentStreak Days Streak!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 30),
              
              // Progress Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        'Today\'s Steps: $_dailySteps / $_targetSteps',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 15),
                      LinearProgressIndicator(
                        value: (_dailySteps / _targetSteps).clamp(0.0, 1.0),
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        _goalAchieved 
                            ? '🎉 Goal Achieved! Streak Maintained!' 
                            : 'Keep moving to maintain your streak!',
                        style: TextStyle(
                          color: _goalAchieved ? Colors.green : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              // Refresh Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _fetchHealthData,
                icon: const Icon(Icons.sync),
                label: Text(_isLoading ? 'Syncing with Samsung Health...' : 'Refresh Data'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
