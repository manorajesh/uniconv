# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

UniConv is a cross-platform desktop file converter built with Tauri v2. It converts video, audio, and image files using system-installed FFmpeg and ImageMagick.

## Build & Development Commands

```bash
# Install dependencies
pnpm install

# Development mode (starts Vite dev server + Tauri)
pnpm tauri dev

# Build for production
pnpm tauri build

# Type check
pnpm run build  # runs tsc && vite build
```

## Prerequisites

Install FFmpeg and ImageMagick via Homebrew:
```bash
brew install ffmpeg imagemagick
```

The converters expect binaries at `/opt/homebrew/bin/ffmpeg` and `/opt/homebrew/bin/magick`.

## Architecture

### Frontend (React + TypeScript)
- `src/App.tsx` - Main app component, manages file state
- `src/components/DropZone.tsx` - Handles Tauri drag-drop events (`tauri://drag-drop`)
- `src/components/FileQueue.tsx` - Displays file list with progress bars
- `src/hooks/useConversion.tsx` - React Context for conversion state, listens to Tauri events

### Backend (Rust)
- `src-tauri/src/lib.rs` - Registers Tauri commands and plugins
- `src-tauri/src/commands/convert.rs` - Main `convert_file` command, routes to converters
- `src-tauri/src/converter/ffmpeg.rs` - FFmpeg wrapper with progress parsing
- `src-tauri/src/converter/imagemagick.rs` - ImageMagick wrapper

## Key Patterns

### Tauri Events
The Rust backend emits events to the frontend for real-time progress:
- `conversion:progress` - `{ file_id, percent, current_time, total_duration }`
- `conversion:complete` - `{ file_id, output_path }`
- `conversion:error` - `{ file_id, message }`

### FFmpeg Progress Parsing
Progress is extracted from FFmpeg stdout by parsing `time=HH:MM:SS.ms` patterns. See `parse_progress_time()` in `ffmpeg.rs`.

### File Type Detection
File types are determined by extension in `src/lib/formats.ts`. Output format options are dynamically shown based on input file type.

## Adding New Formats

1. Add extension to appropriate array in `src/lib/formats.ts`
2. Add output format to corresponding `*_OUTPUT_FORMATS` array
3. If needed, add format-specific FFmpeg/ImageMagick args in `src-tauri/src/converter/`
