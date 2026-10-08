# Pixel perfect view

Scales pixel art to any screen by a whole number, so every art pixel is an exact square of
screen pixels. You choose a world area that must always be visible. The view picks the largest
whole-number scale that still fits it, grows the game area to cover the window, and lets the
part that doesn't divide evenly fall off the screen edges. There are no black bars and no
blurry in-between scales.

## Files

| File | Class | Role |
|---|---|---|
| `pixel_perfect_view.gd` | `PixelPerfectView` (SubViewportContainer) | Picks the scale, sizes the game to cover the window, sets the camera zoom |
| `pixel_perfect_camera_2d.gd` | `PixelPerfectCamera2D` (Camera2D) | Smooth follow camera that snaps to whole pixels |
| `example/example.tscn` | — | The terrain test stage inside a view. Run it with ⌘R |
| `example/glide_example.tscn` | — | A square on a grid with a glide layer. Space turns the glide on and off to compare |

## Setup

Scene tree (see `example/example.tscn`, or `stages/main/main.tscn` for the real game):

    Control (full rect, mouse_filter = Ignore)      ← optional; put sharp UI here
    └── View        SubViewportContainer + pixel_perfect_view.gd
        └── Game    SubViewport
            └── World
                ├── Player
                └── Camera   Camera2D + pixel_perfect_camera_2d.gd (target = Player)

- The SubViewport must be the **only child** of the View, and the whole world goes *inside*
  it. A node placed next to the SubViewport is drawn straight to the window, and the view
  can't find its camera.
- Set the View's layout to Position, with no anchors. Its size, position and `stretch_shrink`
  are set by the script.
- On the SubViewport:
  - **Snap 2D Transforms/Vertices to Pixel:** on
  - **Default Texture Filter:** Nearest
  - **Handle Input Locally:** off
  - **Update Mode:** Always
