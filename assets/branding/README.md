# LASTROOT branding (placeholders)

All of this is our own art. It was made from the procedural dioramas and the
project font (DejaVu Sans, see `assets/fonts/DejaVu_LICENSE.txt`). No vendor or
store assets were used.

**These are placeholders.** The final store art and splash must be redone with
real assets: a painted key art or a beauty render of the final models, plus a
designed logotype. Each image keeps the `_placeholder` name until then.

## Files

| File | Size | What it is | How it was made |
|---|---|---|---|
| `icon.svg` | 512x512 vector | App icon candidate: a turquoise heart inside a faceted tree crown, a trunk with roots, and a thin turquoise "last root" vein, on a deep night-blue rounded square | Hand-written SVG. Large flat shapes, so the heart and crown still read at 16 px |
| `icon_png/icon_{16,32,64,128,256,512}.png` | as named | Renders of `icon.svg` for checking readability (and as a source for a Windows `.ico` later) | `Image.load_svg_from_string` in the capture scene. The folder has `.gdignore`, so it is not imported or exported |
| `splash.png` | 1920x1080, ~300 KB | Boot splash: the menu diorama (tree, heart, both champions, Barkwarden highlighted) with the LASTROOT wordmark on the left | Rendered from `scenes/art/menu_diorama.tscn` with the camera shifted right (screen anchor 0.66, fov 40) |
| `store/header_capsule_460x215_placeholder.png` | 460x215 | Store header capsule | Menu diorama, rendered at 3x and downscaled (Lanczos), wordmark on the left |
| `store/small_capsule_231x87_placeholder.png` | 231x87 | Small capsule. The wordmark dominates, with a sliver of the tree on the right | Menu diorama at 4x, then downscaled |
| `store/main_capsule_616x353_placeholder.png` | 616x353 | Main capsule, with the Spore Sage highlighted | Menu diorama at 3x, then downscaled |
| `store/library_hero_1920x620_placeholder.png` | 1920x620 | Library hero. It has **no text**, as Steam requires: the logo is a separate overlay | Menu diorama, wide framing |
| `store/library_logo_1280x720_placeholder.png` | 1280x720, transparent | Library logo overlay (just the wordmark) | Wordmark only, on a transparent background |

`store/` has a `.gdignore`, so the store images never end up in the game build.

## Wordmark

"LASTROOT" is set in DejaVu Sans, emboldened, tracked out by 12%, with a dark
outline. A turquoise root line with a small heart-diamond sits under it. Behind
it is a soft dark radial pool, so it reads over the diorama. It is drawn by the
`Wordmark` control in `scenes/tests/branding_capture.gd`. This stands in until
a real logotype exists.

## Regenerate

```
tools/synty/capture_branding.sh
```

This needs `xvfb-run` and renders with gl_compatibility. If `splash.png` ever
grows past 1 MB, the script quantizes it with Pillow when python3 is available.
Frames, framing and wordmark rectangles are in the `shots` table at the top of
`scenes/tests/branding_capture.gd`.

## Project settings (applied by the coordinator, not in this folder)

```
config/icon="res://assets/branding/icon.svg"
boot_splash/show_image=true
boot_splash/image="res://assets/branding/splash.png"
boot_splash/fullsize=true
boot_splash/use_filter=true
```

`boot_splash/bg_color` stays at the existing night blue.
