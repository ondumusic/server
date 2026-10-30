interface Props {
  title: string;
}

export function SectionHeader({ title }: Props) {
  return <h2 className="px-2 pb-3 text-xl font-bold text-page-fg">{title}</h2>;
}
