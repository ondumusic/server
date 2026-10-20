interface Props {
  className: string;
  title: string;
  strokeWidth?: number;
}

export function CheckIcon({
  className = "size-5",
  title,
  strokeWidth = 2,
}: Props) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      className={className}
    >
      <title>{title}</title>
      <path
        d="M5 13L9 17L19 7"
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        strokeLinejoin="round"
      ></path>
    </svg>
  );
}
