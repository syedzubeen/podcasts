import 'package:flutter/material.dart';
import 'package:podcasts/podcast_item.dart'; // Import the file

class TranscriptionPage extends StatelessWidget {
  final String transcription;

  TranscriptionPage({required this.transcription});

  @override
  Widget build(BuildContext context) {
    print('Transcription Data in TranscriptionPage: $transcription'); // Use 'transcription' here
    return Scaffold(
      appBar: AppBar(
        title: Text('Transcription'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          transcription,
          style: TextStyle(fontSize: 16.0),
        ),
      ),
    );
  }
}
