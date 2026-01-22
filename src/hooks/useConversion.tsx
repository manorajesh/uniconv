import {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  ReactNode,
  Dispatch,
  SetStateAction,
} from "react";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import {
  FileItem,
  ConversionProgress,
  ConversionComplete,
  ConversionError,
  ConversionCancelled,
} from "../lib/types";

interface ConversionContextType {
  startConversion: (fileId: string, inputPath: string, outputFormat: string) => void;
  cancelConversion: (fileId: string) => void;
  isConverting: boolean;
}

const ConversionContext = createContext<ConversionContextType | null>(null);

interface ConversionProviderProps {
  children: ReactNode;
  setFiles: Dispatch<SetStateAction<FileItem[]>>;
}

export function ConversionProvider({
  children,
  setFiles,
}: ConversionProviderProps) {
  const [activeConversions, setActiveConversions] = useState<Set<string>>(
    new Set()
  );

  const isConverting = activeConversions.size > 0;

  // Listen for conversion events from Tauri backend
  useEffect(() => {
    const unlistenProgress = listen<ConversionProgress>(
      "conversion:progress",
      (event) => {
        const { file_id, percent, fps, frame, speed, eta_seconds } = event.payload;
        setFiles((prev) =>
          prev.map((f) =>
            f.id === file_id
              ? {
                  ...f,
                  status: "converting",
                  progress: percent,
                  fps,
                  frame,
                  speed,
                  etaSeconds: eta_seconds,
                }
              : f
          )
        );
      }
    );

    const unlistenComplete = listen<ConversionComplete>(
      "conversion:complete",
      (event) => {
        const { file_id, output_path } = event.payload;
        setFiles((prev) =>
          prev.map((f) =>
            f.id === file_id
              ? {
                  ...f,
                  status: "completed",
                  progress: 100,
                  outputPath: output_path,
                }
              : f
          )
        );
        setActiveConversions((prev) => {
          const next = new Set(prev);
          next.delete(file_id);
          return next;
        });
      }
    );

    const unlistenError = listen<ConversionError>(
      "conversion:error",
      (event) => {
        const { file_id, message } = event.payload;
        setFiles((prev) =>
          prev.map((f) =>
            f.id === file_id ? { ...f, status: "error", error: message } : f
          )
        );
        setActiveConversions((prev) => {
          const next = new Set(prev);
          next.delete(file_id);
          return next;
        });
      }
    );

    const unlistenCancelled = listen<ConversionCancelled>(
      "conversion:cancelled",
      (event) => {
        const { file_id } = event.payload;
        setFiles((prev) =>
          prev.map((f) =>
            f.id === file_id
              ? { ...f, status: "cancelled", progress: 0 }
              : f
          )
        );
        setActiveConversions((prev) => {
          const next = new Set(prev);
          next.delete(file_id);
          return next;
        });
      }
    );

    return () => {
      unlistenProgress.then((fn) => fn());
      unlistenComplete.then((fn) => fn());
      unlistenError.then((fn) => fn());
      unlistenCancelled.then((fn) => fn());
    };
  }, [setFiles]);

  const startConversion = useCallback(
    async (fileId: string, inputPath: string, outputFormat: string) => {
      // Mark file as converting
      setFiles((prev) =>
        prev.map((f) =>
          f.id === fileId ? { ...f, status: "converting", progress: 0 } : f
        )
      );

      setActiveConversions((prev) => new Set(prev).add(fileId));

      try {
        await invoke("convert_file", {
          fileId,
          inputPath,
          outputFormat,
          outputPath: null,
        });
      } catch (error) {
        // Error will be handled by the event listener
        console.error("Conversion error:", error);
      }
    },
    [setFiles]
  );

  const cancelConversion = useCallback(async (fileId: string) => {
    try {
      await invoke("cancel_conversion", { fileId });
    } catch (error) {
      console.error("Cancel error:", error);
    }
  }, []);

  return (
    <ConversionContext.Provider value={{ startConversion, cancelConversion, isConverting }}>
      {children}
    </ConversionContext.Provider>
  );
}

export function useConversion() {
  const context = useContext(ConversionContext);
  if (!context) {
    throw new Error("useConversion must be used within a ConversionProvider");
  }
  return context;
}
