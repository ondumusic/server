import { useRef } from "react";

export type Observer<T> = (event: T) => void;

export function useObserver<T>(): [
  (event: T) => void,
  (callback: Observer<T>) => () => void,
] {
  const observers = useRef(new Set<Observer<T>>());

  const emit = (event: T) => {
    observers.current.forEach((callback) => {
      callback(event);
    });
  };

  const addObserver = (callback: Observer<T>): (() => void) => {
    observers.current.add(callback);
    return () => observers.current.delete(callback);
  };

  return [emit, addObserver];
}
