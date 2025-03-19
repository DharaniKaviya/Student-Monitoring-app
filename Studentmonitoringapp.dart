import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Monitoring App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginScreen(),
    );
  }
}

// Login Screen
class LoginScreen extends StatelessWidget {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _login(BuildContext context, bool isParent) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => isParent ? ParentDashboard() : ChildDashboard(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _emailController, decoration: InputDecoration(labelText: 'Email')),
            TextField(controller: _passwordController, decoration: InputDecoration(labelText: 'Password'), obscureText: true),
            SizedBox(height: 20),
            ElevatedButton(onPressed: () => _login(context, true), child: Text('Login as Parent')),
            ElevatedButton(onPressed: () => _login(context, false), child: Text('Login as Student')),
          ],
        ),
      ),
    );
  }
}

// Parent Dashboard
class ParentDashboard extends StatelessWidget {
  final AppUsageTracker _tracker = AppUsageTracker();
  final NotificationService _notifications = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Parent Dashboard')),
      body: FutureBuilder<List<UsageInfo>>(
        future: _tracker.getAppUsage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No app usage data found.'));
          } else {
            // Check for excessive usage and send a notification
            snapshot.data!.forEach((usage) {
              if (usage.totalTimeInForeground > 3600000) { // 1 hour in milliseconds
                _notifications.showWarning('Usage Alert', '${usage.packageName} used for more than 1 hour.');
              }
            });

            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                UsageInfo usage = snapshot.data![index];
                return ListTile(
                  title: Text(usage.packageName),
                  subtitle: Text('Usage: ${usage.totalTimeInForeground} ms'),
                );
              },
            );
          }
        },
      ),
    );
  }
}

// Child Dashboard
class ChildDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome, Student!'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EducationalResources()),
                );
              },
              child: Text('Access Educational Resources'),
            ),
          ],
        ),
      ),
    );
  }
}

// Educational Resources
class EducationalResources extends StatelessWidget {
  final List<Map<String, String>> videos = [
    {'title': 'Khan Academy - Math', 'url': 'https://www.khanacademy.org/math'},
    {'title': 'Crash Course - Science', 'url': 'https://www.youtube.com/user/crashcourse'},
    {'title': 'TED-Ed - Learning', 'url': 'https://ed.ted.com/'},
  ];

  final List<Map<String, String>> books = [
    {'title': 'OpenStax - Free Textbooks', 'url': 'https://openstax.org/'},
    {'title': 'Project Gutenberg - Free eBooks', 'url': 'https://www.gutenberg.org/'},
    {'title': 'Google Books', 'url': 'https://books.google.com/'},
  ];

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Educational Resources')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Videos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          ...videos.map((video) => ListTile(
            title: Text(video['title']!),
            onTap: () => _launchURL(video['url']!),
          )).toList(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Books', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          ...books.map((book) => ListTile(
            title: Text(book['title']!),
            onTap: () => _launchURL(book['url']!),
          )).toList(),
        ],
      ),
    );
  }
}

// App Usage Tracker
class AppUsageTracker {
  Future<List<UsageInfo>> getAppUsage() async {
    DateTime endDate = DateTime.now();
    DateTime startDate = endDate.subtract(Duration(days: 1)); // Last 24 hours
    List<UsageInfo> usageStats = await UsageStats.queryUsageStats(startDate, endDate);
    return usageStats;
  }
}

// Notification Service
class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notifications.initialize(initializationSettings);
  }

  Future<void> showWarning(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('channel_id', 'channel_name', importance: Importance.max, priority: Priority.high);
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _notifications.show(0, title, body, platformChannelSpecifics);
  }
}