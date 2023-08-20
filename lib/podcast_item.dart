class PodcastItem {
  final String title;
  final String? audioUrl; // Use String? to allow nullable value
  final String? thumbnailUrl; // Add the thumbnailUrl property
  final String? transcription; // Add the transcription property

  PodcastItem(this.title, this.audioUrl, this.thumbnailUrl, this.transcription);
}