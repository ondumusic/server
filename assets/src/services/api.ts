type RequestMethod = "GET";

type SearchParams = Record<string, string>;

interface Options {
  baseURL?: string;
}

class APIClient {
  #baseURL = "/api";

  constructor(opts: Options = {}) {
    this.#baseURL = (opts.baseURL || this.#baseURL).replace(/\/$/, "");
  }

  get(path: string, search: SearchParams = {}) {
    return this.#request("GET", path, search);
  }

  #request(method: RequestMethod, path: string, search: SearchParams) {
    const requestPath = this.#baseURL + path;
    const url = new URL(requestPath, window.location.href);
    url.search = new URLSearchParams(search).toString();

    return fetch(url.toString(), {
      method,
      credentials: "omit",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
      },
    }).then((res) => res.json());
  }
}

export const api = new APIClient({
  baseURL: "/api",
});
