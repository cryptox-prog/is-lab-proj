# Paper artifact contract

Run `python -m analysis.generate` from the repository root with matplotlib and numpy installed.
The simulator README gives environment setup. Outputs are deterministic geometric scenarios,
not observations, calibration, accuracy measurements, or empirical performance results.

All files below are in `analysis/generated/`:

| Basename | Formats | Meaning |
| --- | --- | --- |
| `coverage_vs_distance` | PDF, PNG | Sensor-relative forward-plane widths |
| `angular_sensitivity` | PDF, PNG | Ideal angular RBU versus assumed effective optical FOV |
| `mode_1` through `mode_6` | PDF, PNG | Six configurations, same synthetic observer locations |
| `safe_case` | PDF, PNG | Privacy-readable sector excludes a lateral undetected observer |
| `angular_geometry` | PDF, PNG | Ideal 75/60-degree subset versus body occlusion |
| `fisheye_geometry` | PDF, PNG | Nominal 180-degree optical / assumed effective 120-degree sectors |
| `radar_geometry` | PDF, PNG | Offset radar with optimistic occlusion-off assumption |
| `angles` | CSV, TEX | Assumed angles and provenance |
| `coverage_widths` | CSV, TEX | Computed widths at four reference distances |
| `mode_comparison` | CSV, TEX | Geometry and hardware assumptions |
| `observer_classifications` | CSV, TEX | Two observers per mode, flags and global trigger |
| `angular_sensitivity` | CSV, TEX | Ideal angular differences; no occlusion |
| `scenario` | JSON | Default configuration used to generate figures |
| `manifest` | JSON | Provenance, formulas, shading semantics, output listing |
| `worked_example` | TEX | Numerical 0.40 m / 75-degree calculation |

The combined six-mode figure is `simulation/generated/scenarios.pdf` (and `.png`).
The Kenko REALPRO nominal 180-degree label follows the coordinating paper agent's verified
specification; this analysis does not supply a manufacturer projection or measured effective FOV.

LaTeX table snippets include a table environment and caption; require `graphicx` for
`resizebox`. Include using the consuming paper's relative path. No bibliography entries are
needed for these explicitly hypothetical calculations. No measured-angle table is provided.

Camera, privacy, and effective-fisheye widths refer to distance from the phone. Radar width
refers to distance from the radar: equal numerical distance does not imply a shared world
plane when radar is offset. Effective fisheye 120-degree widths are sector/plane intersections,
not an optical projection model. Nominal 180-degree fisheye has no finite forward-plane width.
Sensitivity angles 70--200 degrees are hypothetical parameter sweeps, not calibrated ranges.
At 75 degrees camera and 60 degrees readability the ideal angular blind region is zero.
Default snapshots leave optical occlusion off and detect visible central faces. The
separate side-by-side body-occlusion example demonstrates a possible central blind
region only under the explicit opaque-circle assumption, not an unavoidable blind spot.

Run `python -m analysis.check_outputs` after generation to check tables against the shared
geometry, scenario parameters, classifications, and output signatures. Geometry unit tests:
`python -m unittest discover -s simulation/tests -v`.
