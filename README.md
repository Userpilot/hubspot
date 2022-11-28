<div align="center">

<!-- The title and tagline are done in plain HTML instead of Markdown to have ExDoc parse the centring styles properly -->
<h1>Analytex</h1>

<blockquote>

We are what we repeatedly do.

<div style="font-size: 6px; font-weight: light; color: #e6ffff"><em>we may need pick a better tagline</em></div>

</blockquote>

</div>

## Starting up Analytex

This repository is a Mix Umbrella monolithic repository, each folder under the [`apps`](./apps) folder is it's own independent OTP application.

There are 3 primary entry point applications in Analytex,

1. `websocket`, provides Analytex service over WebSockets.
1. `http`, provides Analytex service over a REST HTTP API.
1. `bridge`, provides linking layer to translate next generation analytical data into legacy analytical summary files for consumption by the webapp.

Each one of the 3 entry points internally uses Phoenix framework to provide HTTP/WebSocket APIs.

At least once after cloning the repo, and upon any changes to dependencies you need to run `mix deps.get` to ensure all dependencies are installed and compiled.

To run any specific application you can use any of the following command

```sh
# To run all of Analytex in one batch this will start 3 servers locally
# for each of the applications described before.
mix phx.server

# Opens up an IEx session with all of Analytex modules and dependencies loaded.
iex -S mix

# Starts up all of Analytex servers and then drops you into an IEx session with
# them and all of the rest of Analytex modules and dependencies loaded as well.
iex -S mix phx.server
```

### Analytex configurations

Configurations of Analytex all live under the [`config`](./config) folder, the entrypoint for all configurations is the [`config/config.exs`](./config/config.exs) file, this file is loaded at compile time.

It provides the initial backbone of Analytex configurations, and at the end of it's execution it loads the current environment's respective config file for more specific configurations per each environment.

These environments are controlled by the `MIX_ENV` environment variable, and are

- `dev`, the default environment, used for local development.
- `test`, the default environment when running `mix test`, used for running tests.
- `prod`, the environment used when building the app for staging or production environments.

Each specific environment's config file is found under `config/${MIX_ENV}.exs` and `config/loggers/${MIX_ENV}.exs` (substituting `${MIX_ENV}` with your respective environment).

By default you need to have access to our development product database, which is preconfigured, as well as have a locally running instance of ClickHouse on port `8123` which is what's preconfigured in our case.

### Starting up ClickHouse locally

Our tables are all replicated, ClickHouse setup requires a preconfigured Zookeeper to hold replication metadata. This can either be done manually (good luck with that), or you can simply run our Docker/Compose setup.

> A prerequisite to this is having [Docker](https://docs.docker.com/get-docker/) and [Docker/Compose](https://docs.docker.com/compose/install/) installed in your system, and having Docker up and running.

Run the command following command from the repository root,

```sh
docker-compose -f ./docker/docker-compose.yaml up -d
```

This will open up ClickHouse, Zookeeper, and connect them together, now you have ClickHouse running locally on ports `8123`, and `9000`.

To shutdown the the services run the following command, again from the repository's root.

```sh
docker-compose -f ./docker/docker-compose.yaml down
```

## Documentation

<!-- TODO: -->

### Generate ExDocs

<!-- TODO: -->

```sh
# Generates local version of of our modules' documentations docs
# can be found under the `doc/index.html` as an HTML page.
mix docs
```

## Release

Releases are bound by Git tags that follow semantic versioning, non-prerelease semantic versions trigger production release, while prerelease semantic versions are reserved for non-production purposes.

Currently supported non-production environments are `stg` and `dev`, as such prerelease semantic versions (version suffixes) that are supported are `-dev` and `-stg`, suffixed by any semantic version allowed value. Examples,

- `v1.0.0-dev1`, this would trigger a development release on version `1.0.0-dev1`.
- `v1.0.0-stg1`, this would trigger a staging release on version `1.0.0-stg1`.
- `v1.0.0`, this would trigger a production release on version `1.0.0`.

Version must follow exact [semantic versioning syntax](https://semver.org/#semantic-versioning-specification-semver), otherwise building of the app would fail as Elixir would reject any non-semver value.

Ideally upon the publishing of a production tag, we can create a GitHub release to further document the specific release and have it show up nicely on the repos releases tab. We can additionally name the release and add description of what was released if required. This can help in keeping things organized and tidy.

### Versioning

As we don't really follow SemVer by versioning, but are still required to have valid SemVer to be able to compile, we can use date based versioning that's still compatible for SemVer. The format in use is `<1-2 digit year>.<1-2 digit week of year>.<increment count of releases in the active week>`, an example of this is `21.13.0`.

To get the current version when releasing you can run the following command `date -u +'%-y.%-U.0'`. If the major and minor versions exist, then the patch is set to an increment of the last released version's patch, if either major or minor versions are new, set the patch version to `0`.

For staging releases check the expected production version (assuming a release is being done now), and then just append to it `-rc<increment starting at 1>`, `rc` standing for release candidate. If the version as a whole changes reset the `rc` increment back to `1`.
