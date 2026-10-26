# Runtime Resource

This Lazarus package previews project PNG files in the Windows form designer and loads the corresponding RCDATA resources from the executable at runtime. Preview images are not stored in `.lfm` files.

## Use

Install `RuntimeResource` from this repository in Lazarus and add it to your project's required packages so the form designer recognizes its components.

### Components

- `TRuntimeResourceImage` replaces `TImage`.
- `TRuntimeResourceBitBtn` replaces `TBitBtn`.
- `TRuntimeResourceSpeedButton` replaces `TSpeedButton`.

All three components use the same properties:

- `SourceFile`: A PNG path relative to the project directory containing the `.lpi` file. Used only in the form designer.
- `ResourceName`: The name of an RCDATA resource embedded in the executable. Used only at runtime.

For example, create `resource/images.rc` in your project with:

```rc
PAGE_ADD RCDATA "resource/page_add.png"
```

Add `{$R resource/images.rc}` to the project's `.lpr` file. Set the component's `SourceFile` to `resource/page_add.png` and `ResourceName` to `PAGE_ADD`. Do not assign an image directly to `Picture` or `Glyph`.

If the PNG is missing, the form designer shows no preview. Reopen the form to refresh a PNG changed outside Lazarus. If the RCDATA resource is missing or contains an invalid PNG, form creation fails at runtime.

## Build it yourself

Install Lazarus with Free Pascal and the Windows LCL widgetset. From this directory, run `lazbuild runtimeresource.lpk`, then open the package in Lazarus and use **Install** to register its design-time components. Use your normal Lazarus primary configuration. This package produces compiled units, not a standalone executable. `Taskfile.yml` builds application projects that depend on it but has no separate package task.

## For developers

`runtime_resource.pas` contains the three controls and loads PNGs from RCDATA at runtime. `register_runtime_resource.pas` registers them with the IDE and resolves design-time PNG paths relative to the active project. Keep `ResourceName` in `.lfm` aligned with names in the project's `.rc` file. Automated tests are not included in this package yet.
