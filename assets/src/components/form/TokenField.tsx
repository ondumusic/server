import { type KeyboardEvent, useRef, useState } from "react";
import { classNames } from "../../utils/classNames";

interface Props {
  id?: string;
  name: string;
  defaultValue?: string[];
  hasError?: boolean;
  required?: boolean;
  autoFocus?: boolean;
}

export function TokenField(props: Props) {
  const [tokens, setTokens] = useState<string[]>(props.defaultValue ?? []);
  const [input, setInput] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  const addToken = (input: string) => {
    const token = input.trim().replace(/,+$/, "");
    if (!token || tokens.some((t) => t.toLowerCase() === token.toLowerCase()))
      return;
    setTokens((tokens) => [...tokens, token]);
  };

  const removeToken = (token: string) => {
    setTokens((tokens) => tokens.filter((t) => t !== token));
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if ((e.key === "Enter" || e.key === ",") && input.trim()) {
      e.preventDefault();
      addToken(input);
      setInput("");
    }

    if (e.key === "Backspace" && input === "" && tokens.length > 0) {
      removeToken(tokens[tokens.length - 1]);
    }
  };

  return (
    <div
      className={classNames([
        "mt-2 flex flex-wrap items-center gap-1.5 w-full rounded-lg px-1.5 py-1 sm:text-sm sm:leading-6",
        "bg-white/80 dark:bg-black/40",
        "border transition-colors duration-150 cursor-text",
        !props.hasError &&
          "border-zinc-400/60 dark:border-zinc-400/50 focus-within:border-zinc-400 focus-within:dark:border-zinc-200/50",
        props.hasError && "border-rose-400 dark:border-rose-400",
      ])}
    >
      {tokens.map((token) => (
        <div key={token}>
          <input
            type="hidden"
            name={props.name}
            value={token}
            required={props.required}
          />
          <span className="inline-flex items-center gap-1 pl-2.5 pr-1.5 py-1 rounded-md text-sm font-medium bg-zinc-100 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300 border border-zinc-300/60 dark:border-zinc-600/60">
            {token}
            <button
              type="button"
              onClick={(e) => {
                e.stopPropagation();
                removeToken(token);
              }}
              className="flex items-center justify-center cursor-pointer w-3.5 h-3.5 rounded-full text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200 hover:bg-zinc-200 dark:hover:bg-zinc-700 transition-colors"
            >
              x
            </button>
          </span>
        </div>
      ))}

      <input
        ref={inputRef}
        id={props.id || props.name}
        type="text"
        value={input}
        className="flex-1 min-w-[60px] py-1.5 px-1.5 bg-transparent outline-none border-none focus:ring-0 p-0 text-sm text-zinc-900 dark:text-zinc-100 placeholder:text-zinc-400 dark:placeholder:text-zinc-500"
        onChange={(e) => setInput(e.target.value)}
        onKeyDown={handleKeyDown}
      />
    </div>
  );
}
