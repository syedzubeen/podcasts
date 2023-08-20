import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:just_audio/just_audio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/services.dart'; // Import for SystemChrome
import 'transcription_page.dart';
import 'package:podcasts/podcast_item.dart';
import 'dart:convert';
import 'app_info_page.dart';




void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Customize the status bar
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.black, // Set the status bar color
      statusBarBrightness: Brightness.dark, // Set the status bar content color
    ));
    return MaterialApp(
      title: 'Podcast.AI',

      theme: ThemeData(
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black
        ),
      ),
      home: PodcastListScreen(),
    );
  }
}

class PodcastListScreen extends StatefulWidget {
  @override
  _PodcastListScreenState createState() => _PodcastListScreenState();
}

class _PodcastListScreenState extends State<PodcastListScreen> {
  List<PodcastItem> podcasts = [];
  late AudioPlayer audioPlayer;
  // Variable to keep track of the currently playing podcast
  PodcastItem? currentlyPlaying;
  String? transcriptionFileUrl; // Declare it here

  @override
  void initState() {
    super.initState();
    audioPlayer = AudioPlayer();
    fetchPodcasts();
  }

  Future<void> fetchPodcasts() async {
    final response = await http.get(Uri.parse('http://feeds.feedburner.com/TEDTalks_audio'));
    if (response.statusCode == 200) {
      final xmlDoc = xml.XmlDocument.parse(response.body);
      final items = xmlDoc.findAllElements('item');
      List<PodcastItem> podcastItems = [];
      for (var item in items) {
        final title = item.findElements('title').single.text;
        final enclosure = item.findElements('enclosure').first;
        final audioUrl = enclosure.getAttribute('url');
        // Add code to extract the thumbnail URL
        final mediaThumbnail = item.findElements('media:thumbnail').first;
        final thumbnailUrl = mediaThumbnail.getAttribute('url');
        //print('Thumbnail URL: $thumbnailUrl');
        // Provide a default value if audioUrl is null
        final podcastItem = PodcastItem(title, audioUrl ?? '', thumbnailUrl ?? '', '');
        podcastItems.add(podcastItem);
      }
      setState(() {
        podcasts = podcastItems;
      });
    } else {
      // Handle error
    }
  }

  Future<void> playPodcast(PodcastItem podcast) async {
    if (currentlyPlaying != null) {
      await audioPlayer.stop();
    }

    final audioUrl = podcast.audioUrl;
    if (audioUrl != null) {
      await audioPlayer.setUrl(audioUrl);
      await audioPlayer.play();
      setState(() {
        currentlyPlaying = podcast;
      });
    } else {
      // Handle the case where the audio URL is null
      print("Audio URL is null");
    }
  }

  Future<void> stopAudio() async {
    await audioPlayer.stop();
    setState(() {
      currentlyPlaying = null;
    });
  }

