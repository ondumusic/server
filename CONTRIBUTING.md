# Contributing
It's great you're thinking about contributing to make Ondu better!

## LLM policy
Currently most of the code in this repo is handmade, but there are some
exceptions here and there. LLM usage is allowed for contributions but please
be transparent about it.

## Front-end: testing and formatting
Currently front-end tests are extremely lacking, but we run these simple checks
in CI to find TypeScript and linting errors, so please remember to do them for
your contributions too.

```sh
cd assets
pnpm tsc -b
pnpm biome check
pnpm test
```

## Back-end: testing and formatting
For Elixir we run a bunch of commands to try and keep the codebase clean.

```sh
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --all --strict
mix dialyzer
mix test
```

## License
By contributing, you agree that your contributions will be licensed under the
same license as this project (see `LICENSE`).

