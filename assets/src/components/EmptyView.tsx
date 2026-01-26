interface Props {
  message: string;
}

export function EmptyView({ message }: Props) {
  return (
    <div className="h-full content-center text-center">
      <p>{message}</p>
    </div>
  );
}
