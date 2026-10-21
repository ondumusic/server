interface Props {
  className: string;
  title: string;
}

export function ShuffleIcon({ className = "size-5", title }: Props) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
    >
      <title>{title}</title>
      <path d="M22 7C19 7 15 7 12 12C9 17 5 17 2 17"></path>
      <path d="M20 5L22 7L20 9"></path>
      <path d="M22 17C19 17 15 17 12 12C9 7 5 7 2 7"></path>
      <path d="M20 15L22 17L20 19"></path>
    </svg>
  );
}