  Future<String?> downloadTranscription(String? transcriptionFileUrl) async {
    if (transcriptionFileUrl == null) {
      // Handle the case where transcriptionFileUrl is null
      print('Transcription file URL is null');
      return null;
    }

    try {
      final response = await http.get(Uri.parse(transcriptionFileUrl));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse.containsKey('results') && jsonResponse['results'] is List) {
          final results = jsonResponse['results'] as List;

          final transcriptList = results
              .map((result) =>
              (result['alternatives'] as List).map((alternative) => alternative['transcript'].toString()).join(" "))
              .toList();

          final transcript = transcriptList.join('\n');

          return transcript;
        } else {
          // Handle the case where 'results' key is missing or not a list
          print('Error: Invalid JSON format in response');
          return null;
        }
      } else {
        // Handle the error condition, e.g., return null or an error message
        print('Error: HTTP request failed with status ${response.statusCode}');
        return null;
      }
    } catch (error) {
      // Handle any exceptions that might occur during the HTTP request
      print('Error: $error');
      return null;
    }
  }



  Future<void> downloadAndUploadToFirebaseStorage(
      BuildContext context,
      PodcastItem podcast,
      ) async {
    final audioUrl = podcast.audioUrl;
    if (audioUrl != null) {
      final response = await http.get(Uri.parse(audioUrl));
      if (response.statusCode == 200) {
        final audioBytes = response.bodyBytes;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storageReference = firebase_storage.FirebaseStorage.instance
            .ref()
            .child('podcasts/$timestamp.mp3');

        final uploadTask = storageReference.putData(audioBytes);
        final snapshot = await uploadTask.whenComplete(() {});

        // Get the download URL for the audio file
        if (snapshot.state == firebase_storage.TaskState.success) {
          final downloadUrl = await snapshot.ref.getDownloadURL();
          // print('Audio uploaded to Firebase Storage: $downloadUrl');

          // Display a success SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Audio uploaded to Firebase Storage!'),
              backgroundColor: Colors.green,
            ),
          );
          // Introduce a 5-minute (300 seconds) delay before fetching the transcription file
          // Hardcoded wait for now
          await Future.delayed(Duration(seconds: 500 ));

          // Now, let's wait for the transcript file to become available
          final maxWaitTime = Duration(seconds: 120); // Adjust the timeout as needed
          final timeout = DateTime.now().add(maxWaitTime);

          transcriptionFileUrl = null; // Initialize to null in case of failure

          while (DateTime.now().isBefore(timeout)) {
            final transcriptionFileReference = firebase_storage.FirebaseStorage.instance
                .ref()
                .child('podcasts/$timestamp.mp3.wav_transcription.txt');

            final url = await transcriptionFileReference.getDownloadURL();
            // print('Transcription File URL: $url');
            if (url != null) {
              transcriptionFileUrl = url;
              break; // File found, exit the loop
            }

            // Wait for a short duration before checking again
            await Future.delayed(Duration(seconds: 10));
          }

          if (transcriptionFileUrl != null) {
            // print('Transcription file URL: $transcriptionFileUrl');
            downloadTranscription(transcriptionFileUrl);
            // Display a success SnackBar for the transcription file
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Transcription file downloaded successfully!'),
                backgroundColor: Colors.green,
              ),
            );

            // At this point, you have both the audio file and transcription file URLs
            // You can proceed to display or use them in your app
          } else {
            print('Transcription file not found within the timeout period');
            // Handle the case where the transcription file wasn't found
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Transcription file not found within the timeout period!'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          print('Error uploading audio to Firebase Storage');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading audio!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        print('Error downloading audio file');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading audio file!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      print('Audio URL is null');
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Podcasts.AI'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AppInfoPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: podcasts.length,
              itemBuilder: (context, index) {
                final podcast = podcasts[index];
                final thumbnailUrl = podcast.thumbnailUrl;

                return Column(
                  children: [
                    ListTile(
                      leading: thumbnailUrl != null
                          ? Image.network(
                        thumbnailUrl,
                        errorBuilder: (context, error, stackTrace) {
                          print('Image Error: $error');
                          return SizedBox.shrink();
                        },
                      )
                          : SizedBox.expand(),
                      title: Text(podcast.title),
                      trailing: Row(
                        // Start of Row for trailing icons
                        mainAxisSize: MainAxisSize.min, // Making the Row take minimum space
                        children: [
                          IconButton(
                            icon: Icon(Icons.download_for_offline_outlined),
                            onPressed: () async {
                              // Call downloadAndUploadToFirebaseStorage with context
                              await downloadAndUploadToFirebaseStorage(context, podcast);
                            },
                            color: Colors.black,
                          ),
                          IconButton(
                            onPressed: () async {
                              if (transcriptionFileUrl != null) {
                                final transcription = await downloadTranscription(transcriptionFileUrl);
                                if (transcription != null) {
                                  print('Podcast Transcription: ${transcription}');
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => TranscriptionPage(
                                          transcription: transcription
                                      ),
                                    ),
                                  );
                                } else {
                                  // Handle the cases where transcription is null or an error occurred
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error downloading transcription!'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } else {
                                // Handle the case where transcriptionFileUrl is null
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Transcription file URL is null!'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: Icon(Icons.sticky_note_2_sharp),
                          ),
                        ], // End of Row for trailing icons
                      ),
                      onTap: () => playPodcast(podcast),
                    ),
                    Divider(),
                  ],
                );
              },
            ),
          ),
          if (currentlyPlaying != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.stop),
                    onPressed: stopAudio,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}


