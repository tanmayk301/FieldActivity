
import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/photo_service.dart';

class DayTrackingScreen extends StatefulWidget {
  final UserProfile user;

  const DayTrackingScreen({
    super.key,
    required this.user,
  });

  @override
  State<DayTrackingScreen> createState() =>
      _DayTrackingScreenState();
}

class _DayTrackingScreenState
    extends State<DayTrackingScreen> {
  final ApiService api = ApiService();
  final TextEditingController odometerController =
      TextEditingController();

  String entryType = 'Start Day';
  File? photo;
  bool saving = false;

  Future<void> capturePhoto() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () =>
                  Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () =>
                  Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    File? selectedPhoto;

    try {
      if (source == 'camera') {
        selectedPhoto = await PhotoService.takePhoto();
      } else {
        selectedPhoto =
            await PhotoService.pickFromGallery();
      }

      if (selectedPhoto != null && mounted) {
        setState(() => photo = selectedPhoto);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to capture photo: $e')),
        );
      }
    }
  }

  Future<void> saveEntry() async {
    FocusScope.of(context).unfocus();

    final kmText = odometerController.text.trim();
    final km = double.tryParse(kmText);

    if (kmText.isEmpty || km == null ||
        !km.isFinite || km < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid odometer reading.'),
        ),
      );
      return;
    }

    if (photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take or select a photo.'),
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      // Capture the current GPS location.
      final position = await LocationService.current();

      // Record the date and time when the entry is submitted.
      final entryTime = DateTime.now();

      await api.saveDayEntry(
        userId: widget.user.userId,
        entryType: entryType,
        odometerKm: km,
        entryTime: entryTime,
        latitude: position.latitude,
        longitude: position.longitude,
        photo: photo!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$entryType saved successfully.'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to save entry: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  void dispose() {
    odometerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Day / End Day'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Entry Type',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Start Day'),
                          selected: entryType == 'Start Day',
                          onSelected: saving
                              ? null
                              : (_) => setState(
                                    () => entryType =
                                        'Start Day',
                                  ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('End Day'),
                          selected: entryType == 'End Day',
                          onSelected: saving
                              ? null
                              : (_) => setState(
                                    () => entryType =
                                        'End Day',
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: odometerController,
                    enabled: !saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Odometer Reading (KM) *',
                      hintText: 'Enter current kilometre reading',
                      prefixIcon: Icon(Icons.speed),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Mandatory Photograph',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (photo != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        photo!,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed:
                          saving ? null : capturePhoto,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Change Photo'),
                    ),
                  ] else
                    Container(
                      height: 130,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey,
                        ),
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 36,
                          ),
                          SizedBox(height: 8),
                          Text('No photo selected'),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed:
                        saving ? null : capturePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text(
                      'Take Photo / Choose from Gallery',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Date, time and GPS location will be captured '
            'when you save the entry.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saving ? null : saveEntry,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(
              saving ? 'Saving Entry...' : 'Save $entryType',
            ),
          ),
        ],
      ),
    );
  }
}