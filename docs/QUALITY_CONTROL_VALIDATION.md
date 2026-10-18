# Quality-control integration validation — 2026-10-18

Environment: Windows, MATLAB R2024b. Base commit: `2d2b885f311abb6dd3beaddef61e5c6b227795a7`.
These checks validate integration and preservation of selected historical results; they do not establish universal accuracy improvements.

## Full PPP comparisons

Each run loaded its historical settings and was processed into a new result directory. Epoch timestamps, float-validity flags, finite-coordinate masks and available RAIM action arrays matched. Maximum absolute XYZ component differences were below the 1e-5 m regression threshold.

| Case | Epochs | Maximum XYZ component difference (m) |
|---|---:|---:|
| A761_GPS030 | 600 | 1.86264514923096e-08 |
| K80_baseline | 3600 | 0 |
| K80_exclude_code | 3600 | 0 |
| K80_downweight_code | 3600 | 0 |
| X6_baseline | 3600 | 0 |
| X6_exclude_code | 3600 | 0 |
| X6_downweight_code | 3600 | 0 |
| ACE5_baseline | 2272 | 0 |
| ACE5_exclude_code | 2272 | 0 |
| ACE5_downweight_code | 2272 | 0 |

## Targeted and GUI checks

- Settings defaults, allowed-field copying, invalid inputs and retired-switch rejection: PASS.
- GPS f2 weighting, synthetic predicted-phase metadata, RAIM monitor/numerics/actions: PASS.
- Weighting parser regression: all six cases PASS.
- GUI Apply, MAT save/reload, old settings defaults and generic-template isolation: PASS (39 fields, eight tabs).
- Original GUIDE control tags preserved: PASS. Eight tab screenshots inspected after layout correction.
- Detailed-diagnostics compaction preserves core results: PASS.
- `git diff --check`: PASS.
- User WORK settings and default parameter MAT restored byte-for-byte after GUI initialization tests.

Local evidence (excluded from commits): `tmp/gui_release_20261018/full_validation.csv`, `full_runs.log`, `final_tests.log`, `layout_tests.log`, and `gui_final/`. Full PPP outputs are under `RESULTS/GUI_RELEASE_20261018/`. Pre-change source is archived at `tmp/gui_release_20261018/before_gui_source.zip`.

## Limits

### Startup visibility correction

The initial GUI checks missed a saved `Visible=off` state in `GUI_PPP.fig`, introduced by the maintenance helper opening the figure invisibly before saving. This prevented normal `raPPPid` launches from showing a window. The helper now saves the figure with `Visible=on`; hidden integration tests explicitly request `Visible=off` and assert that the stored figure is visible. The real `WORK/raPPPid.m` entry was rerun and asserted a visible main window (`RAPPPID_PUBLIC_ENTRY_VISIBLE_PASS`, local `startup_fix.log`). Settings round-trip tests also passed again. This corrects the earlier GUI validation coverage gap.

The full runs exercised saved settings through PPP_main. GUI controls and persistence were tested separately; this is not manual coverage of every possible GUI combination. Prediction still requires external RINEX/CSV preparation. RAIM action calibration remains external and device/model dependent. The GUI rejects automatic multi-input prediction/RAIM-action batches. The revised TDCP detector is not proven to improve accuracy for every dataset. Historical scripts retain local paths and may require their original source/data environment.

## Parameter tooltip validation

`test_parameter_tooltips` verifies nonempty help on every edit, checkbox, radio button, popup, list, slider/toggle and table, including hidden/disabled controls. Coverage: 383 main-window parameters/tables plus 39 advanced fields. Advanced help is checked against every schema key. Settings round trips and the real raPPPid startup also passed after tooltip integration (`tooltips.log`). This is property/coverage verification, not a claim that every tooltip was manually hovered.
