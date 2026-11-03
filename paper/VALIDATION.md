# Paper validation

Final paper build: Tectonic 0.15.0, official IEEEtran conference class and IEEEtran BibTeX style. Command from this directory:

```sh
/tmp/tectonic -C -k --keep-logs --reruns 2 main.tex
```

The portable compiler is a temporary tool; a standard TeX installation or another Tectonic installation can build the same sources using the README commands.

- Output: `main.pdf`, eight US-letter pages.
- BibTeX completed without warnings.
- Final LaTeX log: no undefined references/citations, missing glyphs, overfull boxes, or underfull horizontal boxes.
- One underfull vertical-box diagnostic on page 4 (badness 2253) reflects float/text spacing; the rendered page was inspected and has no overlap or clipped content.
- Rendered PDF pages 1, 2, 4, 7 and 8 were inspected during editing. Geometry charts and architecture were also inspected as source images.
- All final figure paths resolve within `paper/figures/`; paper compilation does not depend on adjacent analysis/simulator directories.
- Analysis checker passed: numerical tables, all six classifications, scenario inputs, LaTeX snippets and 26 figure files. Paper width table agrees with the generated CSV after unit conversion.
- Three app screenshot placeholders and author/affiliation placeholders are intentional.
- Four of the six owner-supplied references are verified to the stated evidence scope. Two incomplete records are preserved separately; see `SOURCE_VERIFICATION.md`.
- Android physical trials, calibration, biometric FAR/FRR, liveness and rendering latency are not validated by this PDF build. Application test/APK results are owned by the app integration work and are not inferred here.

No empirical outcomes have been filled into either `paper/calibration_template.csv` or `analysis/calibration/observations.csv`.
