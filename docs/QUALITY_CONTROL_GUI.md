# Advanced quality control

Start MATLAB in `WORK`, run `raPPPid`, then choose **Advanced quality control** in the main window menu. The existing **Weighting** panel contains **GPS f2 Code: SNR-dependent std**. Click **Apply** in the advanced dialog, then use the normal processing button.

## Controls and defaults

| Control | How to enable | Boundary |
|---|---|---|
| GPS frequency-2 SNR std | Enable frequency-specific std and the GPS f2 checkbox | Only GPS frequency slot 2 raw code; default off |
| Robust Doppler | Main-window Doppler detector + advanced robust checkbox | Default legacy integration; 5x3 mask rows GPS/GLO/GAL/BDS/QZSS, columns selected frequency slots |
| TDCP | Main-window TDCP checkbox; advanced record-only option | Per-frequency decisions, MAD multiplier, minimum satellites and rejection limit; default detector remains off for settings without TDCP |
| Cold start | Advanced cold-start checkbox | Requires Code + Phase and phase-to-code adjustment or receiver clock-jump handling; Reset remains an independent main-window option |
| Predicted phase | Advanced prediction checkbox + metadata CSV | Input RINEX must already contain predictions; this does not run external preprocessing |
| Prediction quality | Quality CSV, RMS/sample limits and sigma multiplier | Missing quality is rejected by default; existing explicit historical settings are preserved |
| RAIM monitor | Enable RAIM, action `none` | Diagnostic only; does not certify integrity or output HPL/VPL |
| RAIM actions | Enable RAIM, select `exclude_code`/`downweight_code`, import calibration | Experimental, frozen WLS calibration only; requires GPS week/start SOW and compatible Code + Phase model |
| Detailed diagnostics | Diagnostics tab | Controls detailed frequency arrays in data4plot.mat; calculation and scalar diagnostics remain unchanged |

Frequency labels L1/L2/L3 refer to configured slots, not a universal physical band. For example, GPS slot 2 may be L5. Optional allowed signals use strings such as `G:L1C,C:L2I`, comma separated. Empty means all selected signals.

RAIM calibration MAT must contain numeric positive `model.global_scale`, unique finite `model.keys` and corresponding positive `model.scales`. Select the calibration for the same observation model/device. The GUI validates structure; it does not establish that a calibration from another device is scientifically applicable. Actions are restricted to the entered GPS week. Training and independent validation must be prepared separately; the GUI does not fit a model using the data being scored.

## Persistence and compatibility

Advanced fields are explicitly round-tripped by `getSettingsFromGUI` and `setSettingsToGUI`. Missing fields in old settings get defaults. Full `settings.mat` files retain input-specific configuration. Generic parameter templates intentionally disable prediction and RAIM actions and clear their input-specific file paths; rebind these inputs after loading a generic template.

Prediction metadata has to overlap the observation session. CSV column checks run before processing. RAIM action week checks prevent accidental cross-week application. Automatic matching of arbitrary multi-file batches is not implemented: the GUI rejects prediction/RAIM-action batches. A script may bind each input explicitly and set `PROC.quality_control_single_input=true` for that individual invocation.

The refined TDCP algorithm is the retained implementation: it no longer propagates a single-frequency anomaly to every frequency. Existing TDCP-enabled settings use this corrected implementation; bitwise reproduction of the older detector is not promised. Use the archived source for historical algorithm comparisons. The GUI displays this migration boundary rather than offering a misleading legacy mode containing the known defect.

The internal soft multipath, soft OMC and smartphone stochastic experiments are removed from the production path. Direct calls with these switches enabled are rejected. Importing their settings in the GUI emits a warning and does not copy retired switches. The original multipath and OMC detection paths remain.

## Reproducible script entry

From `WORK`, add `../CODE` recursively, then call:

```matlab
runQualityControlExperiment(settings_file, 'my_run', 'single');
runQualityControlExperiment(settings_file, 'cold_ablation', 'cold_start_ablation');
runQualityControlExperiment(settings_file, 'raim_compare', 'raim_actions');
```

`settings_file` is an explicit saved settings MAT; it supplies observation, product and sidecar paths. `cold_start_ablation` toggles Reset and the combined cold-start/robust-code configuration (not independent attribution to its two subcomponents). `raim_actions` retains all other settings and runs none/exclude/downweight. Results are written to timestamped directories beneath `Path.RESULTS`; input files are not rewritten by this runner. Existing product-reader cache behavior still applies.

Historical dated scripts under `experiments/quality_control/legacy` are provenance, retain their original local paths, and are not the portable GUI execution path. Do not add that directory recursively when starting the application. The portable runner above replaces their use for new single-input/ablation/action runs. Historical searches involving retired algorithms require the pre-change source snapshot.

## Evidence boundary

GPS f2 was beneficial for the selected A761 600-epoch target, with a direction tradeoff. Cold start and prediction benefits are device dependent. K80 prediction improves RMS but can slightly worsen 3D P95. ACE5 cold start trades E/U RMS against P95. RAIM gains were small and device dependent. No switch should be enabled merely because it exists in the GUI. Coordinates used for historical scores have no independently verified uncertainty in this work.

## Parameter hover help

Main-window parameters (including six parameter tables and four dynamic BDS ISB controls) and all 39 advanced fields have hover help. Existing detailed help is retained; new help explains purpose, units, input format and dependencies where relevant. Advanced labels also carry the same explanation, including when their associated editor is disabled. Reopen the GUI to load updated help. Main-window coverage is 383 parameter/table controls; advanced coverage is 39.
