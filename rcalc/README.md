# RCalc

RCalc solves a proportion of the form `X : Y = A : B`, calculating `B = Y / X × A`.

## Use

Enter nonzero values for **X**, **Y**, and **A**, then click **Calculate**. The result appears in **B** and in the result text. Calculations are added to the list without duplicates. Double-click an earlier result to load its **X**, **Y**, and **A** values again. Zero in any input produces an error instead of a ratio.

You can prefill the three inputs on launch:

```powershell
rcalc.exe 2 3 4
```

Arguments are `X Y A` in that order; missing or invalid numbers default to zero. Decimal parsing follows the system locale.

## Build it yourself

Install Lazarus with Free Pascal and the Windows LCL widgetset. Register this repository's [`DarkTheme`](../package/dark-theme/README.md) package in Lazarus. From this directory, run:

```powershell
lazbuild --build-mode=Default rcalc.lpi
```

The executable is `rcalc.exe` in this directory. The repository's `task build:rcalc` builds it and moves it to `.dist/rcalc.exe`; adjust the Taskfile's local tool paths before using that task.

## For developers

`rcalc.lpr` parses the three optional arguments. `ui/main.pas` owns the proportion calculation, result history, and number formatting; `ui/main.lfm` defines the controls. The form's `TFloatSpinEdit` interposer removes trailing zeroes while retaining input precision. If the displayed result format changes, keep `TryReadResult` in sync because double-clicking a history item parses that text.
