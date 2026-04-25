# Netflix PS4 NRDP Environment by MexrlDev Findings..
* You are free to use these the way you like, study them, learn from them, and develop using them.

This document is a comprehensive guide to the Netflix Rich Development Platform (NRDP) as it exists inside the PlayStation 4 Netflix application.  It synthesizes information from three primary sources—the raw test scripts, the built‑in error page framework, and the official test automation library to explain every aspect of the environment, from the lowest‑level widget API to the highest‑level UI framework and playback automation.

---

1. Introduction

The PS4 Netflix app is not a traditional web browser; it runs a custom JavaScript runtime built on V8 (similar to Chrome ~80).  There is no DOM, no document, and no window in the browser sense.  All graphics, input, and networking are exposed through the nrdp global object and its sub‑modules, chiefly nrdp.gibbon (the rendering engine) and nrdp.media / nrdp.mediasourceplayerfactory (for media playback).

Netflix’s own UI and certification tests are written entirely against this platform.  By understanding the APIs revealed in the supplied code, it is possible to build full‑fledged games, streaming players, diagnostic tools, and more—all inside the Netflix app.

---

2. The Global Environment

2.1 JavaScript Runtime

· Engine: V8 (ES5 plus some ES6 features: let, const, arrow functions, promises, Map, Set, typed arrays, BigInt).
· No browser APIs: There is no window, document, or XMLHttpRequest by default (polyfills are provided in the error page and test library).
· Timers: nrdp.gibbon.setTimeout(callback, ms, isOneShot), nrdp.gibbon.clearTimeout(id).  These are the only timer functions; setInterval is implemented by recursively calling setTimeout.
· Logging: nrdp.log.debug(), nrdp.log.info(), nrdp.log.warn(), nrdp.log.error(), nrdp.log.fatal().  The logging system is extremely capable, supporting trace areas, sinks, and flush.

2.2 The nrdp Global Object

Key sub‑objects:

Module Purpose
nrdp.gibbon Rendering system – widgets, scene, image loading
nrdp.media / nrdp.mediasourceplayerfactory Media playback
nrdp.device Device info (ESN, model, SDK version, capabilities)
nrdp.storage Persistent key‑value storage (per device account)
nrdp.registration Account registration / activation
nrdp.PlayerControl High‑level playback controller (requires nrdjs)
nrdp.audio Audio output (loading, playing, volume)
nrdp.network Network diagnostics, interface list
nrdp.instrumentation Event instrumentation for profiling / FPS
nrdp.drmsystem DRM (PlayReady / Widevine)
nrdp.SDKVersion Device SDK version info

The runtime also defines nrdjs (the media JS layer) when loaded.

---

3. Core NRDP / Gibbon Primitives

3.1 Widgets – nrdp.gibbon.makeWidget()

All visual elements are widgets created with makeWidget().  A widget is a rectangular layer with position, size, colour, text, images, and a hierarchy via parent.

```js
var w = nrdp.gibbon.makeWidget();  // or makeWidget({x:10, y:20, width:100, height:50})
w.x = 100;
w.y = 200;
w.width = 300;
w.height = 50;
w.color = { r: 255, g: 0, b: 0, a: 255 };  // background
w.text = "Hello";
w.textStyle = { size: 24, color: { r: 255, g: 255, b: 255 }, wrap: true };
w.parent = someParentWidget;  // add to another widget
```

Important Widget Properties

Property Type Description
x, y number Position (top‑left corner)
width, height number Size (pixels)
color {r,g,b,a} Background colour (alpha 0‑255)
text string Display text
textStyle object Text formatting (see below)
image object Foreground image (scale, align, sourceRect)
background object Background image (same structure)
parent widget Parent widget (or undefined for a top‑level widget)
visible boolean Show/hide
opacity number 0‑1
scale number Scale factor (affects size and position)
drawOrder number Stacking order
mirror boolean Mirror horizontally (for RTL languages)
clip boolean Clip children to this widget’s bounds
cache boolean Cache widget as a surface (performance)
hidden boolean Alias for !visible
name string Optional identifier
id string Optional identifier (used in the higher‑level framework)
rect object Set all position/size at once: {x, y, width, height}
padding object Inner padding: {left, top, right, bottom, wrap}
layout object Layout properties (see below)
children array Read‑only list of child widgets
scrollX / scrollY number Scroll offset (crops children)

