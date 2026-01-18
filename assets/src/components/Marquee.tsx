import { useCallback, useEffect, useRef, useState } from "react";
import { classNames } from "../utils/classNames";

interface Props {
  text: string;
  delay?: number;
  className?: string;
}

export function Marquee({ text, delay, className }: Props) {
  const textRef = useRef<HTMLDivElement>(null);
  const frameRef = useRef<number>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout>>(null);
  const [isAnimating, setIsAnimating] = useState(false);

  useEffect(() => {
    frameRef.current && cancelAnimationFrame(frameRef.current);
    timerRef.current && clearTimeout(timerRef.current);
    if (!textRef.current) return;

    // Reset if not animating
    if (!isAnimating) {
      textRef.current.style.transform = "";
      return;
    }

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
      if (!startTime) startTime = performance.now();

      const progress = (performance.now() - startTime) / duration;
      const newLeft = maxScrollLeft * progress;

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

    // Cleanup
    return () => {
      frameRef.current && cancelAnimationFrame(frameRef.current);
      timerRef.current && clearTimeout(timerRef.current);
    };
  }, [isAnimating, delay]);

  return (
    <div
      role="tooltip"
      onMouseEnter={useCallback(() => setIsAnimating(true), [])}
      onMouseLeave={useCallback(() => setIsAnimating(false), [])}
      className={classNames([
        "relative block w-full whitespace-nowrap overflow-hidden",
        className,
      ])}
    >
      <div
        ref={textRef}
        className={classNames([
          "transform-gpu",
          !isAnimating && "w-full overflow-hidden text-ellipsis",
        ])}
      >
        {text}
      </div>
    </div>
  );
}
