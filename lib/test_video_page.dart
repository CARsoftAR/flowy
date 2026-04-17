import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class TestVideoPage extends StatefulWidget {
  const TestVideoPage({super.key});

  @override
  State<TestVideoPage> createState() => _TestVideoPageState();
}

class _TestVideoPageState extends State<TestVideoPage> {
  late final Player _player;
  late final VideoController _controller;
  bool _isReady = false;
  String _status = 'Initializing...';
  int _textureId = -1;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: false,
      ),
    );
    
    _controller.id.addListener(_onTextureIdChanged);
    
    _player.open(Media('https://www.w3schools.com/html/mov_bbb.mp4')).then((_) {
      _player.play();
      setState(() {
        _isReady = true;
        _status = 'Playing!';
      });
    }).catchError((e) {
      setState(() {
        _status = 'Error: $e';
      });
    });
  }

  void _onTextureIdChanged() {
    setState(() {
      _textureId = _controller.id.value ?? -1;
    });
  }

  @override
  void dispose() {
    _controller.id.removeListener(_onTextureIdChanged);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          AppBar(
            title: Text(_status),
            backgroundColor: Colors.black,
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _isReady
                    ? Video(
                        controller: _controller,
                        fill: Colors.black,
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
          Text(
            'Video Controller Texture ID: $_textureId',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