Text Style (set via w.textStyle or as an object in w.text if using the framework) can include:

Property Description
size Font size (pt)
align e.g. "left", "center", "right", "bottom", "center-horizontal", "center-both"
color {r,g,b,a}
wrap Boolean, enable word wrapping
bold Boolean
italic Boolean
underline Boolean
strikethrough Boolean
lineHeight Number (e.g. 24)
maxLines Maximum visible lines
truncation {position:"end", ellipsis:"…"}
shadow {offsetX, offsetY, color:{r,g,b,a}}
edgeEffect {type:"outline", width:1, outlineColor, lightColor, darkColor}
richText Boolean, enables span‑based formatting
cursor {visible, position, interval, style, width, color}
locale BCP‑47 language tag

Image Handling
The image (foreground) and backgroundImage properties can be a string URL, but more commonly an object:

```js
w.image = {
    url: "http://example.com/image.png",  // or { url: "...", lazy: true, async: true }
    halign: "left",   // "left","center","right","stretch","tile","tile right","stretch aspect"
    valign: "top",    // similar
    sourceRect: { x:0, y:0, width:50, height:50 }  // crop
};
```

Image data can come from URLs (http/https) or data URIs.

Layout
Widgets support a simple layout system for children.  Set layout on the parent:

· layout: "vertical" – children stacked vertically.
· layout: "horizontal" – children stacked horizontally.
· layout: "flow" – flow layout like text (line wrapping).
· layout: "stack" – overlapping (usually just positions manually).

Layout can also accept alignment options, e.g.:

```js
w.layout = { layout: "horizontal", align: ["left", "center"] };
```

Children can use stretch to fill available space:

```js
child.layoutStretch = 0.5;  // relative weight
```

3.2 The Scene

The display is represented by the scene widget:

```js
nrdp.gibbon.scene.widget = myRootWidget;   // set the root widget
var w = nrdp.gibbon.scene.width;           // read scene dimensions (usually 1920×1080 on PS4)
var h = nrdp.gibbon.scene.height;
```

To remove the current scene, set scene.widget = undefined.  Overlays (like the error screen) use nrdp.gibbon.scene.overlay.

3.3 Input Handling

Input is received via key events on nrdp.gibbon:

```js
nrdp.gibbon.addEventListener('key', function(event) {
    // event.data: { code, type ("press"/"release"), uiEvent, text, repeat, modifiers, ... }
    if (event.data.type !== 'press') return;
    var ui = event.data.uiEvent;   // e.g. "key.up", "key.enter"
    switch (ui) {
        case 'key.up':    // move up
        case 'key.down':  // move down
        case 'key.left':  // move left
        case 'key.right': // move right
        case 'key.enter': // Cross (X)
        case 'key.back':  // Circle (O)
    }
});
```

Known uiEvent mappings for PS4:

Button uiEvent string
D‑pad Up "key.up"
D‑pad Down "key.down"
D‑pad Left "key.left"
D‑pad Right "key.right"
Cross (X) "key.enter"
Circle (O) "key.back"
Triangle "key.context_sensitive_2" (likely)
Square "key.context_sensitive_1" (likely)
L1 "key.l1"
R1 "key.r1"
L2 "key.l2"
R2 "key.r2"
Options "key.options" (or "key.context_sensitive_1")

The numeric data.code is also present but uiEvent is the recommended identifier.

Key repeat: event.data.repeat is true for held keys.  Rapid key detection is handled by custom logic in the tests (see util.KeyHistory).

Simulating input can be done via the developer console:

```js
nrdp.gibbon._runConsole('/key right 1 1000');
```

3.4 Timers

```js
var timer = nrdp.gibbon.setTimeout(function() { ... }, 500, true);  // one-shot
var interval = nrdp.gibbon.setTimeout(function() { return 200; }, 200, false);  // repeating
nrdp.gibbon.clearTimeout(timer);
```

3.5 Loading External Scripts

```js
nrdp.gibbon.loadScript({ url: "http://server/script.js", async: false }, function(result) {
    // result.data contains the script text if successful
    eval(result.data);
});
```

The load function can fetch arbitrary data:

