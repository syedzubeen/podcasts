import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TED Talks Podcasts',
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TED Talks Podcasts'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: podcasts.length,
              itemBuilder: (context, index) {
                final podcast = podcasts[index];
                return ListTile(
                  title: Text(podcast.title),
                  onTap: () => playPodcast(podcast),
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
