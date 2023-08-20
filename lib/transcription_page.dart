import 'package:flutter/material.dart';

class TranscriptionPage extends StatelessWidget {
  final String transcription;

  TranscriptionPage({required this.transcription});

  @override
  Widget build(BuildContext context) {
    // print('Transcription Data in TranscriptionPage: $transcription'); // Use 'transcription' here
    return Scaffold(
      appBar: AppBar(
        title: Text('Transcription'),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: EdgeInsets.all(16.0),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 10.0),
              Align(
                alignment: Alignment.centerLeft, // Aligns the text to the left
                child: Text(
                  'Podcast Transcript:',
                  style: TextStyle(
                    fontSize: 24.0,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 20.0),
              Padding(
                padding: EdgeInsets.all(8.0), // You can adjust the values as needed
                child: Text(
                  transcription,
                  style: TextStyle(
                    fontSize: 15.0,
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.justify, // Justify the text contents
                )
              )
            ],
          ),
        ),
      ),
    );
  }
}
