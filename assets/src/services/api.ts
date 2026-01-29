import { auth } from "../services/auth";

interface ApiErrorArguments {
  message: string;
  response?: Response;
  aborted?: boolean;
}

export class ApiError extends Error {
  response?: Response;
  aborted?: boolean;

  constructor(params: ApiErrorArguments) {
    super(params.message);
    this.name = "ApiError";
    this.response = params.response;
    this.aborted = params.aborted;
    Object.setPrototypeOf(this, ApiError.prototype);
  }
}

type RequestMethod = "GET" | "POST";
type PostBody<T> = BodyInit | undefined | T;
type SearchParams = Record<string, string>;

interface Options {
  baseURL?: string;
}

interface RequestOptions {
  signal?: AbortSignal;
  search?: SearchParams;
}

interface Headers {
  [key: string]: string;
}

interface Paginated {
  pageNumber: number;
  totalPages: number;
}

class APIClient {
  #baseURL = "/api";

  constructor(opts: Options = {}) {
    this.#baseURL = (opts.baseURL || this.#baseURL).replace(/\/$/, "");
  }

  async get<T, R>(path: string, opts: RequestOptions = {}): Promise<R> {
    return this.#request<T, R>("GET", path, undefined, opts);
  }

  async *paginate<T, R extends Paginated>(
    path: string,
    opts: RequestOptions = {},
  ): AsyncGenerator<R> {
    let hasPages = true,
      pageNumber = 1,
      search = opts.search ?? {};

    do {
      const response = await this.get<T, R>(path, {
        ...opts,
        search: { ...search, page: pageNumber.toString() },
      });

      yield response;

      if (response.pageNumber < response.totalPages) {
        pageNumber++;
      } else {
        hasPages = false;
      }
    } while (hasPages);
  }

  async post<T, R>(
    path: string,
    body: PostBody<T>,
    opts: RequestOptions = {},
  ): Promise<R> {
    return this.#request<T, R>("POST", path, body, opts);
  }

  async #request<T, R>(
    method: RequestMethod,
    path: string,
    body: PostBody<T>,
    opts: RequestOptions,
  ): Promise<R> {
    const requestPath = this.#baseURL + path;
    const url = new URL(requestPath, window.location.href);
    url.search = new URLSearchParams(opts?.search ?? {}).toString();

    const headers: Headers = {
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
        throw new ApiError({ message: "Unauthorized", response });
      }

      if (response.status === 403) {
        throw new ApiError({ message: "Forbidden", response });
      }

      return (await response.json()) as R;
    } catch (err) {
      if (err instanceof Error && err.name === "AbortError") {
        throw new ApiError({ message: "Aborted", aborted: true });
      }

      throw err;
    }
  }
}

export const api = new APIClient({
  baseURL: "/api",
});
