import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SimpleMixer',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const MixerPage(),
    );
  }
}

class Track {
  final String name;
  final AudioPlayer player;
  double volume = 1.0;
  Track(this.name, this.player);
}

class MixerPage extends StatefulWidget {
  const MixerPage({super.key});

  @override
  State<MixerPage> createState() => _MixerPageState();
}

class _MixerPageState extends State<MixerPage> {
  final List<Track> _tracks = [];

  Future<void> _tambahTrack() async {
    final hasil = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav'],
      allowMultiple: true,
    );
    if (hasil == null) return;

    for (final f in hasil.files) {
      final path = f.path;
      if (path == null) continue;

      final player = AudioPlayer(handleAudioSessionActivation: false);
      try {
        await player.setFilePath(path);
        setState(() => _tracks.add(Track(f.name, player)));
      } catch (e) {
        await player.dispose();
        _pesan('Gagal memuat ${f.name}');
      }
    }
  }

  void _pesan(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _play(Track t) async {
    if (t.player.processingState == ProcessingState.completed) {
      await t.player.seek(Duration.zero);
    }
    t.player.play();
  }

  Future<void> _stop(Track t) async {
    await t.player.pause();
    await t.player.seek(Duration.zero);
  }

  Future<void> _playAll() async {
    await Future.wait(_tracks.map((t) => t.player.seek(Duration.zero)));
    for (final t in _tracks) {
      t.player.play();
    }
  }

  Future<void> _stopAll() async {
    for (final t in _tracks) {
      await _stop(t);
    }
  }

  Future<void> _hapus(int index) async {
    final t = _tracks.removeAt(index);
    setState(() {});
    await t.player.dispose();
  }

  @override
  void dispose() {
    for (final t in _tracks) {
      t.player.dispose();
    }
    super.dispose();
  }

  Widget _buatTile(int index) {
    final t = _tracks[index];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _hapus(index),
                ),
              ],
            ),
            Row(
              children: [
                StreamBuilder<PlayerState>(
                  stream: t.player.playerStateStream,
                  builder: (context, snap) {
                    final s = snap.data;
                    final sedangMain = (s?.playing ?? false) &&
                        s?.processingState != ProcessingState.completed;
                    return Row(
                      children: [
                        IconButton.filled(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: sedangMain ? null : () => _play(t),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.stop),
                          onPressed: () => _stop(t),
                        ),
                      ],
                    );
                  },
                ),
                const Icon(Icons.volume_up, size: 20),
                Expanded(
                  child: Slider(
                    value: t.volume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) {
                      setState(() => t.volume = v);
                      t.player.setVolume(v);
                    },
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text('${(t.volume * 100).round()}%'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SimpleMixer')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _tracks.isEmpty ? null : _playAll,
                    icon: const Icon(Icons.play_circle),
                    label: const Text('Play All'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _tracks.isEmpty ? null : _stopAll,
                    icon: const Icon(Icons.stop_circle),
                    label: const Text('Stop All'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tracks.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Belum ada track.\nTekan tombol + untuk memilih file MP3/WAV (minimal 3).',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _tracks.length,
                    itemBuilder: (_, i) => _buatTile(i),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambahTrack,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Audio'),
      ),
    );
  }
}
