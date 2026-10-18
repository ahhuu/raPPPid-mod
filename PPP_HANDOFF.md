# Predicted-phase PPP input contract

The prediction path is integrated in PPP and can be enabled from the main GUI's **Advanced quality control** menu. See [GUI instructions](docs/QUALITY_CONTROL_GUI.md). The older statement that PPP integration was not implemented is superseded.

## Required inputs

- An observation RINEX already containing predicted phase values.
- Matching prediction metadata CSV with `time,sat_id,freq,prediction_length,sigma_m,accepted` (plus the reader's `source,status` fields).
- A quality RMS CSV with `satellite,frequency,prediction_length,sample_count,rms_m` when quality gating is enabled.

Time is matched using GPS week/time, satellite and signal, with an explicit tolerance. `sigma_m` is a standard deviation in metres; its squared value is propagated through the PPP covariance construction. Do not flip the Doppler sign again or repeat the external multipath correction.

Prediction length, quality RMS and sample thresholds determine eligibility. Predictions already written in RINEX but rejected by these gates are withheld from phase processing. Accepted predictions receive their explicit variance. Current/previous predicted phase is excluded from non-LLI cycle-slip confirmation; real RINEX LLI is retained.

The GUI does not generate predictions or pseudorange corrections. It consumes external files, validates their required columns and checks session overlap. Metadata time/signal mapping does not independently certify the external prediction algorithm or its coordinate accuracy.

## Use and reproduction

Use single-file GUI processing, select prediction and quality CSVs, configure the gate, apply, then run. Save full settings to retain input bindings. Generic parameter templates intentionally clear prediction file bindings.

For scripting, use `runQualityControlExperiment(settings_file, output_name, 'single')` from `WORK`. Preserve original/modified RINEX, metadata, saved settings and complete-epoch outputs for comparisons.

The historical evidence supports device-specific decisions: K80 quality-gated prediction plus external multipath correction improved RMS, while its P95 remained slightly worse than multipath-only. X6 and ACE5 prediction was not selected as the production baseline. Do not equate increased phase completeness with validated PPP improvement.
