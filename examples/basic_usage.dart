import 'package:flutter/material.dart';
import 'package:oddsockets_flutter/oddsockets_flutter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OddSockets Flutter Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: OddSocketsExample(),
    );
  }
}

class OddSocketsExample extends StatefulWidget {
  @override
  _OddSocketsExampleState createState() => _OddSocketsExampleState();
}

class _OddSocketsExampleState extends State<OddSocketsExample> {
  late OddSocketsClient client;
  late OddSocketsChannel channel;
  List<String> messages = [];
  TextEditingController messageController = TextEditingController();
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeOddSockets();
  }

  Future<void> _initializeOddSockets() async {
    try {
      // Initialize the OddSockets client
      client = OddSocketsClient(
        OddSocketsConfig.defaultConfig('ak_live_1234567890abcdef'),
      );

      // Create a channel
      channel = client.channel('flutter-example-channel');

      // Subscribe to messages
      await channel.subscribe((message) {
        setState(() {
          messages.add('Received: ${message.data}');
        });
      });

      setState(() {
        isConnected = true;
        messages.add('Connected to OddSockets!');
      });
    } catch (e) {
      setState(() {
        messages.add('Error: $e');
      });
    }
  }

  Future<void> _sendMessage() async {
    if (messageController.text.isNotEmpty && isConnected) {
      try {
        await channel.publish(messageController.text);
        setState(() {
          messages.add('Sent: ${messageController.text}');
        });
        messageController.clear();
      } catch (e) {
        setState(() {
          messages.add('Send error: $e');
        });
      }
    }
  }

  @override
  void dispose() {
    channel.unsubscribe();
    client.disconnect();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OddSockets Flutter Example'),
        backgroundColor: isConnected ? Colors.green : Colors.red,
      ),
      body: Column(
        children: [
          // Connection status
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
            child: Text(
              isConnected ? 'Connected to OddSockets' : 'Connecting...',
              style: TextStyle(
                color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Messages list
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      messages[index],
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Message input
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'Enter message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isConnected ? _sendMessage : null,
                  child: Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
