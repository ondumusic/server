interface Props {
  className?: string;
  title?: string;
  paused?: boolean;
}

export const AnimatedWaveform = ({
  className,
  title,
  paused = false,
}: Props) => {
  const dur = (base: number) => `${(base / 0.8).toFixed(2)}s`;
  const playState = paused ? "paused" : "running";

  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
    >
      <title>{title}</title>
      <style>{`
        @keyframes pw-bar-1 { 0%,100% { transform: scaleY(0.35); } 50% { transform: scaleY(1); } }
        @keyframes pw-bar-2 { 0%,100% { transform: scaleY(1);    } 50% { transform: scaleY(0.4); } }
        @keyframes pw-bar-3 { 0%,100% { transform: scaleY(0.55); } 50% { transform: scaleY(0.95); } }
        @keyframes pw-bar-4 { 0%,100% { transform: scaleY(0.85); } 50% { transform: scaleY(0.3); } }

        .pw-bar {
          transform-box: fill-box;
          transform-origin: center;
          animation-iteration-count: infinite;
          animation-timing-function: ease-in-out;
          animation-play-state: ${playState};
        }
        .pw-bar-1 { animation-name: pw-bar-1; animation-duration: ${dur(0.9)}; }
        .pw-bar-2 { animation-name: pw-bar-2; animation-duration: ${dur(0.7)}; }
        .pw-bar-3 { animation-name: pw-bar-3; animation-duration: ${dur(1.1)}; }
        .pw-bar-4 { animation-name: pw-bar-4; animation-duration: ${dur(0.8)}; }

        @media (prefers-reduced-motion: reduce) {
          .pw-bar { animation: none; }
        }
      `}</style>
      <line className="pw-bar pw-bar-1" x1="5" y1="4" x2="5" y2="20" />
      <line className="pw-bar pw-bar-2" x1="10" y1="4" x2="10" y2="20" />
      <line className="pw-bar pw-bar-3" x1="15" y1="4" x2="15" y2="20" />
      <line className="pw-bar pw-bar-4" x1="20" y1="4" x2="20" y2="20" />
    </svg>
  );
};