```js
nrdp.gibbon.load({
    url: "http://server/data.json",
    requestMethod: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({...}),
    secure: true,
    format: "string"
}, function(result) {
    // result.data, result.statusCode, result.reason
});
```

3.6 Logging & Debugging

```js
nrdp.log.debug("message", "TRACE_AREA");
nrdp.log.error("error");
nrdp.log.success("success");  // green text in telnet
```

Logs can be filtered by area, level, and captured via nrdp.log.addSink(area:level, callback).

---

4. The High‑Level UI Framework (error.js)

The error.js file contains a complete, production‑ready UI framework that Netflix builds on top of the raw gibbon API.  It’s used by the built‑in error page, customer service screens, dialogs, and the main browse experience.  This framework is not strictly required to create custom applications, but it provides an immense amount of infrastructure that can be reused to dramatically accelerate development.

4.1 The gibbon Wrapper Object

At the top of error.js, a global gibbon object is created that wraps nrdp.gibbon and adds:

· gibbon.makeWidget – an alias.
· gibbon.setScene(widget) – sets nrdp.gibbon.scene.widget.
· gibbon.scene.width / height – read‑only.
· gibbon.color – a colour class with string parsing ("#RRGGBB", "rgb(r,g,b)").
· gibbon.rect – a rectangle class with x, y, width, height, left, top, right, bottom, intersect, unite, etc.
· gibbon.defaultTextStyle() – a default text style object with merge support.
· gibbon.Widget – the core class of the framework (see below).
· gibbon.parseMarkup / createWidgets – creates a widget tree from a JSON‑like object.
· gibbon.style – a CSS‑like stylesheet system (classes and selectors).
· gibbon.layout – a layout engine (vertical, horizontal, flow, grid, etc.).
· gibbon.getElementById(id) – find a widget by its id property.

4.2 gibbon.Widget – The Framework Widget

gibbon.Widget is not the raw NRDP widget, but a wrapper that provides a higher‑level API:

· Each gibbon.Widget has an underlying _proxy (the actual nrdp.gibbon widget).
· Properties are defined with getters/setters that mirror the proxy, but also support reactive styles, transitions, and layout.
· Children are managed via an internal _children array.
· The widget supports setProperties(markup) to apply multiple properties at once.
· There is a style system: widget.style holds a style object, and widget.className can be set to apply CSS‑like class rules.
· Layout is handled by a _layout property that can be set to a layout engine instance.

Key Properties

Same as the raw widget but with additional ones:

· rect – get/set all position/size at once.
· right, bottom – settable via widget.right = 50 (distance from parent’s right edge).
· drawOrder, opacity, scale, hidden, clip, cache, mirror.
· transformOriginX/Y – animation pivot.
· display – special flags.
· textStyle – as above, plus can be set via widget.text.style.size, etc. (using the p / text sub‑object in the framework).
· image – foreground image (wrapped).
· backgroundImage – background image.
· padding, margin – for layout.
· children – array of child widgets.
· parent – getter/setter that reparents in the tree and on the proxy.
· cloneNode(deep) – clone the widget.
· getElementById, getElementsByClassName – search the subtree.

Text system: The text property in the framework is actually an object with its own sub‑properties (size, color, etc.) that eventually translates to the proxy’s text string and textStyle.  Renderers specify these as sub‑objects.

4.3 The Renderer System (view2)

The framework includes a renderer abstraction that bridges declarative markup and the raw widget tree.  Renderers are classes that produce a gibbon.Widget on demand and then apply properties via a set/reset/commit cycle, efficiently batching changes.

view2.ARenderer (base class):

· render() → returns a gibbon.Widget.
· element getter caches the rendered widget.
· set(properties) – marks properties for update.
· reset() – restores default values.
· commit() – applies batched sets and resets to the underlying widget(s).

Renderer types:

· view2.ContainerRenderer – a coloured box; supports cache, clip, layout, padding, background image, border, and can contain children.
· view2.TextRenderer – text with alignment, colour, truncation, shadow, edge effect.
· view2.ImageRenderer – image with source, alignment, aspect ratio.
· view2.controls.ButtonRenderer – buttons (with state changes).
· view2.controls.CollectionRenderer – a container that helps with collection views.
· view2.dialog.DialogRenderer – the dialog background.
· view2.customerservice.CustomerServiceRenderer – the customer service screen background.

