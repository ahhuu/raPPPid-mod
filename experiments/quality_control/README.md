# Quality-control experiment provenance

`legacy/` contains the 16 selected original calibration, comparison, audit and regression scripts. Their dated dataset paths are deliberately preserved so the original protocol is not silently rewritten. They are not production dependencies and are not automatically added to MATLAB's path.

For new runs, use `CODE/OTHERS/runQualityControlExperiment.m`, which accepts an explicit settings MAT, output name and mode. Read `docs/QUALITY_CONTROL_GUI.md` for GUI controls and migration boundaries. Train/freeze RAIM calibration separately, then load its MAT through the GUI. Do not copy a calibration between devices without validation.

Historical negative-result reports are retained under `docs/experiments/`. They describe their dated code/configuration, not blanket guarantees about the final GUI release. Some early statements were superseded by later quality-gated prediction experiments.

Large input/results and the original source snapshot remain local and are not committed. The pre-GUI snapshot for this workspace is under `tmp/gui_release_20261018/`; it includes all MATLAB source/FIG files and a SHA256 manifest. No old result directories were removed.
