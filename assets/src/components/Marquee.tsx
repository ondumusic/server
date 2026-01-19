import { memo, useEffect, useRef } from "react";
import { classNames } from "../utils/classNames";

interface Props {
  text: string;
  delay?: number;
  className?: string;
}

export const Marquee = memo(({ text, delay, className }: Props) => {
  const textRef = useRef<HTMLDivElement>(null);
  const parentRef = useRef<HTMLDivElement>(null);
  const frameRef = useRef<number>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout>>(null);

  useEffect(() => {
    if (!textRef.current) return;
    if (!parentRef.current) return;

    const handleMouseEnter = () => {
      if (!textRef.current) return;
      if (!parentRef.current) return;

      if (timerRef.current) clearTimeout(timerRef.current);

      // Get the maximum amount we can scroll
      const maxScrollLeft =
        textRef.current.scrollWidth - textRef.current.clientWidth;
      if (maxScrollLeft === 0) {
        return;
      }

      // Calculate the duration based on the amount of scrollable content
      const duration = maxScrollLeft * 25;
      let startTime: number;

      // Animation function
      function animate() {
        if (!textRef.current) return;
        if (!parentRef.current) return;
        if (!startTime) startTime = performance.now();

        const progress = (performance.now() - startTime) / duration;
        const newLeft = maxScrollLeft * progress;

        parentRef.current.classList.remove(
          "w-full",
          "overflow-hidden",
          "text-ellipsis",
        );

        if (progress < 1) {
          textRef.current.style.transform = `translateX(-${newLeft}px)`;
          frameRef.current = requestAnimationFrame(animate);
        } else {
          textRef.current.style.transform = `translateX(-${maxScrollLeft}px)`;
        }
      }

      // Should it start immediately or with a delay?
      if (typeof delay === "number" && delay > 0) {
        timerRef.current = setTimeout(animate, delay);
      } else {
        frameRef.current = requestAnimationFrame(animate);
      }
    };

    const handleMouseLeave = () => {
      if (textRef.current) {
        textRef.current.style.transform = "";
      }

      if (parentRef.current) {
        parentRef.current.classList.add(
          "w-full",
          "overflow-hidden",
          "text-ellipsis",
        );
      }

      if (timerRef.current) clearTimeout(timerRef.current);
    };

    parentRef.current.addEventListener("mouseenter", handleMouseEnter);
    parentRef.current.addEventListener("mouseleave", handleMouseLeave);

    return () => {
      if (frameRef.current) cancelAnimationFrame(frameRef.current);
      if (timerRef.current) clearTimeout(timerRef.current);

      if (!parentRef.current) return;
      parentRef.current.classList.add(
        "w-full",
        "overflow-hidden",
        "text-ellipsis",
      );
      parentRef.current.removeEventListener("mouseenter", handleMouseEnter);
      parentRef.current.removeEventListener("mouseleave", handleMouseLeave);
    };
  }, [delay]);

  return (
    <div
      ref={parentRef}
      className={classNames([
        "relative block w-full whitespace-nowrap overflow-hidden",
        className,
      ])}
    >
      <div ref={textRef} className="w-full overflow-hidden text-ellipsis">
        {text}
      </div>
    </div>
  );
});
