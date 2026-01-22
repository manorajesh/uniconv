import { useState } from "react";
import { DropZone } from "./components/DropZone";
import { FileQueue } from "./components/FileQueue";
import { ConversionProvider } from "./hooks/useConversion";
import { FileItem } from "./lib/types";
import { getFileType, getOutputFormats } from "./lib/formats";

function App() {
  const [files, setFiles] = useState<FileItem[]>([]);

  const handleFilesDropped = (paths: string[]) => {
    const newFiles: FileItem[] = paths.map((path) => {
      const fileName = path.split("/").pop() || path.split("\\").pop() || path;
      const extension = fileName.split(".").pop()?.toLowerCase() || "";
      const fileType = getFileType(extension);
      const availableFormats = getOutputFormats(fileType);

      return {
        id: crypto.randomUUID(),
        path,
        name: fileName,
        type: fileType,
        status: "pending",
        progress: 0,
        selectedFormat: availableFormats[0] || "",
        availableFormats,
      };
    });

    setFiles((prev) => [...prev, ...newFiles]);
  };

  const handleFormatChange = (fileId: string, format: string) => {
    setFiles((prev) =>
      prev.map((f) => (f.id === fileId ? { ...f, selectedFormat: format } : f))
    );
  };

  const handleRemoveFile = (fileId: string) => {
    setFiles((prev) => prev.filter((f) => f.id !== fileId));
  };

  const handleClearCompleted = () => {
    setFiles((prev) => prev.filter((f) =>
      f.status !== "completed" && f.status !== "cancelled" && f.status !== "error"
    ));
  };

  return (
    <ConversionProvider setFiles={setFiles}>
      <div className="h-screen bg-gray-900 text-gray-100 flex flex-col">
        {/* Draggable title bar area */}
        <div
          className="h-8 flex-shrink-0"
          style={{ WebkitAppRegion: "drag" } as React.CSSProperties}
        />

        {/* Main content */}
        <div className="flex-1 overflow-auto px-4 pb-4">
          <div className="max-w-2xl mx-auto space-y-4">
            <DropZone onFilesDropped={handleFilesDropped} />

            {files.length > 0 && (
              <FileQueue
                files={files}
                onFormatChange={handleFormatChange}
                onRemove={handleRemoveFile}
                onClearCompleted={handleClearCompleted}
              />
            )}
          </div>
        </div>
      </div>
    </ConversionProvider>
  );
}

export default App;
