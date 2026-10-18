# Ground Track Simulations

```
inputs/        Data budget (PDF), link budget (xlsx), ISS TLE + Heavens-Above passes for verification
simulations/   Python scripts (TudatPy, env: tudat-space)
  Ground_track_utilities.py   propagation, elevation, pass extraction
  Ground_track.py             single short run, saves CSV to output/
  Ground_track_calendar.py    passes / contact time per day, calendar plots
  pass_statistics.py          1-year run -> pass duration distribution + data volumes
  test_passes.py              self-check of the pass extraction
  verify_passes.py            verification vs Heavens-Above (ISS), SGP4 and analytic bound (needs skyfield)
output/        Generated results (results.json, figures, CSV)
report/        Typst report (TU Delft / DVS template)
reference/     Reference report the template was taken from
```

## Usage

```bash
conda activate tudat-space
cd simulations
python test_passes.py          # quick check
python pass_statistics.py      # ~5 min, writes output/results.json and figures
python verify_passes.py        # ~15 s, writes output/verification.json and figures
cd ..
typst compile --root . report/main.typ report/Contact_Time_Data_Volume.pdf
```

Link-budget data rates, data-budget frame sizes, elevation mask and minimum pass duration are set at the top of
`pass_statistics.py`. The propagation is cached in `output/elevation_history.npz`; delete it after changing the
orbit, spacecraft or ground station, otherwise re-runs only redo the statistics (seconds).
