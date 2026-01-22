interface FormatSelectorProps {
  formats: string[];
  selected: string;
  onChange: (format: string) => void;
  disabled?: boolean;
}

export function FormatSelector({
  formats,
  selected,
  onChange,
  disabled = false,
}: FormatSelectorProps) {
  return (
    <select
      value={selected}
      onChange={(e) => onChange(e.target.value)}
      disabled={disabled}
      className={`
        px-2 py-1 rounded text-xs font-medium
        bg-gray-700 border border-gray-600
        focus:outline-none focus:border-gray-500
        disabled:opacity-40 disabled:cursor-not-allowed
        appearance-none cursor-pointer
        pr-6 bg-no-repeat bg-right
        ${disabled ? "text-gray-500" : "text-gray-200"}
      `}
      style={{
        backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%236b7280' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E")`,
        backgroundPosition: "right 6px center",
      }}
    >
      {formats.map((format) => (
        <option key={format} value={format}>
          {format.toUpperCase()}
        </option>
      ))}
    </select>
  );
}
