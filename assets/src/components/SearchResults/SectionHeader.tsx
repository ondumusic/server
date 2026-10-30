interface Props {
  title: string;
}

export function SectionHeader({ title }: Props) {
  return (
    <h2 className="px-2 pt-8 pb-3 text-xl font-semibold text-page-fg">
      {title}
    </h2>
  );
}
