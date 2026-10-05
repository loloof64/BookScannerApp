import 'dart:io';

import 'package:flutter/material.dart';

import '../services/page_flattener.dart';

/// Second confirmation after the crop: unrolls the gutter curvature and flattens
/// the lighting, then lets the user pick corrected / uncorrected.
/// Pops with the chosen image path, or null to go back to the crop preview.
class FlattenPreviewScreen extends StatefulWidget {
  final String croppedPath;

  const FlattenPreviewScreen({super.key, required this.croppedPath});

  @override
  State<FlattenPreviewScreen> createState() => _FlattenPreviewScreenState();
}

class _FlattenPreviewScreenState extends State<FlattenPreviewScreen> {
  String? _flatPath;
  bool _loading = true;
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    flattenPage(widget.croppedPath).then((path) {
      if (!mounted) return;
      setState(() {
        _flatPath = path;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final flat = _flatPath;
    final shown = (_showOriginal || flat == null) ? widget.croppedPath : flat;
    return Scaffold(
      appBar: AppBar(title: const Text('Page correction')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (flat == null)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Correction failed, original kept.'),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: InteractiveViewer(
                      child: Image.file(File(shown), fit: BoxFit.contain),
                    ),
                  ),
                ),
                if (flat != null)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Corrected')),
                      ButtonSegment(value: true, label: Text('Original')),
                    ],
                    selected: {_showOriginal},
                    onSelectionChanged: (s) =>
                        setState(() => _showOriginal = s.first),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, shown),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: Text(
                          _showOriginal || flat == null
                              ? 'Keep original'
                              : 'Keep corrected',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
