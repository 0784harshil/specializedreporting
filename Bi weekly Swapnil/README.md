# Bi-Weekly Employee Hours Report (Swapnil)

Employee **hours only** (Time_Clock). No sales sections.

## Half-month periods (auto)

| Half | Days |
|------|------|
| 1 | 1st – 15th |
| 2 | 16th – last day of month (28 / 29 / 30 / 31 detected automatically) |

Default run uses the **most recently completed** half (`REPORT_PERIOD_MODE=previous`).

## Run

```
BiWeeklyEmployeeReport.exe
BiWeeklyEmployeeReport.exe --dry-run
BiWeeklyEmployeeReport.exe --half 1 --month 2026-07
BiWeeklyEmployeeReport.exe --half 2 --month 2026-07
BiWeeklyEmployeeReport.exe --start 2026-07-01 --end 2026-07-15
BiWeeklyEmployeeReport.exe --store 1001
```

Edit `config.env` next to the exe for SQL / email settings.

Reports are saved under `biweekly_reports\YYYY-MM-DD_to_YYYY-MM-DD\<Store_ID>\`.
