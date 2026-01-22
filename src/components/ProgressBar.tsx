interface ProgressBarProps {
  progress: number;
  status: "pending" | "converting" | "completed" | "error" | "cancelled";
}

export function ProgressBar({ progress, status }: ProgressBarProps) {
  const getBarColor = () => {
    switch (status) {
      case "completed":
        return "bg-green-500";
      case "error":
        return "bg-red-500";
      case "cancelled":
        return "bg-yellow-500";
      case "converting":
        return "bg-blue-500";
      default:
        return "bg-gray-600";
    }
  };

  return (
    <div className="w-full h-2 bg-gray-700 rounded-full overflow-hidden">
      <div
        className={`h-full transition-all duration-300 ${getBarColor()}`}
        style={{ width: `${Math.min(100, Math.max(0, progress))}%` }}
      />
    </div>
  );
}
