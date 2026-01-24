# UniConv - SwiftUI macOS

A native macOS application for universal file conversion using FFmpeg and ImageMagick.

## Overview

This is a SwiftUI port of the original Tauri-based UniConv application. It provides a native macOS experience for converting video, audio, and image files.

## Features

- **Drag & Drop Interface**: Simply drag files into the app to add them to the conversion queue
- **Multiple Format Support**:
  - **Video**: MP4, WebM, MKV, MOV, GIF, and extract to MP3
  - **Audio**: MP3, WAV, FLAC, AAC, OGG, M4A
  - **Image**: PNG, JPG, WebP, PDF, BMP, TIFF
- **Batch Conversion**: Convert multiple files at once
- **Real-time Progress**: See conversion progress with speed and ETA
- **Queue Management**: Start, pause, cancel, and retry conversions
- **Native macOS Integration**: Uses system-level APIs and native UI components

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later (for building)
- FFmpeg (for video/audio conversion)
- ImageMagick (for image conversion)

## Installation

### Prerequisites

Install FFmpeg and ImageMagick using Homebrew:

```bash
brew install ffmpeg imagemagick
```

### Building the App

1. Open `UniConv.xcodeproj` in Xcode
2. Select your target device/Mac
3. Press `Cmd+R` to build and run
4. Or press `Cmd+B` to build only

The app will be compiled and can be run directly from Xcode or found in the DerivedData folder.

## Project Structure

```
UniConv-SwiftUI/
├── UniConv.xcodeproj/          # Xcode project file
└── UniConv/
    ├── UniConvApp.swift         # Main app entry point
    ├── ContentView.swift        # Main view
    ├── Models/
    │   └── FileItem.swift       # Data models
    ├── Views/
    │   ├── DropZoneView.swift   # Drag & drop area
    │   ├── FileQueueView.swift  # File list and queue
    │   ├── FormatSelector.swift # Format selection dropdown
    │   └── ProgressBarView.swift # Progress indicator
    ├── Services/
    │   └── ConversionManager.swift # Conversion logic
    ├── Utils/
    │   └── FormatUtils.swift    # Format utilities
    ├── Assets.xcassets/         # App icons and assets
    ├── Info.plist              # App information
    └── UniConv.entitlements    # Security permissions
```

## Usage

1. **Launch the app**
2. **Drag and drop files** onto the drop zone
3. **Select output format** using the format dropdown for each file
4. **Click "Convert All"** or click the play button on individual files
5. **Monitor progress** with real-time updates
6. **Completed files** are saved in the same directory as the original

## Architecture

### Key Components

- **FileItem**: Observable model representing a file in the conversion queue
- **ConversionManager**: Singleton service that handles all conversion operations
- **DropZoneView**: Handles file drag-and-drop
- **FileQueueView**: Displays and manages the conversion queue
- **FormatSelector**: Dropdown menu for selecting output format

### Conversion Flow

1. User drops files → Files are added to queue with detected type
2. User selects format and clicks convert
3. ConversionManager spawns Process for FFmpeg/ImageMagick
4. Progress is monitored via stderr parsing (FFmpeg) or immediate completion (ImageMagick)
5. File status updates in real-time
6. Completed files are marked and can be cleared

## Differences from Original Tauri App

### Advantages

- **Native Performance**: No web rendering overhead
- **Better macOS Integration**: Native file pickers, drag & drop
- **Smaller Bundle Size**: No embedded browser engine
- **System API Access**: Direct access to macOS APIs
- **SwiftUI**: Declarative, modern UI framework

### Considerations

- **macOS Only**: This is a macOS-specific app (original was cross-platform)
- **App Sandbox**: Disabled for file system access (can be enabled with proper entitlements)

## FFmpeg and ImageMagick Paths

The app expects FFmpeg and ImageMagick to be installed via Homebrew at:

- FFmpeg: `/opt/homebrew/bin/ffmpeg`
- ImageMagick: `/opt/homebrew/bin/magick`

If you have these tools installed elsewhere, modify the paths in [ConversionManager.swift](UniConv/Services/ConversionManager.swift):

```swift
private let ffmpegPath = "/opt/homebrew/bin/ffmpeg"
private let magickPath = "/opt/homebrew/bin/magick"
```

## Development

### Adding New Formats

1. Add the format extension to [FormatUtils.swift](UniConv/Utils/FormatUtils.swift)
2. Add format-specific FFmpeg arguments in [ConversionManager.swift](UniConv/Services/ConversionManager.swift)

### Customizing UI

All UI components are in the `Views/` directory and built with SwiftUI. You can customize:

- Colors and styling in each view file
- Window size in [UniConvApp.swift](UniConv/UniConvApp.swift)
- Layout in [ContentView.swift](UniConv/ContentView.swift)

## License

Same as the original UniConv project.

## Credits

SwiftUI port of the original Tauri-based UniConv application.
