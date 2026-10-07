import 'package:flutter/material.dart';

import 'orientation_controller.dart';
import 'face_protection_controller.dart';

class OrientationDialog extends StatelessWidget {
  const OrientationDialog({
    super.key,
    required this.controller,
    required this.faces,
  });
  final OrientationController controller;
  final FaceProtectionController faces;

  Widget _slider(String label, double value, ValueChanged<double> update) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label),
          Text('Allowed: -${value.round()}\u00b0 to +${value.round()}\u00b0'),
          Slider(
            value: value,
            min: 0,
            max: 180,
            divisions: 180,
            label: '${value.round()}\u00b0',
            semanticFormatterCallback: (value) =>
                'Plus or minus ${value.round()} degrees',
            onChanged: update,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, faces]),
    builder: (context, _) => AlertDialog(
      title: const Text('Privacy settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.enabled) ...[
              _slider(
                'Theta / Tilt threshold',
                controller.thetaThreshold,
                (value) =>
                    controller.setThresholds(value, controller.phiThreshold),
              ),
              const SizedBox(height: 16),
              _slider(
                'Phi / Yaw threshold',
                controller.phiThreshold,
                (value) =>
                    controller.setThresholds(controller.thetaThreshold, value),
              ),
              const SizedBox(height: 12),
              Text(
                controller.error ??
                    (!controller.ready
                        ? 'Waiting for sensor...'
                        : controller.triggered
                        ? 'Threshold exceeded'
                        : 'Within thresholds'),
                style: TextStyle(
                  color: controller.protected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
              const Divider(height: 28),
            ],
            Row(
              children: [
                const Icon(Icons.videocam_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(faces.status)),
                if (faces.error != null)
                  IconButton(
                    tooltip: 'Retry camera access',
                    onPressed: faces.retry,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (controller.enabled)
          TextButton.icon(
            onPressed: controller.ready ? controller.calibrate : null,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Calibrate'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
