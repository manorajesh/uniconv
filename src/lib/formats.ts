import { FileType } from "./types";

const VIDEO_EXTENSIONS = [
  "mp4",
  "mkv",
  "avi",
  "mov",
  "webm",
  "flv",
  "wmv",
  "m4v",
];
const AUDIO_EXTENSIONS = ["mp3", "wav", "flac", "aac", "ogg", "m4a", "wma"];
const IMAGE_EXTENSIONS = [
  "png",
  "jpg",
  "jpeg",
  "gif",
  "webp",
  "bmp",
  "tiff",
  "svg",
];

const VIDEO_OUTPUT_FORMATS = ["mp4", "webm", "mkv", "mov", "gif", "mp3"];
const AUDIO_OUTPUT_FORMATS = ["mp3", "wav", "flac", "aac", "ogg", "m4a"];
const IMAGE_OUTPUT_FORMATS = ["png", "jpg", "webp", "pdf", "bmp", "tiff"];

export function getFileType(extension: string): FileType {
  const ext = extension.toLowerCase();

  if (VIDEO_EXTENSIONS.includes(ext)) return "video";
  if (AUDIO_EXTENSIONS.includes(ext)) return "audio";
  if (IMAGE_EXTENSIONS.includes(ext)) return "image";

  return "unknown";
}

export function getOutputFormats(fileType: FileType): string[] {
  switch (fileType) {
    case "video":
      return VIDEO_OUTPUT_FORMATS;
    case "audio":
      return AUDIO_OUTPUT_FORMATS;
    case "image":
      return IMAGE_OUTPUT_FORMATS;
    default:
      return [];
  }
}

export function getFileTypeIcon(fileType: FileType): string {
  switch (fileType) {
    case "video":
      return "film";
    case "audio":
      return "music";
    case "image":
      return "image";
    default:
      return "file";
  }
}
