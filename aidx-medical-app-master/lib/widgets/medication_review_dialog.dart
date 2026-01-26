import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'glass_container.dart';

class MedicationReviewDialog extends StatefulWidget {
  final List<Map<String, String>> medications;

  const MedicationReviewDialog({super.key, required this.medications});

  @override
  _MedicationReviewDialogState createState() => _MedicationReviewDialogState();
}

class _MedicationReviewDialogState extends State<MedicationReviewDialog> {
  late List<Map<String, String>> _editableMedications;

  @override
  void initState() {
    super.initState();
    _editableMedications = List.from(widget.medications);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      content: GlassContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Review Medications',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _editableMedications.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: AppTheme.bgGlassMedium,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          TextFormField(
                            initialValue: _editableMedications[index]['name'],
                            decoration: InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white)),
                            style: TextStyle(color: Colors.white),
                            onChanged: (value) => _editableMedications[index]['name'] = value,
                          ),
                          TextFormField(
                            initialValue: _editableMedications[index]['dosage'],
                            decoration: InputDecoration(labelText: 'Dosage', labelStyle: TextStyle(color: Colors.white)),
                            style: TextStyle(color: Colors.white),
                            onChanged: (value) => _editableMedications[index]['dosage'] = value,
                          ),
                          TextFormField(
                            initialValue: _editableMedications[index]['frequency'],
                            decoration: InputDecoration(labelText: 'Frequency', labelStyle: TextStyle(color: Colors.white)),
                            style: TextStyle(color: Colors.white),
                            onChanged: (value) => _editableMedications[index]['frequency'] = value,
                          ),
                          TextFormField(
                            initialValue: _editableMedications[index]['timing'],
                            decoration: InputDecoration(labelText: 'Timing', labelStyle: TextStyle(color: Colors.white)),
                            style: TextStyle(color: Colors.white),
                            onChanged: (value) => _editableMedications[index]['timing'] = value,
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: AppTheme.dangerColor),
                            onPressed: () {
                              setState(() {
                                _editableMedications.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _editableMedications),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                  ),
                  child: Text('Save Selected'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dangerColor,
                  ),
                  child: Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
