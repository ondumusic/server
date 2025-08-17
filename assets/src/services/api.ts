interface ApiErrorArguments {
  message: string;
  response: Response;
}

export class ApiError extends Error {
  response: Response;

  constructor(params: ApiErrorArguments) {
    super(params.message);
    this.name = "ApiError";
    this.response = params.response;
    Object.setPrototypeOf(this, ApiError.prototype);
  }
}

type RequestMethod = "GET" | "POST";
type PostBody<T> = BodyInit | undefined | T;
type SearchParams = Record<string, string>;

interface Options {
  baseURL?: string;
}

interface Headers {
  [key: string]: string;
}

class APIClient {
  #baseURL = "/api";

  constructor(opts: Options = {}) {
    this.#baseURL = (opts.baseURL || this.#baseURL).replace(/\/$/, "");
  }

  async get<T, R>(path: string, search: SearchParams = {}): Promise<R> {
    return this.#request<T, R>("GET", path, undefined, search);
  }

  async post<T, R>(
    path: string,
    body: PostBody<T>,
    search: SearchParams = {},
  ): Promise<R> {
    return this.#request<T, R>("POST", path, body, search);
  }

  async #request<T, R>(
    method: RequestMethod,
    path: string,
    body: PostBody<T>,
    search: SearchParams,
  ): Promise<R> {
    const requestPath = this.#baseURL + path;
    const url = new URL(requestPath, window.location.href);
    url.search = new URLSearchParams(search).toString();

    const headers: Headers = {
      "Content-Type": "application/json",
      Accept: "application/json",
    };

    // TODO: Move this into separate auth service
    const { sessionToken } = localStorage;
    if (sessionToken) {
      headers.Authorization = `Bearer ${sessionToken}`;
    }

    if (typeof body === "object") {
      body = JSON.stringify(body);
    }

    const response = await fetch(url.toString(), {
      body: body as BodyInit,
      method,
      headers,
      credentials: "omit",
    });

    if (response.status === 401) {
      throw new ApiError({ message: "Unauthorized", response });
    }

    if (response.status === 403) {
      throw new ApiError({ message: "Forbidden", response });
    }

    return (await response.json()) as R;
  }
}

export const api = new APIClient({
  baseURL: "/api",
});