Each renderer’s template is a JSON tree that is passed to gibbon.parseMarkup to create the initial widget structure.

4.4 View Classes (view2)

Views are higher‑level objects that own a renderer and provide interaction:

· view2.AView – base class: manages position, size, opacity, transforms, transitions, and a list of children.  Has methods like show(), hide(), focus(), blur(), destroy(), addChild(), removeChild().
· view2.Container – a simple box.
· view2.Text – a text label.
· view2.Image – an image.
· view2.controls.Button – a button with states (default, highlighted, pressed, disabled, selected) and callbacks.
· view2.controls.Collection / ScrollableCollection – a container that positions children using a layout engine (stack, grid, engine) and supports data‑source updates, focusing, key navigation, and scrolling transitions.
· view2.dialog.DialogView – a modal dialog with title, subtitle, code, and a button collection.
· view2.customerservice.CustomerServiceView – the entire customer service menu (network info, device info, sign‑out, etc.).

These views are designed to be used with the binding system (see section 6) to retrieve their dependencies.

4.5 Layout Engines

The view2.controls.layout namespace provides three engines for positioning child views:

· Stack – arranges children along an axis ("x" or "y") with a given spacing and wrapping.
· Engine – similar to Stack but tracks positions in a flat object; used in collections.
· Grid – two‑dimensional grid layout; supports crosshair‑based virtual navigation and wrap behavior.

These engines are used by ScrollableCollection to position its items.

4.6 Data‑Driven Collections

ScrollableCollection binds to an observable data source (e.g., an array or a Falcor path evaluator).  It automatically creates, reuses, and updates child views as the visible range changes.  It supports:

· Smooth scrolling (translate animations).
· Key‑based focus navigation (using the layout engine to find the nearest item in a direction).
· Placeholder items.
· View recycling.

This is how Netflix’s video lists work.

4.7 The Stylesheet System

gibbon.style provides a CSS‑like class system on top of the widget tree:

· A style sheet contains entries for class selectors (e.g., ".foo") and optionally parent selectors (e.g., ".bar>.foo").
· When a widget’s className is set, the style sheet computes the merged effective style, and the widget’s onStyleChange method applies the properties directly to the widget.
· Styles can include all standard properties, including transition definitions, which cause smooth animated changes when a class is swapped.

Example from the code:

```js
gibbon.style.addStyleSheet({
    ".myclass": { color: "#ff0000", textStyle: { size: 24 } },
    ".parent>.child": { color: "#00ff00" }
});
widget.className = "myclass";
```

4.8 Transitions & Animation

Widgets support CSS‑like transitions via the transition property:

```js
widget.transition = { property: "x", duration: 500, ease: "ease-in-out" };
```

Setting a property will animate from the current value to the new value over the given duration.  Multiple transitions can be set simultaneously (e.g., for x, y, opacity, scale).  The raw NRDP animation is used under the hood.

4.9 State Machine & Navigation

state is a hierarchical state stack system used to manage the application flow:

· state.RootState – the root of the state tree.
· state.StateStack – a stack of states; the topmost handles events and can push/pop substates (like entering a dialog or a card).
· state.ICompoundState / ACompoundState – a state that can have a current active sub‑state.

Events (like key presses or commands) are raised with state.raiseEvent(eventName, args).  The state chain can decide to handle the event or let it bubble up.

The main application root (application.AppRoot) extends state.RootState and defines the top‑level actions, such as "state.enter", "state.exit", and "root.collapse".

The framework includes several card‑like states:

· controller.DialogCardV2 – a modal dialog card.
· controller.ErrorDialogCard – a simpler error dialog.
· controller.RetryPageCard – a retry spinner.
· controller.CustomerServiceCard – the customer service screen.

These cards have onEnter/onExit lifecycle and can be pushed/popped on the state stack.

4.10 Reactive Programming (Rx & Events)

The framework includes a custom observable library (resembling RxJS) used extensively for data binding and event handling.

