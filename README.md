# MeetUp2 Remote

A native macOS menu bar app for controlling the zoom and pan/tilt of a [Logitech MeetUp 2](https://www.logitech.com/en-eu/products/video-conferencing/conference-cameras/meetup2.html) conference camera over USB.

[Logitech](https://www.logitech.com/) has no app to drive the MeetUp 2's camera controls. MeetUp2 Remote lives in the menu bar: click the icon, and a small panel shows the camera's connection state and current zoom, with a zoom slider and a directional pad for pan/tilt. Changes take effect immediately in whatever app is using the camera.

![MeetUp2 Remote](Meetup2%20Remote.png)

## Features

- Menu bar app — no Dock icon, one click away
- Detects the first attached MeetUp 2 at launch
- Live zoom value read from the camera, absolute zoom control via a slider
- Pan/tilt movement via a directional pad (short relative movement pulses)
- Errors are shown in the panel; every USB operation is logged to stderr for diagnostics

## Requirements

- macOS 14 (Sonoma) or later
- A Logitech MeetUp 2 connected over USB
- To build from source: a current Swift toolchain (Xcode or Command Line Tools)

## Running

This a demo of [***plain](https://www.plainlang.org/): you generate the app's code from the spec yourself, then run it.

### 1. Render the app

Install the `codeplain` renderer (instructions at [codeplain.ai](https://codeplain.ai)), then run from the repository root:

```bash
codeplain meetup2_remote.plain
```

This generates the Swift code of the app into `dist/`.

### 2. Run it

```bash
cd dist
swift run
```

The icon appears in the menu bar.

### 3. Package it (optional)

```bash
cd dist
./package.sh
```

Produces `release/MeetUp2Remote.app` and `release/MeetUp2Remote.zip`, release-built and ad-hoc signed. To run the packaged app, unzip `MeetUp2Remote.zip`, then right-click `MeetUp2Remote.app` → **Open** (needed once — the bundle is ad-hoc signed).

## How this project is built

This repository is a [***plain](https://codeplain.ai) project: the source is in `meetup2_remote.plain`, and the Swift code is generated from it by the `codeplain` renderer (see [Running](#running) above).

```
meetup2_remote.plain              # the specification (concepts, requirements, functional specs)
resources/
  uvc-control-protocol.yaml      # UVC protocol facts and macOS IOKit access recipes
test_scripts/                    # unit- and conformance-test runners (wired via config.yaml)
config.yaml                      # renderer configuration
plain_modules/                   # generated code + conformance tests
dist/                            # the latest successfully rendered app
dist/release/                    # packaged distribution artifacts (produced by dist/package.sh)
```

## Hardware notes

Learned from the live device and encoded in `resources/uvc-control-protocol.yaml`:

- Zoom uses the standard UVC absolute control and reports real values.
- The MeetUp 2 does **not** report a pan/tilt position: the UVC absolute pan/tilt control always reads zero. Movement works through the relative control (direction + start/stop pulses), which is what the directional pad uses — so the panel intentionally shows no pan/tilt numbers.
- Detection matches USB vendor ID `0x046D` and a product name containing "MeetUp" (the device reports "Logi MeetUp 2").
