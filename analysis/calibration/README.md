# Physical calibration records

No device-specific trial records were supplied or measured in this environment.
The reference ranges in the request are not experimental calibration results.
`observations.csv` is intentionally header-only: append real trials, not inferred
successes. Do not replace the paper's missing-measurement labels until trials exist.

Record phone model/OS, camera resolution, portrait/landscape orientation, detector
and model versions, protector brand and direction, lens model/alignment, radar
firmware/pose, display brightness, ambient illumination, and consenting subjects.

1. **Normal camera:** measure distance from camera to face. Move a consenting
   subject through known lateral positions on both sides. Compute bearing with
   `degrees(atan2(lateral_m, forward_m))`. Record repeated detection trials at
   each bearing and distance, not merely optical image visibility. Report each
   side separately and a predeclared reliability criterion, such as detection in
   at least 19 of 20 trials. Report uncertainty and sample counts.
2. **Protector:** use fixed-size randomized text and score correct reading under
   specified illumination, brightness, font size, distance and angle. Repeat both
   sides; optical readability is not a universal hard boundary. Document whether
   the filter restricts horizontal viewing only.
3. **Fisheye:** record the physical attachment and alignment. Repeat camera trials
   including edge faces. Nominal 180-degree optical FOV is not an effective
   detection angle. If fitting a projection, photograph angular calibration
   landmarks and fit/evaluate on separate points; do not assume a manufacturer
   mapping. Enter measured effective left/right limits independently.
4. **Radar:** use radar-relative coordinates and repeated moving/stationary trials
   with one, two and three targets, including the user outside the radar sector.
   Record missed/merged targets and occlusions. Check count > 1 as the threat rule;
   the radar does not authenticate the user.
5. **Distance:** measure actual camera-to-user distance with a ruler/tape in each
   posture. The supplied 35/40/55/60 cm remain scenario values until measured.
6. **Verification:** collect independent genuine/impostor validation and held-out
   sessions without retaining raw face images unnecessarily. Enrollment-only
   consistency is not a false-accept-rate calibration. See `assets/models/README.md`.

Use `subject_code`, not names. Keep any identifiable research records outside
the repository. Generated geometric figures remain mathematical scenario results.
