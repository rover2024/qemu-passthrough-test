## `4-graphics` - Two libraries and a live GUI

Layer 4 does **two libraries at once — and a live, interactive window**: a small OpenGL program whose Xlib *and* OpenGL/GLX calls all run on the host.

[`Program.cpp`](4-graphics/guest/Program.cpp) is a self-contained GLX + immediate-mode GL demo — glowing, spinning torus knots over a starfield. It opens a window with Xlib and draws with OpenGL, but it is built against **drop-in `libX11.so` and `libGL.so`**, so every `XCreateWindow`, `glBegin`, `glXSwapBuffers`, … is forwarded to the host's real Xlib/OpenGL and rendered on the host display.

<!-- The same [`GenerateSource.py`](4-graphics/GenerateSource.py) produces **both** thunk pairs — one per `*Symbols.conf` — and reuses the `2-callback` runtime unchanged. Every function the program uses is **pure data pass-through** (no callbacks, no varargs), so this layer is mechanically the simplest: the generator emits one stub and one adapter per symbol, nothing more. -->

<!-- What lets an unmodified windowing toolkit survive this is the shared address space:

* Xlib's **macros** (`DefaultScreen`, `RootWindow`) and **struct fields** (`XVisualInfo`, `XEvent`) are read by the guest straight out of the host-owned structs — there is no symbol to thunk.
* **Opaque host handles** — a `Display *`, an `XVisualInfo *`, a `GLXContext` — flow between the `libX11` and `libGL` thunks as plain values the guest never dereferences. -->

## Build and Run

To run this demo, an available display is required.

```sh
./build.sh
./run.sh
```

You should see a window with a spinning torus knot over a starfield.