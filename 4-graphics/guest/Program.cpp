// Program.cpp — a flashy OpenGL demo: glowing, interpenetrating torus knots
// spinning over a twinkling starfield, with additive "neon" glow and cycling
// hues.
//
// Windowing is raw GLX + Xlib, and rendering is legacy/immediate-mode GL, so it
// links against only the two host libraries you'd pass through (libGL, libX11) —
// no GLFW/GLUT/glad/glew needed.
//
// Built by hand (host side):
//
//   g++ Program.cpp -o Program -lGL -lX11 -lm
//   ./Program        # ESC or close the window to quit

#include <GL/glx.h>
#include <GL/gl.h>
#include <X11/Xlib.h>
#include <X11/keysym.h>

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <vector>

#ifndef M_PI
#  define M_PI 3.14159265358979323846
#endif

// ---------------------------------------------------------------------------

static double now_seconds() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static void hsv2rgb(float h, float s, float v, float &r, float &g, float &b) {
    h = (h - floorf(h)) * 6.0f;
    int i = (int) h;
    float f = h - i;
    float p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f));
    switch (i % 6) {
        case 0:  r = v; g = t; b = p; break;
        case 1:  r = q; g = v; b = p; break;
        case 2:  r = p; g = v; b = t; break;
        case 3:  r = p; g = q; b = v; break;
        case 4:  r = t; g = p; b = v; break;
        default: r = v; g = p; b = q; break;
    }
}

static void set_perspective(int w, int h) {
    glViewport(0, 0, w, h);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    double aspect = h ? (double) w / h : 1.0;
    double fov = 55.0 * M_PI / 180.0;
    double top = tan(fov * 0.5) * 0.1, right = top * aspect;
    glFrustum(-right, right, -top, top, 0.1, 100.0);
    glMatrixMode(GL_MODELVIEW);
}

// A (p, q) torus knot traced as a line strip. With additive blending the
// overlapping segments bloom into a glow; call it twice (wide+dim, thin+bright)
// for a neon core-and-halo look.
static void draw_knot(int p, int q, float scale, float hue, float t,
                      float width, float alpha) {
    const int N = 1600;
    glLineWidth(width);
    glBegin(GL_LINE_STRIP);
    for (int i = 0; i <= N; ++i) {
        float u = (float) i / N * 2.0f * (float) M_PI;
        float rr = cosf(q * u) + 2.2f;
        float x = rr * cosf(p * u);
        float y = rr * sinf(p * u);
        float z = -sinf(q * u);
        float cr, cg, cb;
        hsv2rgb(hue + 0.14f * sinf(u * 3.0f + t) + t * 0.04f, 0.85f, 1.0f, cr, cg, cb);
        glColor4f(cr, cg, cb, alpha);
        glVertex3f(x * scale, y * scale, z * scale);
    }
    glEnd();
}

struct Star {
    float x, y, z, phase;
};

int main() {
    Display *dpy = XOpenDisplay(nullptr);
    if (!dpy) {
        fprintf(stderr, "cannot open X display (is $DISPLAY set?)\n");
        return 1;
    }

    int attrs[] = {GLX_RGBA, GLX_DOUBLEBUFFER, GLX_RED_SIZE, 8, GLX_GREEN_SIZE, 8,
                   GLX_BLUE_SIZE, 8, None};
    XVisualInfo *vi = glXChooseVisual(dpy, DefaultScreen(dpy), attrs);
    if (!vi) {
        fprintf(stderr, "no suitable GLX visual\n");
        return 1;
    }

    Window root = RootWindow(dpy, vi->screen);
    XSetWindowAttributes swa;
    swa.colormap = XCreateColormap(dpy, root, vi->visual, AllocNone);
    swa.event_mask = ExposureMask | KeyPressMask | StructureNotifyMask;

    int width = 1280, height = 720;
    Window win = XCreateWindow(dpy, root, 0, 0, width, height, 0, vi->depth, InputOutput,
                               vi->visual, CWColormap | CWEventMask, &swa);
    XStoreName(dpy, win, "Pass-Through Graphics");
    XMapWindow(dpy, win);

    Atom wm_delete = XInternAtom(dpy, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(dpy, win, &wm_delete, 1);

    GLXContext ctx = glXCreateContext(dpy, vi, nullptr, GL_TRUE);
    glXMakeCurrent(dpy, win, ctx);

    set_perspective(width, height);

    // Additive "glow" blending; no depth test so layers accumulate brightness.
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_LINE_SMOOTH);
    glEnable(GL_POINT_SMOOTH);
    glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
    glHint(GL_POINT_SMOOTH_HINT, GL_NICEST);

    // A drifting starfield.
    std::vector<Star> stars;
    srand(1234);
    for (int i = 0; i < 600; ++i) {
        Star s;
        s.x = (rand() / (float) RAND_MAX - 0.5f) * 18.0f;
        s.y = (rand() / (float) RAND_MAX - 0.5f) * 18.0f;
        s.z = (rand() / (float) RAND_MAX - 0.5f) * 18.0f;
        s.phase = rand() / (float) RAND_MAX * 6.28f;
        stars.push_back(s);
    }

    struct KnotDef {
        int p, q;
        float scale, hue, spinX, spinY;
    };
    const KnotDef knots[] = {
        {3, 2, 0.95f, 0.00f, 17.0f, 23.0f},
        {2, 3, 0.80f, 0.33f, -21.0f, 13.0f},
        {5, 3, 0.68f, 0.66f, 11.0f, -29.0f},
    };

    double t0 = now_seconds();
    bool running = true;
    while (running) {
        while (XPending(dpy)) {
            XEvent ev;
            XNextEvent(dpy, &ev);
            if (ev.type == ConfigureNotify) {
                width = ev.xconfigure.width;
                height = ev.xconfigure.height;
                set_perspective(width, height);
            } else if (ev.type == KeyPress) {
                if (XLookupKeysym(&ev.xkey, 0) == XK_Escape) {
                    running = false;
                }
            } else if (ev.type == ClientMessage) {
                if ((Atom) ev.xclient.data.l[0] == wm_delete) {
                    running = false;
                }
            }
        }

        float t = (float) (now_seconds() - t0);

        glClearColor(0.02f, 0.02f, 0.05f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        float camDist = 7.0f + 1.5f * sinf(t * 0.3f);
        glLoadIdentity();
        glTranslatef(0.0f, 0.0f, -camDist);

        // Starfield, gently rotating on its own.
        glPushMatrix();
        glRotatef(t * 3.0f, 0.2f, 1.0f, 0.0f);
        glPointSize(2.0f);
        glBegin(GL_POINTS);
        for (const Star &s : stars) {
            float tw = 0.35f + 0.35f * sinf(t * 2.0f + s.phase);
            glColor4f(0.6f * tw, 0.7f * tw, 1.0f * tw, tw);
            glVertex3f(s.x, s.y, s.z);
        }
        glEnd();
        glPopMatrix();

        // Three knots, each with its own spin.
        for (const KnotDef &k : knots) {
            glPushMatrix();
            glRotatef(t * k.spinX, 1.0f, 0.4f, 0.0f);
            glRotatef(t * k.spinY, 0.0f, 1.0f, 0.2f);
            draw_knot(k.p, k.q, k.scale, k.hue, t, 7.0f, 0.18f); // halo
            draw_knot(k.p, k.q, k.scale, k.hue, t, 2.0f, 0.65f); // core
            glPopMatrix();
        }

        glXSwapBuffers(dpy, win);
    }

    glXMakeCurrent(dpy, None, nullptr);
    glXDestroyContext(dpy, ctx);
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);
    return 0;
}
