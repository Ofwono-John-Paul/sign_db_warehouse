import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final titleController = TextEditingController();
  String? selectedCategory;
  String? selectedGloss;
  PlatformFile? selectedFile;
  bool isUploading = false;

  // Updated sign categories - Health and Education
  final List<String> categories = ['Health', 'Education'];

  // Updated gloss names based on category
  final Map<String, List<String>> glossNames = {
    'Health': [
      'Fever',
      'Cough',
      'Headache',
      'Stomach Ache',
      'Chest Pain',
      'Dizziness',
      'Nausea',
      'Fatigue',
      'Shortness of Breath',
      'Body Weakness',
      'Loss of Appetite',
      'Weight Loss',
      'Vision Problems',
      'Hearing Problems',
      'Skin Rash',
      'Joint Pain',
      'Back Pain',
      'Toothache',
      'Menstrual Pain',
      'Pregnancy',
      'Diabetes',
      'Hypertension',
      'Malaria',
      'Typhoid',
      'HIV/AIDS',
      'Tuberculosis',
      'Yes',
      'No',
      'Help',
      'Emergency',
      'Doctor',
      'Nurse',
      'Hospital',
      'Medicine',
      'Injection',
      'Blood Test',
      'X-Ray',
      'Surgery',
      'Ambulance',
      'Pharmacy',
      'Health Center',
      'Clinic',
    ],
    'Education': [
      'Student',
      'Teacher',
      'School',
      'Class',
      'Book',
      'Pen',
      'Notebook',
      'Paper',
      'Write',
      'Read',
      'Study',
      'Learn',
      'Teach',
      'Exam',
      'Test',
      'Quiz',
      'Homework',
      'Project',
      'Science',
      'Math',
      'English',
      'Social Studies',
      'Geography',
      'History',
      'Art',
      'Music',
      'Sports',
      'Library',
      'Principal',
      'Headmaster',
      'Office',
      'Playground',
      'Uniform',
      'Bag',
      'Chair',
      'Desk',
      'Blackboard',
      'Chalk',
      'Map',
      'Globe',
      'Computer',
      'Understand',
      'Remember',
      'Think',
      'Question',
      'Answer',
      'Explain',
    ],
  };

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
    if (titleController.text.isEmpty ||
        selectedCategory == null ||
        selectedGloss == null ||
        selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all fields and select a video"),
        ),
      );
      return;
    }

    setState(() => isUploading = true);

    try {
      bool success = await ApiService.uploadVideo(
        titleController.text,
        selectedCategory!,
        selectedGloss!,
        selectedFile!.bytes!,
        selectedFile!.name,
        'Web Upload',
      );

      setState(() => isUploading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Video uploaded successfully!")),
        );

        // Clear form
        setState(() {
          titleController.clear();
          selectedCategory = null;
          selectedGloss = null;
          selectedFile = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Upload failed. Please try again.")),
        );
      }
    } catch (e) {
      setState(() => isUploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
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
              "Upload Sign Language Video",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Contribute to the medical sign language dataset",
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
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Video Title
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: "Video Title",
                          hintText: "e.g., Sign for fever - Patient demo",
                          prefixIcon: const Icon(Icons.title),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sign Category - Health or Education
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          labelText: "Sign Category",
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
                            selectedGloss = null;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Gloss - Meaning of the sign
                      DropdownButtonFormField<String>(
                        value: selectedGloss,
                        decoration: InputDecoration(
                          labelText: "Gloss",
                          hintText: "Meaning of the sign video",
                          prefixIcon: const Icon(Icons.sign_language),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: selectedCategory != null
                            ? (glossNames[selectedCategory] ?? [])
                                  .map(
                                    (gloss) => DropdownMenuItem(
                                      value: gloss,
                                      child: Text(gloss),
                                    ),
                                  )
                                  .toList()
                            : [],
                        onChanged: selectedCategory == null
                            ? null
                            : (value) {
                                setState(() {
                                  selectedGloss = value;
                                });
                              },
                      ),
                      const SizedBox(height: 25),

                      // File Selection
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            if (selectedFile == null) ...[
                              Icon(
                                Icons.video_file,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "No video selected",
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 15),
                              ElevatedButton.icon(
                                onPressed: pickVideo,
                                icon: const Icon(Icons.cloud_upload),
                                label: const Text("Select Video File"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E88E5),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ] else ...[
                              Icon(
                                Icons.check_circle,
                                size: 48,
                                color: Colors.green[400],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                selectedFile!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "${(selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 15),
                              TextButton.icon(
                                onPressed: pickVideo,
                                icon: const Icon(Icons.refresh),
                                label: const Text("Change File"),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Upload Button
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
                                      "Upload Video",
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
