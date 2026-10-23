# Runtime Resource

This Lazarus package previews project PNG files in the Windows form designer and loads the corresponding RCDATA resources from the executable at runtime. Preview images are not stored in `.lfm` files.

## Components

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

## Build

```powershell
E:\lazarus\lazbuild.exe runtimeresource.lpk
```

Install `RuntimeResource` from this repository in Lazarus. Add it to each project's required packages so the form designer can recognize the component classes.

Automated tests are not included in this package yet.
