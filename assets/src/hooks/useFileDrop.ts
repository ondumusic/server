import { type DragEvent, useCallback, useState } from "react";

const hasFiles = (e: DragEvent) => {
  return e.dataTransfer.types.includes("Files");
};

export function useFileDrop(onDrop: (file: File) => void) {
  const [isDraggingFiles, setIsDraggingFiles] = useState(false);

  const handleDragOver = useCallback((e: DragEvent) => {
    if (!hasFiles(e)) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = "copy";
    setIsDraggingFiles(true);
  }, []);

  const handleDragLeave = useCallback((e: DragEvent) => {
    if (e.currentTarget.contains(e.relatedTarget as Node)) return;
    setIsDraggingFiles(false);
  }, []);

  const handleDrop = useCallback(
    (e: DragEvent) => {
      setIsDraggingFiles(false);
      if (!hasFiles(e)) return;
      e.preventDefault();

      const file = e.dataTransfer.files[0];
      if (file) onDrop(file);
    },
    [onDrop],
  );

  return {
    isDraggingFiles,
    props: {
      onDragOver: handleDragOver,
      onDragLeave: handleDragLeave,
      onDrop: handleDrop,
    },
  };
}
