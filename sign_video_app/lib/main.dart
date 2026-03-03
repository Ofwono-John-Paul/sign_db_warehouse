import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: UploadScreen(),
    );
  }
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {

  final TextEditingController titleController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController uploaderController = TextEditingController();

  PlatformFile? selectedFile;

  Future<void> pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null) {
      setState(() {
        selectedFile = result.files.first;
      });
    }
  }

  Future<void> uploadVideo() async {

    if (selectedFile == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please select a video")));
      return;
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://127.0.0.1:5000/upload'),
    );

    request.fields['title'] = titleController.text;
    request.fields['category'] = categoryController.text;
    request.fields['uploader_name'] = uploaderController.text;

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        selectedFile!.path!,
      ),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Upload Successful")));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Upload Failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Video Upload")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [

            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Title"),
            ),

            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: "Category"),
            ),

            TextField(
              controller: uploaderController,
              decoration: const InputDecoration(labelText: "Uploader Name"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: pickVideo,
              child: const Text("Select Video"),
            ),

            if (selectedFile != null)
              Text("Selected: ${selectedFile!.name}"),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: uploadVideo,
              child: const Text("Upload"),
            ),
          ],
        ),
      ),
    );
  }
}