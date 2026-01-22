import { useEffect, useState } from "react";
import { listen } from "@tauri-apps/api/event";
import { FolderOpen } from "lucide-react";

interface DropZoneProps {
  onFilesDropped: (paths: string[]) => void;
}

export function DropZone({ onFilesDropped }: DropZoneProps) {
  const [isDragging, setIsDragging] = useState(false);

  useEffect(() => {
    const unlistenDrop = listen<{ paths: string[] }>(
      "tauri://drag-drop",
      (event) => {
        setIsDragging(false);
        if (event.payload.paths.length > 0) {
          onFilesDropped(event.payload.paths);
        }
      }
    );

    const unlistenEnter = listen("tauri://drag-enter", () => {
      setIsDragging(true);
    });

    const unlistenLeave = listen("tauri://drag-leave", () => {
      setIsDragging(false);
    });

    return () => {
      unlistenDrop.then((fn) => fn());
      unlistenEnter.then((fn) => fn());
      unlistenLeave.then((fn) => fn());
    };
  }, [onFilesDropped]);

  return (
    <div
      className={`
        relative border-2 border-dashed rounded-lg p-8
        transition-all duration-150 ease-out
        ${
          isDragging
            ? "border-blue-500 bg-blue-500/5 scale-[1.01]"
            : "border-gray-700 hover:border-gray-600 bg-gray-800/30"
        }
      `}
    >
      <div className="flex flex-col items-center gap-3 text-center">
        <div
          className={`
            p-3 rounded-lg transition-colors
            ${isDragging ? "bg-blue-500/10 text-blue-400" : "bg-gray-800 text-gray-500"}
          `}
        >
          <FolderOpen size={24} />
        </div>
        <div>
          <p className="text-sm text-gray-300">
            {isDragging ? "Drop files here" : "Drop files to convert"}
          </p>
          <p className="text-xs text-gray-500 mt-1">
            Video, audio, and images supported
          </p>
        </div>
      </div>
    </div>
  );
}