· Rx.Observable – create, subscribe, map, filter, zip, combine, etc.
· Rx.Subject, Rx.BehaviorSubject, Rx.ReplaySubject.
· Event buses: application.keydown, application.keyup (Rx Subjects).
· util.Observable – a simple event emitter (used before the Rx lib was available).
· util.MultiLock – a lock that notifies when the first lock is acquired or the last is released (used for screensaver/idle).
· util.KeyedObservable – a map of named emitters.

4.11 The Binding / Dependency Injection System

The framework uses a Binding Container (application.Binding) to resolve dependencies.  In the error page, this is configured to create singletons, factories, and pools of views.

For example, application.Binding.get("DIALOG_VIEW") returns a function that creates a DialogView instance, injecting its required button collection factory and range factory.

This system is also used to manage the EVENT_DISPATCHER and other global services.

4.12 The Event Dispatcher

view2.EventDispatcher (bound as a singleton) is the central router for pointer and key events within the view hierarchy.  It maintains:

· The current scene.
· The list of views currently under the pointer.
· The first responder chain.

It translates raw key/mouse events into method calls on views (keyDown, pointerDown, etc.), respects nextResponder and event bubbling, and supports exclusive pointer constraints (for dialogs and the customer service card).

4.13 The Application Object

application is a global object that holds:

· application.AppDialog – a service to show dialogs with a priority system.
· application.IdleTimeout – manages idle detection (for screen saver).
· application.AppLock – a multi‑lock that can suspend the idle timer.
· application.notifications – an instance of netflix.notification.ClientNotifications (used for logging UI events like views, focus, commands, and playback).
· application.exit() – calls nrdp.exit().
· application.reactivate() – performs a factory reset and reloads the boot URL.

4.14 Logging & Customer Events

The netflix.notification module is a sophisticated event logging system:

· Defines events for UI views, intents, playback, QoE, search, etc.
· Events are batched, persisted, and sent to Netflix servers (or local infrastructure).
· Uses application.notifications.notifyStart/notifyEnd to mark session durations.
· Can be suspended and restored (for app pause/resume).

This is not required for third‑party development but shows how robust the infrastructure is.

4.15 Polyfills for Browser‑Like Environment

error.js also contains polyfills to make the environment look more like a browser:

· window, document, navigator, screen, console.
· XMLHttpRequest (uses nrdp.gibbon.load under the hood).
· localStorage / sessionStorage (backed by nrdp.storage).
· setTimeout, clearTimeout, setInterval, clearInterval (global).
· Image constructor (for preloading).

These polyfills enable a huge body of existing JavaScript code to run with minimal modifications.

---

5. The Test Automation Framework (ttrlibs.js)

ttrlibs.js is a massive library used by Netflix’s certification, QA, and development teams to write automated tests on NRDP devices.  It contains hundreds of modules that cover every aspect of device testing.  While its primary purpose is testing, it exposes a wealth of functionality that can be repurposed for any application.

5.1 The Module System

The file uses a custom _dereq_ (require) function with a flat module index.  It pulls in dependencies from paths like "libs/q.js", "tpl/simone.js", "certification/gibbon/static/common.js", etc.  This module system is not automatically available to user code; it’s part of the build process for TTR tests.  However, the modules themselves use standard JavaScript patterns that can be extracted.

5.2 The MiniMePlayer – Video Playback Made Easy

MiniMePlayer is a complete wrapper around the NRDJS player that simplifies playback automation:

· Initialise: var player = new MiniMePlayer("test", qlMode); player.initialize(streamingConfig, playbackConfig).then(...)
· Play a video: player.playVideo({viewableId: 80018710, currentTime: 0})
· Wait for state: player.waitForState("PLAYING", timeout)
· Pause, stop, seek, swim: player.pauseVideo(), player.stopVideo(), player.seekVideo({currentTime: 30}), player.swimVideo({delta: 60})
· Set audio/subtitle tracks: player.setAudioTrack({language:"en", channels:"5.1"}), player.setSubtitleTrack({language:"en"})
· Playlist support: player.setPlaylist(id, def), player.startPlaylistSegment(params)
· Manifest filtering: player.setPreferredProfiles({video:/.*-h264hpl.*/}) – restricts the profiles the player can choose.
· Playback error detection: player.waitForPlayerError() returns a promise that rejects with detailed error info.
· Multi‑source: player.playUrl(urls, offset) for playing arbitrary HLS/DASH streams.
· Instrumentation: player.waitForPlaybackReporterEvent({funcname:"updatePlaybackPts"})