- Project settings, under **Display → Window**:
  - **Stretch → Mode:** `disabled`. The View does the scaling, and engine stretching on top
    of it would scale the image twice.
  - **DPI → Allow hiDPI:** see [Retina screens](#retina-screens).

## `PixelPerfectView`

| Export | Default | Meaning |
|---|---|---|
| `target_size` | `800 × 600` | World area, in art pixels, that is always visible. Wider or taller screens show more |
| `zoom_camera` | `true` | Where the scale goes. See below |
| `glide_view` | — | Optional second view drawn on top that shows the camera target gliding. See [Gliding target](#gliding-target) |

| Property | Meaning |
|---|---|
| `pixel_scale` | Screen pixels per art pixel. Read-only, updated on every resize |
| `subpixel_offset` | Set by `PixelPerfectCamera2D` when `zoom_camera` is off |

How it fits the window (`_fit`, re-run on every resize):
1. `pixel_scale = floor(min(window.x / target.x, window.y / target.y))`, at least 1.
2. The game size is `ceil(window / scale)`, rounded up to even so a centred camera lands on a
   whole pixel. With `zoom_camera` off, there is also one spare art pixel on each side.
3. The container is centred, and whatever doesn't fit falls off the screen edges.
4. The SubViewport's current Camera2D gets its zoom set. Any zoom you set in the editor is
   overwritten.

### `zoom_camera`

Both modes look the same when nothing moves. They differ in how motion lands on the grid.

| | `true` | `false` |
|---|---|---|
| Renders at | Window resolution | Art resolution (cheaper) |
| Scale applied by | `camera.zoom = pixel_scale` | `stretch_shrink = pixel_scale`, `camera.zoom = 1` |
| Camera and sprites move in | Screen pixels (1/scale of an art pixel) | Whole art pixels. The camera's sub-pixel is hidden by shifting the image |
| Rotated or scaled sprites | Drawn at screen resolution, so finer than the art | Stay on the art grid |

Use `false` for a strict pixel grid and `true` for silkier motion.

## `PixelPerfectCamera2D`

| Export | Default | Meaning |
|---|---|---|
| `target` | — | Node2D to follow |
| `follow_speed` | `5.0` | How fast it catches up. Higher is snappier (frame-rate independent) |

Every frame it eases an unsnapped position toward the target, then places itself on the
nearest game pixel, so the world never jitters against itself. With `zoom_camera` off, it also
hands the leftover to the view as `subpixel_offset`, and the view shifts the scaled-up image
by `offset × scale` screen pixels. Motion looks smooth while the art stays on the grid.

If you swap cameras at runtime, the view sets zoom only on start and on resize. Set the new
camera's zoom to `Vector2.ONE * view.pixel_scale` when `zoom_camera` is on, or `Vector2.ONE`
when it is off.

## Gliding target

With `zoom_camera` off, every node moves one whole art pixel at a time. The camera hides its
own sub-pixel by shifting the image, so the world glides, but the target it follows then
wobbles on screen by up to one art pixel. A glide view fixes this for the target. It draws the
target on a second art-resolution layer on top of the game, and shifts that layer by the part
of the target's position that rounding removed. Art pixels stay exact squares, and the world
keeps its strict grid. Only the target leaves the grid.

Scene tree (see `example/glide_example.tscn`, or `stages/main/main.tscn` for the real game):

    Control
    ├── View        SubViewportContainer + pixel_perfect_view.gd (glide_view = GlideView)
    │   └── Game    SubViewport, canvas_cull_mask = every layer except 2
    │       └── World                visibility_layer = 1 + 2
    │           ├── Terrain          visibility_layer = 1
    │           └── Player           visibility_layer = 2, and its children too
    │               └── Camera       Camera2D + pixel_perfect_camera_2d.gd (target = Player)
    └── GlideView   SubViewportContainer + pixel_perfect_view.gd, after View
        └── Glide   SubViewport, same settings as Game, plus transparent_bg and canvas_cull_mask = 2

- `View` copies `target_size` and `zoom_camera` to the glide view, and gives `Glide` the same
  world, so set them on `View` only. The camera copies its canvas transform to `Glide` every
  frame.
- Layer 2 rules. A node is skipped along with all its children when its layer isn't in the
  cull mask, so:
  - the target and all its children go on layer 2 only;
  - every parent of the target goes on layers 1 and 2;
  - Game's cull mask leaves out layer 2.
- Put only the camera target on layer 2. Anything else there glides by the target's sub-pixel,
  not its own.
- The target's parent must sit on a whole pixel.
- Move the target in `_process`, and set its **Physics Interpolation Mode** to Off. The shift
  needs the exact position that gets drawn, and with physics interpolation the renderer
  computes that where scripts can't read it.
- `GlideView` needs a `CanvasItemMaterial` with **Blend Mode** set to Premultiplied Alpha. A
  transparent viewport stores premultiplied colour, so normal blending draws overlaps and
  soft edges too dark.
- Lights and `CanvasModulate` ignore the cull mask, so the target is lit and tinted as before.
- The glide layer always draws on top of the world. The target can't pass behind anything.
- At rest, the target can sit between art pixels, off the world's grid. To line it up again,
  ease it onto `position.round()` when it stops (see `Vtol.settle_below_speed`). The camera
  follows it there, so both layers end with no shift.

## Choosing `target_size`

`target_size` is a minimum, and **both axes count**. A 4:3 target on a 16:9 screen is limited
by the height:

| Target | Studio Display, 5120×2880 physical pixels | Scale |
|---|---|---|
| 800×600 | min(6.4, **4.8**) | 4 |
| 800×450 | min(6.4, 6.4) | 6 (854×480 game, 2 px cropped) |

Match the target to the screen shape you care about most (16:9, 16:10) and you'll lose less
scale.

To hit a specific scale on specific screens, work backwards. For example, 3× on a Studio
Display (2560×1440 points) and 2× on a MacBook (about 1512×982 points) needs a target width
between 641 and 756. This project uses **720×400**.

With the window maximized rather than fullscreen, the title bar takes some height, so keep a
little headroom on the height. To check, look at `View.pixel_scale` in the remote scene tree
while the game runs.

## Retina screens

With **Allow hiDPI** off, macOS gives Godot the window in points (2560×1440 on a Studio
Display) and doubles it itself. On exact 2× screens that is still pixel-perfect, and
`pixel_scale` counts points, so 3× means 6×6 physical pixels per art pixel.

On a MacBook running a "scaled" resolution that isn't exactly half the panel, macOS resamples
the image and nothing in Godot can make it sharp. Use the screen's default (2×) resolution.

If you turn hiDPI on, Godot renders at physical pixels. Double `target_size` to keep the same
framing. With `zoom_camera` on, that also costs four times the fill rate.

## Tips

- **UI:** put pixel-art UI inside the SubViewport (on a CanvasLayer) so it gets the same
  scale. Put sharp, native-resolution UI (debug text, menus) next to the View, under the root
  Control.
- **Steppy motion:** if the target moves in `_physics_process` while the camera updates every
  frame, turn on **Physics → Common → Physics Interpolation** in the project settings.
- **Things that follow the camera** (for example `InfiniteLayeredTerrain.follow`) should point
  at the camera node. It sits at the snapped position, which is what's on screen.
