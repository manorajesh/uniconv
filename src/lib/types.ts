export type FileType = "video" | "audio" | "image" | "unknown";

export type ConversionStatus = "pending" | "converting" | "completed" | "error" | "cancelled";

export interface FileItem {
  id: string;
  path: string;
  name: string;
  type: FileType;
  status: ConversionStatus;
  progress: number;
  selectedFormat: string;
  availableFormats: string[];
  outputPath?: string;
  error?: string;
  fps?: number;
  frame?: number;
  speed?: number;
  etaSeconds?: number;
}

export interface ConversionProgress {
  file_id: string;
  percent: number;
  current_time?: number;
  total_duration?: number;
  fps?: number;
  frame?: number;
  speed?: number;
  eta_seconds?: number;
}

export interface ConversionComplete {
  file_id: string;
  output_path: string;
}

export interface ConversionError {
  file_id: string;
  message: string;
}

export interface ConversionCancelled {
  file_id: string;
}
