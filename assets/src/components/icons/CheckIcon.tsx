interface Props {
  className: string;
  title: string;
}

export function CheckIcon({ className = "size-5", title }: Props) {
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
        d="M5 13L9 17L19 7"
        stroke="#ffffff"
        stroke-width="1.5"
        stroke-linecap="round"
        stroke-linejoin="round"
      ></path>
    </svg>
  );
}
