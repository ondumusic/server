interface Props {
  title: string;
  subtitle?: string;
}

export function ResultRow({ title, subtitle }: Props) {
  return (
    <div className="px-2 py-1.5 rounded-md text-sm truncate hover:bg-black/5 dark:hover:bg-white/5">
      {title}
      {subtitle && (
        <span className="inline-block pl-1 text-muted">{subtitle}</span>
      )}
    </div>
  );
}
