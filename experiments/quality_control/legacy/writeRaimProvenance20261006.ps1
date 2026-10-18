# Run from the repository root after all PPP runs finish.
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path '.').Path
$resultRoot=Join-Path $projectRoot 'RESULTS/PPP_RAIM_ACTIONS_20261005'
$runList=Import-Csv -LiteralPath (Join-Path $resultRoot 'action_manifest.csv')
if ($runList.Count -ne 9) { throw 'Expected all nine completed variants.' }
$targets=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'CODE') -Filter '*.m' -Recurse -File | ForEach-Object { [void]$targets.Add($_.FullName) }
[void]$targets.Add((Join-Path $projectRoot 'WORK/Path.m'))
[void]$targets.Add((Join-Path $projectRoot 'DATA/COORDS/Coords.txt'))
[void]$targets.Add((Join-Path $projectRoot 'output/doc/RAIM_stage4_protocol_20261005.txt'))
foreach ($run in $runList) {
    $runDir=[IO.Path]::GetFullPath((Join-Path (Join-Path $projectRoot 'WORK') $run.output_dir))
    foreach ($name in @('settings.mat','settings_summary.txt','data4plot.mat','raim_epoch_summary.csv')) { [void]$targets.Add((Join-Path $runDir $name)) }
    foreach ($name in @($run.source_settings,$run.calibration_file)) { [void]$targets.Add([IO.Path]::GetFullPath((Join-Path (Join-Path $projectRoot 'WORK') $name))) }
    $obsLine=Get-Content -LiteralPath (Join-Path $runDir 'settings_summary.txt') | Where-Object { $_ -match '^  Obs-File: ' } | Select-Object -First 1
    if (-not $obsLine) { throw 'Missing observation path in saved settings.' }
    [void]$targets.Add($obsLine.Substring(12).Trim())
}
$records=foreach ($file in $targets) {
    $info=Get-Item -LiteralPath $file
    $hash=Get-FileHash -LiteralPath $file -Algorithm SHA256
    [PSCustomObject]@{path=$info.FullName;bytes=$info.Length;sha256=$hash.Hash}
}
$records | Sort-Object path | Export-Csv -LiteralPath (Join-Path $resultRoot 'reproduction_sha256.csv') -NoTypeInformation -Encoding utf8
Write-Output ('Hashed '+$records.Count+' source, input, configuration and evidence files.')
