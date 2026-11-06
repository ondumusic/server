interface Props {
  className: string;
  title: string;
  strokeWidth?: number;
}

export function SpinnerIcon({
  className = "size-5",
  title,
  strokeWidth = 1.5,
}: Props) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="currentColor"
      strokeWidth={strokeWidth}
      className={className}
    >
      <title>{title}</title>
      <circle
        cx="12"
        cy="12"
        r="9"
        fill="none"
        stroke="currentColor"
        strokeWidth={strokeWidth}
        opacity="0.2"
      />
      <circle
        cx="12"
        cy="12"
        r="9"
        fill="none"
        stroke="currentColor"
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        strokeDasharray="14 43"
      />
    </svg>
  );
}
