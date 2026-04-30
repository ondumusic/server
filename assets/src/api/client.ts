import { notFound } from "@tanstack/react-router";
import { auth } from "../services/auth";
import type { Page } from "../types";
import { ClientError } from "./errors";

type RequestMethod = "GET" | "POST" | "PATCH" | "DELETE";
type RequestBody<T> = BodyInit | undefined | T;
type RequestHeaders = { [key: string]: string };

export interface RequestOptions {
  signal?: AbortSignal;
  search?: Record<string, string>;
}

class Client {
  #baseURL = "/api";

  constructor(
    opts: {
      baseURL?: string;
    } = {},
  ) {
    this.#baseURL = (opts.baseURL || this.#baseURL).replace(/\/$/, "");
  }

  async get<Req, Res>(path: string, opts: RequestOptions = {}): Promise<Res> {
    return this.#request<Req, Res>("GET", path, undefined, opts);
  }

  async *paginate<Req, Res>(
    path: string,
    opts: RequestOptions = {},
  ): AsyncGenerator<Res> {
    let hasPages = true,
      pageNumber = 1,
      search = opts.search ?? {};

    do {
      const response = await this.get<Req, Page<Res>>(path, {
        ...opts,
        search: { ...search, page: pageNumber.toString() },
      });

      for (const entry of response.entries) {
        yield entry;
      }

      if (response.pageNumber < response.totalPages) {
        pageNumber++;
      } else {
        hasPages = false;
      }
    } while (hasPages);
  }

  async post<Req, Res>(
    path: string,
    body: RequestBody<Req>,
    opts: RequestOptions = {},
  ): Promise<Res> {
    return this.#request<Req, Res>("POST", path, body, opts);
  }

  async patch<Req, Res>(
    path: string,
    body: RequestBody<Req>,
    opts: RequestOptions = {},
  ): Promise<Res> {
    return this.#request<Req, Res>("PATCH", path, body, opts);
  }

  async delete<Req, Res>(
    path: string,
    opts: RequestOptions = {},
  ): Promise<Res> {
    return this.#request<Req, Res>("DELETE", path, undefined, opts);
  }

  async #request<Req, Res>(
    method: RequestMethod,
    path: string,
    body: RequestBody<Req>,
    opts: RequestOptions,
  ): Promise<Res> {
    const requestPath = this.#baseURL + path;
    const url = new URL(requestPath, window.location.href);
    url.search = new URLSearchParams(opts?.search ?? {}).toString();

    const headers: RequestHeaders = {
      "Content-Type": "application/json",
      Accept: "application/json",
    };

    if (auth.sessionToken) {
      headers.Authorization = `Bearer ${auth.sessionToken}`;
    }

    if (typeof body === "object") {
      body = JSON.stringify(body);
    }

    try {
      const response = await fetch(url.toString(), {
        body: body as BodyInit,
        method,
        headers,
        credentials: "omit",
        signal: opts?.signal,
      });

      if (response.status === 401) {
        throw new ClientError({ message: "Unauthorized", response });
      }

      if (response.status === 403) {
        throw new ClientError({ message: "Forbidden", response });
      }

      if (response.status === 404) {
        throw notFound();
      }

      if (response.status === 204) {
        return { ok: true } as Res;
      }

      return (await response.json()) as Res;
    } catch (err) {
      if (err instanceof Error && err.name === "AbortError") {
        throw new ClientError({ message: "Aborted", aborted: true });
      }

      throw err;
    }
  }
}

export const client = new Client({
  baseURL: "/api",
});
