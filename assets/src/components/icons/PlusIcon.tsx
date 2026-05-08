interface Props {
  className: string;
  title: string;
}

export function PlusIcon({ className = "size-5", title }: Props) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="currentColor"
      strokeWidth="1.5"
      className={className}
    >
      <title>{title}</title>
      <path
        d="M6 12H12M18 12H12M12 12V6M12 12V18"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      ></path>
    </svg>
  );
}
