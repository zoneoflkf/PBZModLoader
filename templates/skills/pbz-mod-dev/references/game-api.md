# UE/PuerTS bridge notes

Use the MOD's own `vendor/game-api/README.md` and declarations for signatures and version-specific behavior.

- Native types use the `ue` module. For Blueprint types, use the exact reflected path in `UE.ReflectedTypes` or `UE.ReflectedClasses`; these type maps do not exist at runtime. To load a Blueprint class, pass the verified `_C` path to `UE.Class.Load`, check the result, and use `blueprint.tojs` when you need the JS type wrapper. This does not instantiate the class. For a native type use its declared `StaticClass()` where available.
- Use `GameplayStatics.GetPlayerPawn(gameInstance, 0)` and check the returned object. A TypeScript assertion does not cast a native object. Use `puerts.$ref` and `$unref` for native out parameters. Use native container methods like `Num()` and `Get()`; a UE container is not a JS array. Respect `bigint`, nullable returns, and `$Unresolved` markers in the SDK.
- For SDK versions that declare `UE.$FText`, pass the native result of `KismetTextLibrary.Conv_StringToText(label)` to `TextBlock.SetText()`. Read back with `Conv_TextToString(widget.GetText())`. If the value round-trips but is not visible, inspect font, color and layout. For Chinese labels, choose a font already seen rendering Chinese; a font used by a HUD counter may only contain digits. Confirm visible glyphs in the target game.
