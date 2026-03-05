// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:file_picker/file_picker.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       home: UploadScreen(),
//     );
//   }
// }

// class UploadScreen extends StatefulWidget {
//   const UploadScreen({super.key});

//   @override
//   State<UploadScreen> createState() => _UploadScreenState();
// }

// class _UploadScreenState extends State<UploadScreen> {
//   final TextEditingController titleController = TextEditingController();
//   final TextEditingController categoryController = TextEditingController();

//   PlatformFile? selectedFile;

//   int? selectedSchoolId;

//   // TEMP MOCK DATA (later we fetch from Flask)
//   final List<Map<String, dynamic>> schools = [
//     {"school_id": 1, "school_name": "Kampala School for the Deaf"},
//     {"school_id": 2, "school_name": "Mbarara Special Needs School"},
//     {"school_id": 3, "school_name": "Gulu Deaf Primary School"},
//   ];

//   Future<void> pickVideo() async {
//     FilePickerResult? result = await FilePicker.platform.pickFiles(
//       type: FileType.video,
//       withData: true,
//     );

//     if (result != null) {
//       setState(() {
//         selectedFile = result.files.first;
//       });
//     }
//   }

//   Future<void> uploadVideo() async {
//     if (selectedFile == null || selectedSchoolId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Select school and video")),
//       );
//       return;
//     }

//     try {
//       var request = http.MultipartRequest(
//         'POST',
//         Uri.parse('http://127.0.0.1:5000/upload'),
//       );

//       request.fields['title'] = titleController.text;
//       request.fields['category'] = categoryController.text;
//       request.fields['school_id'] = selectedSchoolId.toString();

//       request.files.add(
//         http.MultipartFile.fromBytes(
//           'file',
//           selectedFile!.bytes!,
//           filename: selectedFile!.name,
//         ),
//       );

//       var response = await request.send();

//       if (response.statusCode == 200) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Upload Successful")),
//         );

//         setState(() {
//           titleController.clear();
//           categoryController.clear();
//           selectedFile = null;
//           selectedSchoolId = null;
//         });
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Upload Failed")),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error: $e")),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Sign Video Upload")),
//       body: Padding(
//         padding: const EdgeInsets.all(20.0),
//         child: Column(
//           children: [
//             TextField(
//               controller: titleController,
//               decoration: const InputDecoration(labelText: "Title"),
//             ),

//             TextField(
//               controller: categoryController,
//               decoration: const InputDecoration(labelText: "Category"),
//             ),

//             const SizedBox(height: 15),

//             // 🔥 School Dropdown
//             DropdownButtonFormField<int>(
//               decoration: const InputDecoration(labelText: "Select School"),
//               value: selectedSchoolId,
//               items: schools.map((school) {
//                 return DropdownMenuItem<int>(
//                   value: school['school_id'],
//                   child: Text(school['school_name']),
//                 );
//               }).toList(),
//               onChanged: (value) {
//                 setState(() {
//                   selectedSchoolId = value;
//                 });
//               },
//             ),

//             const SizedBox(height: 20),

//             ElevatedButton(
//               onPressed: pickVideo,
//               child: const Text("Select Video"),
//             ),

//             if (selectedFile != null)
//               Text("Selected: ${selectedFile!.name}"),

//             const SizedBox(height: 20),

//             ElevatedButton(
//               onPressed: uploadVideo,
//               child: const Text("Upload"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/upload_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadToken();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ApiService.token == null
          ? const LoginScreen()
          : const UploadScreen(),
    );
  }
}