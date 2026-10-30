interface Props {
  className: string;
  title: string;
  strokeWidth?: number;
}

export function SearchIcon({
  className = "size-5",
  title,
  strokeWidth = 1.5,
}: Props) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      strokeWidth={strokeWidth}
      className={className}
    >
      <title>{title}</title>
      <circle cx="11" cy="11" r="7" stroke="currentColor" />
      <path d="M20 20L16 16" stroke="currentColor" strokeLinecap="round" />
    </svg>
  );
}
