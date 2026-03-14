import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../services/api_service.dart';

class _SelectedVideo {
  const _SelectedVideo({
    required this.name,
    required this.bytes,
    required this.captureDevice,
    this.path,
  });

  final String name;
  final List<int> bytes;
  final String captureDevice;
  final String? path;

  double get sizeInMb => bytes.length / 1024 / 1024;
  bool get isRecordedLive => captureDevice == 'Live Recording';
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final titleController = TextEditingController();
  final glossController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? selectedCategory;
  _SelectedVideo? selectedVideo;
  bool consentToUpload = false;
  bool recordingAccepted = false;
  bool isUploading = false;

  final List<String> categories = ['Health', 'Education'];

  @override
  void dispose() {
    titleController.dispose();
    glossController.dispose();
    super.dispose();
  }

  Future<void> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    if (file.bytes == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to read video bytes. Please choose another file.',
          ),
        ),
      );
      return;
    }

    setState(() {
      selectedVideo = _SelectedVideo(
        name: file.name,
        bytes: file.bytes!,
        captureDevice: 'File Upload',
        path: file.path,
      );
      recordingAccepted = false;
      consentToUpload = false;
    });
  }

  Future<void> recordLiveVideo() async {
    try {
      final recordedVideo = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2),
      );

      if (recordedVideo == null) {
        return;
      }

      final bytes = await recordedVideo.readAsBytes();
      if (!mounted) {
        return;
      }

      setState(() {
        selectedVideo = _SelectedVideo(
          name: recordedVideo.name,
          bytes: bytes,
          captureDevice: 'Live Recording',
          path: recordedVideo.path,
        );
        recordingAccepted = false;
        consentToUpload = false;
      });

      final accepted = await _showVideoPreviewDialog(requireDecision: true);
      if (!mounted) {
        return;
      }

      if (accepted) {
        setState(() {
          recordingAccepted = true;
        });
      } else {
        setState(() {
          selectedVideo = null;
          recordingAccepted = false;
          consentToUpload = false;
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Live recording is unavailable on this device or permission was denied. Error: $e',
          ),
        ),
      );
    }
  }

  Future<VideoPlayerController?> _createPreviewController() async {
    final video = selectedVideo;
    final path = video?.path;
    if (video == null || path == null || path.isEmpty) {
      return null;
    }

    final controller = VideoPlayerController.contentUri(Uri.file(path));
    await controller.initialize();
    controller.setLooping(true);
    return controller;
  }

  Future<bool> _showVideoPreviewDialog({required bool requireDecision}) async {
    final video = selectedVideo;
    if (video == null) {
      return false;
    }

    VideoPlayerController? controller;
    bool playerReady = false;

    try {
      controller = await _createPreviewController();
      playerReady = controller != null;
      if (playerReady) {
        await controller.play();
      }
    } catch (_) {
      playerReady = false;
      await controller?.dispose();
      controller = null;
    }

    if (!mounted) {
      await controller?.dispose();
      return false;
    }

    final decision = await showDialog<bool>(
      context: context,
      barrierDismissible: !requireDecision,
      builder: (context) {
        return AlertDialog(
          title: Text(
            requireDecision ? 'Preview Live Recording' : 'Video Preview',
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (playerReady && controller != null)
                  AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: VideoPlayer(controller),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Preview is unavailable on this platform. You can still continue.',
                    ),
                  ),
                const SizedBox(height: 12),
                Text('File: ${video.name}'),
                Text('Size: ${video.sizeInMb.toStringAsFixed(2)} MB'),
              ],
            ),
          ),
          actions: requireDecision
              ? [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel Recording'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Accept Recording'),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Close'),
                  ),
                ],
        );
      },
    );

    await controller?.pause();
    await controller?.dispose();
    return decision ?? false;
  }

  Future<bool> _confirmSubmission() async {
    final video = selectedVideo;
    if (video == null) {
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Submission'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('You are about to submit this video:'),
              const SizedBox(height: 10),
              Text('Title: ${titleController.text.trim()}'),
              Text('Category: ${selectedCategory ?? '-'}'),
              Text('Gloss: ${glossController.text.trim()}'),
              Text('Source: ${video.captureDevice}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Review Again'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm & Submit'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<void> uploadVideo() async {
    if (titleController.text.isEmpty ||
        selectedCategory == null ||
        glossController.text.isEmpty ||
        selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields and select a video'),
        ),
      );
      return;
    }

    if (selectedVideo!.isRecordedLive && !recordingAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please preview and accept your live recording first.'),
        ),
      );
      return;
    }

    if (!consentToUpload) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide consent before submitting this video.'),
        ),
      );
      return;
    }

    final confirmed = await _confirmSubmission();
    if (!confirmed) {
      return;
    }

    setState(() => isUploading = true);

    try {
      final success = await ApiService.uploadVideo(
        titleController.text.trim(),
        selectedCategory!,
        glossController.text.trim(),
        selectedVideo!.bytes,
        selectedVideo!.name,
        selectedVideo!.captureDevice,
      );

      if (!mounted) {
        return;
      }

      setState(() => isUploading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video uploaded successfully!')),
        );

        setState(() {
          titleController.clear();
          glossController.clear();
          selectedCategory = null;
          selectedVideo = null;
          consentToUpload = false;
          recordingAccepted = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Please try again.')),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => isUploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload Sign Language Video',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Contribute to the medical sign language dataset',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Video Title',
                          hintText: 'e.g., Sign for fever - Patient demo',
                          prefixIcon: const Icon(Icons.title),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Sign Category',
                          prefixIcon: const Icon(Icons.category),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: categories
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedCategory = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: glossController,
                        decoration: InputDecoration(
                          labelText: 'Gloss',
                          hintText:
                              'Type the meaning/interpretation of the sign',
                          prefixIcon: const Icon(Icons.sign_language),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            if (selectedVideo == null) ...[
                              Icon(
                                Icons.video_file,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No video selected',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 15),
                              ElevatedButton.icon(
                                onPressed: pickVideo,
                                icon: const Icon(Icons.cloud_upload),
                                label: const Text('Select Video File'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E88E5),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: recordLiveVideo,
                                icon: const Icon(Icons.videocam),
                                label: const Text('Record Live Video'),
                              ),
                            ] else ...[
                              Icon(
                                Icons.check_circle,
                                size: 48,
                                color: Colors.green[400],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                selectedVideo!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${selectedVideo!.sizeInMb.toStringAsFixed(2)} MB • ${selectedVideo!.captureDevice}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  TextButton.icon(
                                    onPressed: pickVideo,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Change File'),
                                  ),
                                  if (selectedVideo!.isRecordedLive)
                                    TextButton.icon(
                                      onPressed: recordLiveVideo,
                                      icon: const Icon(Icons.videocam),
                                      label: const Text('Record Again'),
                                    ),
                                  TextButton.icon(
                                    onPressed: () {
                                      _showVideoPreviewDialog(
                                        requireDecision:
                                            selectedVideo!.isRecordedLive,
                                      ).then((accepted) {
                                        if (!mounted ||
                                            selectedVideo == null ||
                                            !selectedVideo!.isRecordedLive) {
                                          return;
                                        }
                                        setState(() {
                                          recordingAccepted = accepted;
                                          if (!accepted) {
                                            selectedVideo = null;
                                            consentToUpload = false;
                                          }
                                        });
                                      });
                                    },
                                    icon: const Icon(Icons.play_circle),
                                    label: const Text('Preview'),
                                  ),
                                ],
                              ),
                              if (selectedVideo!.isRecordedLive) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      recordingAccepted
                                          ? Icons.verified
                                          : Icons.info_outline,
                                      size: 18,
                                      color: recordingAccepted
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        recordingAccepted
                                            ? 'Recording accepted. You can proceed to consent and submit.'
                                            : 'Preview and accept this recording before submitting.',
                                        style: TextStyle(
                                          color: recordingAccepted
                                              ? Colors.green
                                              : Colors.orange,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      CheckboxListTile(
                        value: consentToUpload,
                        onChanged: (value) {
                          setState(() {
                            consentToUpload = value ?? false;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'I confirm I have consent and permission to submit this video for the dataset.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isUploading ? null : uploadVideo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isUploading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cloud_upload),
                                    SizedBox(width: 10),
                                    Text(
                                      'Upload Video',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