This player is used in almost every Netflix certification test and is a production‑quality foundation for building your own video player interface.

5.3 Scene Capture & Image Comparison

Scene Capture (libs/scene-capture.js):

```js
sceneCapture.capture({
    framebuffer: true,        // use framebuffer read (more accurate)
    captureRect: { x:0, y:0, width:1280, height:720 },
    captureDelay: 0
}).then(function(grab) {
    // grab.png is an ArrayBuffer of the PNG image
});
```

Uses nrdp.gibbon.scene.grab() or the newer sync/render event scheme.

Image Comparison (libs/scenediff.js):

· Compare actual vs. reference images using metrics: ae (absolute error), rmse, pdiff, with fuzz, percent, fov, colour factor, and optional spatial filters.
· Reference images can be stored locally, in the DTA file service, or in the asset service (S3).
· Automatic retries on mismatch (with optional scene re‑capture).
· Can generate reference images automatically when autogen is enabled.

5.4 Memory & Performance Measurement

· Memory snapshot: memory.getMemorySnapshot() returns JSC and system memory usage (by parsing smaps or NOVA meminfo).
· Garbage collection: memory.garbageCollect() and memory.garbageCollectEverything() run nrdp.gibbon.garbageCollect() repeatedly until the heap stabilises.
· FPS measurement: animation.startFramerateMeasurement() enables instrumentation, then later animation.calculate() computes frame render times and FPS.

5.5 Service Clients

· simone – Full client for Netflix’s variant management API (Simone).  Create and delete variants, retrieve logs, control AB tests.
· DtaTestConfiguration – Posts test configuration (device info, SDK version, etc.) to a DTA endpoint.
· testrun – An abstraction layer that routes test results to different backends (DTA, NTS, local).  It manages starting/ending a test run, saving data, data series, and steps.
· proxysec – A secure HTTP proxy using an ephemeral RSA key to talk to internal Netflix services.
· dasClient – Uses MSL (NRDJS) to communicate with the DAS (Device Activation Service) for account creation in INT/NTS stacks.

These clients demonstrate how to perform complex network operations within the NRDP environment, including authentication, proxy security, and JSON‑based APIs.

5.6 UI Testing Utilities

· Automation class (from certification/gibbon/static/automatedTest.js) provides a step‑by‑step test runner with manual advancement (Enter/Right) or autorun, reference image overlay, and rollback.
· Common.Widgets – pre‑built widgets: scene, testContainer, testRoot, refImgWidget.
· Common.Helpers – setScene(), clearScene(), showReferenceImage(), navigateUp(), key handling.
· Instruction widget – displays the current step description and result colour.

5.7 Key Repeater & History

util.KeyRepeater handles repeating key presses with configurable initial wait and repeat rate.  util.KeyHistory tracks the last key pressed and can detect rapid successive presses, held keys, and off‑axis rapid presses.

5.8 Debugging & Logging

· LogScroll – a log viewer overlay that displays recent log messages in a scrollable widget.
· Logger – a logger class used throughout, integrated with nrdp.log sinks.

5.9 Resolution Scaling (Again)

libs/hiResUpscaler.js is a standalone version of the TV‑UI scaling patch.  It can be enabled with hiResPatch query parameter and ensures that all widget properties and images are scaled up from the authored 1280×720 to the actual screen size (e.g., 1920×1080).

---

6. Integration and Practical Use

Now that we understand both the low‑level APIs and the high‑level frameworks, let’s discuss how to actually build an application inside the Netflix PS4 app.

6.1 Entry Point

Your custom JavaScript can be loaded in several ways:

