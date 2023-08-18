import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:just_audio/just_audio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/services.dart'; // Import for SystemChrome



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
      statusBarColor: Colors.blue, // Set the status bar color
      statusBarBrightness: Brightness.dark, // Set the status bar content color
    ));
    return MaterialApp(
      title: 'TED Talks Podcasts',

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
        final podcastItem = PodcastItem(title, audioUrl ?? ''); // Provide a default value if audioUrl is null
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

  Future<void> downloadAndUploadToFirebaseStorage(PodcastItem podcast) async {
    final audioUrl = podcast.audioUrl;
    if (audioUrl != null) {
      final response = await http.get(Uri.parse(audioUrl));
      if (response.statusCode == 200) {
        final audioBytes = response.bodyBytes;

        // Upload the audio file to Firebase Storage
        final storageReference = firebase_storage.FirebaseStorage.instance
            .ref()
            .child('podcasts/${DateTime.now().millisecondsSinceEpoch}.mp3');

        final uploadTask = storageReference.putData(audioBytes);
        final snapshot = await uploadTask.whenComplete(() {});

        // Get the download URL
        if (snapshot.state == firebase_storage.TaskState.success) {
          final downloadUrl = await snapshot.ref.getDownloadURL();
          print('Audio uploaded to Firebase Storage: $downloadUrl');
          // Here you can provide a UI indication that the download and upload were successful
        } else {
          print('Error uploading audio to Firebase Storage');
          // Handle the error condition
        }
      } else {
        print('Error downloading audio file');
        // Handle the error condition
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
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: podcasts.length,
              itemBuilder: (context, index) {
                final podcast = podcasts[index];
                return Column(
                  children: [
                    ListTile(
                      title: Text(podcast.title),
                      trailing: IconButton(
                        icon: Icon(Icons.download_for_offline_outlined),
                        onPressed: () => downloadAndUploadToFirebaseStorage(podcast),
                        color: Colors.black, // Change this color to the desired color
                      ),
                      onTap: () => playPodcast(podcast),
                    ),
                    Divider(), // Add a Divider after each ListTile
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

class PodcastItem {
  final String title;
  final String? audioUrl; // Use String? to allow nullable value

  PodcastItem(this.title, this.audioUrl);
}
