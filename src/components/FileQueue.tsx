import { Film, Music, Image, File, X, Check, AlertCircle, Play, Square, RotateCcw } from "lucide-react";
import { FileItem } from "../lib/types";
import { FormatSelector } from "./FormatSelector";
import { ProgressBar } from "./ProgressBar";
import { useConversion } from "../hooks/useConversion";

interface FileQueueProps {
  files: FileItem[];
  onFormatChange: (fileId: string, format: string) => void;
  onRemove: (fileId: string) => void;
  onClearCompleted: () => void;
}

function FileTypeIcon({ type }: { type: FileItem["type"] }) {
  const iconProps = { size: 18, className: "text-gray-400 flex-shrink-0" };

  switch (type) {
    case "video":
      return <Film {...iconProps} />;
    case "audio":
      return <Music {...iconProps} />;
    case "image":
      return <Image {...iconProps} />;
    default:
      return <File {...iconProps} />;
  }
}

function formatEta(seconds: number | undefined): string {
  if (seconds === undefined || seconds <= 0 || !isFinite(seconds)) return "";

  if (seconds < 60) {
    return `${Math.round(seconds)}s remaining`;
  } else if (seconds < 3600) {
    const mins = Math.floor(seconds / 60);
    const secs = Math.round(seconds % 60);
    return `${mins}m ${secs}s remaining`;
  } else {
    const hours = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    return `${hours}h ${mins}m remaining`;
  }
}

function ProgressInfo({ file }: { file: FileItem }) {
  if (file.status !== "converting") return null;

  const parts: string[] = [];

  // Show percentage
  parts.push(`${Math.round(file.progress)}%`);

  // Show speed if available
  if (file.speed !== undefined && file.speed > 0 && isFinite(file.speed)) {
    parts.push(`${file.speed.toFixed(1)}x speed`);
  }

  // Show ETA
  const eta = formatEta(file.etaSeconds);
  if (eta) {
    parts.push(eta);
  }

  if (parts.length === 0) return null;

  return (
    <span className="text-xs text-gray-500 ml-2">
      {parts.join(" · ")}
    </span>
  );
}

export function FileQueue({
  files,
  onFormatChange,
  onRemove,
  onClearCompleted,
}: FileQueueProps) {
  const { startConversion, cancelConversion, isConverting } = useConversion();

  const pendingFiles = files.filter((f) => f.status === "pending");
  const hasFinished = files.some((f) => f.status === "completed" || f.status === "cancelled" || f.status === "error");

  const handleConvertAll = () => {
    pendingFiles.forEach((file) => {
      startConversion(file.id, file.path, file.selectedFormat);
    });
  };

  const handleRetry = (file: FileItem) => {
    startConversion(file.id, file.path, file.selectedFormat);
  };

  return (
    <div className="bg-gray-800/50 rounded-lg border border-gray-700">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-gray-700">
        <span className="text-sm font-medium text-gray-300">
          {files.length} {files.length === 1 ? "file" : "files"}
        </span>
        <div className="flex gap-2">
          {hasFinished && (
            <button
              onClick={onClearCompleted}
              className="px-2.5 py-1 text-xs text-gray-400 hover:text-white hover:bg-gray-700 rounded transition-colors"
            >
              Clear
            </button>
          )}
          {pendingFiles.length > 0 && (
            <button
              onClick={handleConvertAll}
              disabled={isConverting}
              className="
                flex items-center gap-1.5 px-3 py-1 rounded
                bg-blue-600 hover:bg-blue-500 disabled:bg-gray-600
                text-xs font-medium transition-colors
                disabled:cursor-not-allowed
              "
            >
              <Play size={12} />
              Convert
            </button>
          )}
        </div>
      </div>

      {/* File list */}
      <div className="divide-y divide-gray-700/50">
        {files.map((file) => (
          <div
            key={file.id}
            className="flex items-center gap-3 px-4 py-3 hover:bg-gray-700/30 transition-colors"
          >
            <FileTypeIcon type={file.type} />

            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <span className="text-sm truncate text-gray-200">{file.name}</span>
                {file.status === "completed" && (
                  <Check size={14} className="text-green-500 flex-shrink-0" />
                )}
                {file.status === "error" && (
                  <AlertCircle size={14} className="text-red-500 flex-shrink-0" />
                )}
              </div>

              {file.status === "converting" && (
                <div className="mt-1.5 flex items-center">
                  <div className="flex-1">
                    <ProgressBar progress={file.progress} status={file.status} />
                  </div>
                  <ProgressInfo file={file} />
                </div>
              )}

              {file.status === "error" && file.error && (
                <p className="text-xs text-red-400 mt-1 truncate">{file.error}</p>
              )}

              {file.status === "cancelled" && (
                <p className="text-xs text-gray-500 mt-1">Cancelled</p>
              )}
            </div>

            <FormatSelector
              formats={file.availableFormats}
              selected={file.selectedFormat}
              onChange={(format) => onFormatChange(file.id, format)}
              disabled={file.status === "converting"}
            />

            {/* Action buttons */}
            <div className="flex items-center gap-1">
              {file.status === "converting" ? (
                <button
                  onClick={() => cancelConversion(file.id)}
                  className="p-1.5 text-gray-400 hover:text-red-400 hover:bg-gray-700 rounded transition-colors"
                  title="Cancel"
                >
                  <Square size={14} />
                </button>
              ) : (file.status === "cancelled" || file.status === "error") ? (
                <button
                  onClick={() => handleRetry(file)}
                  className="p-1.5 text-gray-400 hover:text-blue-400 hover:bg-gray-700 rounded transition-colors"
                  title="Retry"
                >
                  <RotateCcw size={14} />
                </button>
              ) : null}

              {file.status !== "converting" && (
                <button
                  onClick={() => onRemove(file.id)}
                  className="p-1.5 text-gray-500 hover:text-gray-300 hover:bg-gray-700 rounded transition-colors"
                  title="Remove"
                >
                  <X size={14} />
                </button>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
