import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlgoArena Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TestHomePage(),
    );
  }
}

class TestHomePage extends StatefulWidget {
  const TestHomePage({super.key});

  @override
  State<TestHomePage> createState() => _TestHomePageState();
}

class _TestHomePageState extends State<TestHomePage> {
  late IO.Socket socket;
  String status = 'Not connected';
  String roomStatus = 'Not joined';
  int playerCount = 0;
  String question = '';
  String complexity = '';
  int timeLeft = 0;
  bool canAnswer = false;
  final TextEditingController answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    connectToServer();
  }

  void connectToServer() {
    socket = IO.io(
      'http://10.72.101.43:5000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.emit('setUid', 'test-user-${DateTime.now().millisecondsSinceEpoch}');

    socket.onConnect((_) {
      setState(() {
        status = '✅ Connected to server';
      });
      print('✅ Connected to server');
    });

    socket.onConnectError((data) {
      setState(() {
        status = '❌ Connection error: $data';
      });
      print('❌ Connection error: $data');
    });

    socket.onDisconnect((_) {
      setState(() {
        status = '❌ Disconnected';
      });
      print('❌ Disconnected');
    });

    socket.on('joinedRoom', (roomId) {
      setState(() {
        roomStatus = '✅ Joined room: $roomId';
      });
      print('✅ Joined room: $roomId');
    });

    socket.on('playerCountUpdate', (data) {
      setState(() {
        playerCount = data['count'] ?? 0;
        canAnswer = playerCount >= 2;
      });
      print('📊 Player count: ${data['count']}, Message: ${data['message']}');
    });

    // Add question display when game starts
    socket.on('gameStarted', (data) {
      setState(() {
        question = data['question'] ?? '';
        complexity = data['complexity'] ?? '';
        timeLeft = data['timeLimit'] ?? 60;
        canAnswer = true;
      });
      print('🎮 Game started! Question: $question');
    });

    socket.on('wrongAnswer', (data) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? 'Wrong answer!'),
          backgroundColor: Colors.red,
        ),
      );
      answerController.clear();
    });

    socket.on('gameFinished', (data) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('🏆 Winner!'),
          content: Text(data['message'] ?? 'Game finished!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  void joinRoom() {
    socket.emit('joinRoom', 'Room 101');
  }

  void submitAnswer() {
    if (answerController.text.isEmpty) return;
    socket.emit('submitAnswer', {
      'roomId': 'Room 101',
      'answer': answerController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AlgoArena Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: status.contains('✅') ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Status: $status',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 16),

            // Room Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: roomStatus.contains('✅') ? Colors.blue.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Room: $roomStatus',
                style: const TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 16),

            // Player Count with better status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: playerCount >= 2 ? Colors.green.shade100 : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: playerCount >= 2 ? Colors.green : Colors.orange,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    playerCount >= 2 ? Icons.check_circle : Icons.hourglass_bottom,
                    color: playerCount >= 2 ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Players: $playerCount/2',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          playerCount >= 2
                              ? '🚀 Game Starting!'
                              : playerCount == 1
                                  ? '⏳ Finding teammates...'
                                  : 'Click "Join Room 101" to start',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Join Room Button
            ElevatedButton(
              onPressed: joinRoom,
              child: const Text('🎮 Join Room 101'),
            ),

            const SizedBox(height: 24),

            // Question Display (if available)
            if (question.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question:',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question,
                      style: const TextStyle(fontSize: 18),
                    ),
                    if (complexity.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Complexity: $complexity',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Answer Input
              TextField(
                controller: answerController,
                enabled: canAnswer,
                decoration: InputDecoration(
                  labelText: canAnswer ? 'Enter your answer' : 'Waiting for players...',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: canAnswer ? Colors.white : Colors.grey.shade200,
                ),
              ),

              const SizedBox(height: 16),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canAnswer ? submitAnswer : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: canAnswer ? Colors.green : Colors.grey,
                  ),
                  child: Text(
                    canAnswer ? '🚀 Submit Answer' : 'Waiting for 2 players...',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],

            const Spacer(),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 How to Test:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. Click "Join Room 101"'),
                  Text('2. Open this app on another device'),
                  Text('3. Click "Join Room 101" on second device'),
                  Text('4. Both devices will show the question'),
                  Text('5. First to answer correctly wins!'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    socket.disconnect();
    answerController.dispose();
    super.dispose();
  }
}
