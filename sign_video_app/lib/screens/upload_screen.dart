import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'login_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {

  final titleController = TextEditingController();
  final categoryController = TextEditingController();
  PlatformFile? selectedFile;

  Future<void> pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
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
          .showSnackBar(const SnackBar(content: Text("Select a video")));
      return;
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiService.baseUrl}/upload'),
    );

    request.headers['Authorization'] =
        "Bearer ${ApiService.token}";

    request.fields['title'] = titleController.text;
    request.fields['category'] = categoryController.text;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        selectedFile!.bytes!,
        filename: selectedFile!.name,
      ),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Upload Successful")));

      setState(() {
        titleController.clear();
        categoryController.clear();
        selectedFile = null;
      });
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Upload Failed")));
    }
  }

  void logout() async {
    await ApiService.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Sign Video"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
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