· Via nrdp.gibbon.loadScript (if you have code execution on a test page).
· By replacing the built‑in error page (e.g., setting http://localcontrol.netflix.com/js/error.js to a custom URL).
· Through the automation stack – any test page can include your script.

Once loaded, you have access to nrdp, gibbon (the wrapped version), view2, controller, and all the utility classes from error.js (because the error page’s framework is always present when the error page is active).  If the full ttrlibs.js is loaded, you also have MiniMePlayer, qtga, scenediff, etc.

6.2 Building a Simple Game

Using only the raw nrdp.gibbon API (no framework), you can:

1. Create a root widget (black background).
2. Add score text, game‑over text.
3. Create snake segments as small coloured widgets.
4. Add a key listener that changes direction based on uiEvent.
5. Set up a timer with nrdp.gibbon.setTimeout that updates the game state and repositions the segment widgets.
6. Exit on Circle (key.back) by throwing an error or calling nrdp.exit().

This is exactly what the Snake game in tests.txt does.

6.3 Building a Full UI with the Framework

If you include the error page’s framework (which is loaded automatically when the error page is displayed), you can use all the view2 classes and the binding system.

1. Initialise the scene: gibbon.scene.start(markup) or create a root view2.Container and set scene.widget = container.element._proxy.
2. Define your UI in JSON markup – view2.Text, view2.Button, containers.
3. Instantiate views via view2.ViewFactory or directly.
4. Handle events by making your view a view2.Responder and implementing keyDown, keyUp, etc.  Register it with the event dispatcher.
5. Use the state machine to manage screens (push/pop cards).
6. Leverage Rx to bind data (e.g., monitor a util.ObservableValue for the score, and update the text view automatically).

6.4 Adding Video Playback

If MiniMePlayer is loaded (or you manually instantiate nrdp.PlayerControl), you can:

1. Create a player: var player = new MiniMePlayer("myplayer", true);
2. Initialize: player.initialize().then(...)
3. Play a movie: player.playVideo({viewableId: 70291145});
4. Control playback: player.pauseVideo(), player.seekVideo(...)
5. Listen to events: player.playerControl.stateChanged.subscribe(...)
6. Set the video widget: You need to attach the video to a widget.  The nrdp.media.setVideoWindow(widget) method is available (or it’s handled automatically by PlayerControl).  In tests, they create an erase widget that acts as the video surface:

```js
var videoWidget = nrdp.gibbon.makeWidget({ x:0, y:0, width:1280, height:720, erase:true, parent: root });
```

The player’s _media object manages the video window.

6.5 Capturing the Screen

Use sceneCapture.capture() (from ttrlibs.js) to get a PNG buffer that you can then upload or save.

6.6 Networking

Use nrdp.gibbon.load() to make HTTP/HTTPS requests.  The utility function utils.load() adds retries and better error handling.

6.7 Storing Data

nrdp.storage.setItem(nrdp.storage.NO_DEVICE_ACCOUNT, key, value) persists data across sessions.  localStorage (polyfilled) is also available when the framework is loaded.

---

7. Key Architectural Insights

· Separation of concerns: The error page framework is a clean MVC‑like system: state (controller), view2 (view), and bindings (model/DI).  This makes applications modular and testable.
· Reactive everywhere: Nearly all data flows are streams (Rx).  This minimises manual synchronisation and makes UI updates automatic.
· Declarative markup: The renderer system allows building complex widget trees from JSON, which could be loaded from a server or generated dynamically.
· Extensible: By providing your own Renderer and AView subclasses, you can create custom reusable components (e.g., a minimap, a chart) that look and behave like Netflix’s own.
· Performance: The framework batches widget updates (via the _push mechanism and pending sync) to minimise IPC overhead with the rendering engine.  Caching widgets (cache: true) is used for static parts of the UI.
· RTL support: The framework supports right‑to‑left languages through automatic mirroring and the mirror property.

---

8. Summary of Every Major Component

Component File(s) Description
Raw NRDP / gibbon tests.txt Widget creation, properties, scene, key events, timers
Input handling & help help.txt PS4 key mappings, Snake game example, UI explanation
High‑level UI framework error.js gibbon wrapper, gibbon.Widget, renderers, views, layout, styles, state stack, Rx, bindings, dialog, customer service, error page, scaling patch
Test automation library ttrlibs.js MiniMePlayer, sceneCapture, scenediff, simone, testrun, log scroll, automation runner, performance metrics, proxysec, DAS client

---

9. Conclusion

The Netflix PS4 NRDP environment is an incredibly powerful platform for building native‑like applications, games, and diagnostic tools.  By combining the raw nrdp.gibbon API, the rich view framework from *.js, and the automation powerhouse of *.js, one can achieve virtually any graphical or media experience that the hardware supports—all while running inside the official Netflix application.
