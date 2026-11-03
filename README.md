# .NET Docker Container Images

[![Build Status](https://github.com/wodby/dotnet/workflows/Build%20docker%20image/badge.svg)](https://github.com/wodby/dotnet/actions)
[![Docker Pulls](https://img.shields.io/docker/pulls/wodby/dotnet.svg)](https://hub.docker.com/r/wodby/dotnet)
[![Docker Stars](https://img.shields.io/docker/stars/wodby/dotnet.svg)](https://hub.docker.com/r/wodby/dotnet)

## Table of Contents

- [Docker Images](#docker-images)
    - [`-dev`](#-dev)
    - [`-dev-macos`](#-dev-macos)
    - [Supported architectures](#supported-architectures)
- [Running an application](#running-an-application)
- [Environment Variables](#environment-variables)
- [Build arguments](#build-arguments)
- [Changelog](#changelog)
- [Crond](#crond)
- [SSHD](#sshd)
- [Adding SSH key](#adding-ssh-key)
- [Complete ASP.NET Core stack](#complete-aspnet-core-stack)
- [Orchestration Actions](#orchestration-actions)

## Docker Images

Use image revision tags such as `wodby/dotnet:10.0-rN` to select a Wodby image revision.
Major and minor tags use the repository release number, starting at `r0`. Full-version tags such as
`wodby/dotnet:10.0.14-r0` start at `r0` for each exact upstream version.
Every published versioned revision tag has a matching annotated Git tag pointing to its release commit.
Existing tags remain available after support for their major or minor version ends.
See [release tags](https://github.com/wodby/dotnet/tags) for available revisions and the [image revision policy](https://github.com/wodby/images#image-revisions) for upgrade guidance.

About images:

- All images are based on Alpine Linux
- Base images: [ASP.NET Core Runtime](https://mcr.microsoft.com/product/dotnet/aspnet/about) for ordinary images and [.NET SDK](https://mcr.microsoft.com/product/dotnet/sdk/about) for `-dev` images
- [GitHub actions builds](https://github.com/wodby/dotnet/actions)
- [Docker Hub](https://hub.docker.com/r/wodby/dotnet)

Supported tags and respective `Dockerfile` links:

- `10.0`, `10`, `latest` [_(Dockerfile)_]
- `10.0-dev`, `10-dev`, `dev` [_(Dockerfile)_]
- `10.0-dev-macos`, `10-dev-macos` [_(Dockerfile)_]

[_(Dockerfile)_]: https://github.com/wodby/dotnet/tree/master/Dockerfile

### `-dev`

Images with `-dev` tag contain the .NET SDK, whose runtime is the same patch release as the ordinary image's, and have
`sudo` allowed for all commands for the `wodby` user.

### `-dev-macos`

Same as `-dev` but the default user/group `wodby` has uid/gid `501`/`20` to match the macOS default user/group ids.

### Supported architectures

All images are built for `linux/amd64` and `linux/arm64`.

## Running an application

Ordinary images contain the ASP.NET Core runtime, which includes the .NET runtime, but no SDK. Build the application
with the SDK and copy the output of `dotnet publish` to `/usr/src/app`:

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS build
COPY . /src
RUN dotnet publish /src/MyApp.csproj -c Release -o /out

FROM wodby/dotnet:10.0
COPY --from=build --chown=wodby:wodby /out /usr/src/app
```

The default command, `dotnet-app`, starts the application in `/usr/src/app`: the assembly named by `DOTNET_APP`, or
else the one whose `*.runtimeconfig.json` is the only one there, which `dotnet publish` writes for the entry project.

ASP.NET Core applications listen on port 8080 (`ASPNETCORE_HTTP_PORTS`). The upstream Alpine images run in
globalization-invariant mode because they ship without ICU; these images add ICU with the full culture data and turn
that mode off.

## Environment Variables

| Variable                               | Default value       |
|----------------------------------------|---------------------|
| `APP_ROOT`                             | `/usr/src/app`      |
| `ASPNETCORE_HTTP_PORTS`                | `8080`              |
| `DOTNET_APP`                           |                     |
| `DOTNET_CLI_TELEMETRY_OPTOUT`          | `1`                 |
| `DOTNET_NOLOGO`                        | `1`                 |
| `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT` | `false`            |
| `FILES_DIR`                            | `/mnt/files`        |
| `GIT_USER_EMAIL`                       | `wodby@example.com` |
| `GIT_USER_NAME`                        | `wodby`             |
| `SSH_DISABLE_STRICT_KEY_CHECKING`      |                     |
| `SSH_PRIVATE_KEY`                      |                     |
| `SSHD_GATEWAY_PORTS`                   | `no`                |
| `SSHD_HOST_KEYS_DIR`                   | `/etc/ssh`          |
| `SSHD_LOG_LEVEL`                       | `INFO`              |
| `SSHD_PASSWORD_AUTHENTICATION`         | `no`                |
| `SSHD_PERMIT_USER_ENV`                 | `no`                |
| `SSHD_USE_DNS`                         | `yes`               |

## Build arguments

| Argument         | Default value |
|------------------|---------------|
| `DOTNET_DEV`     |               |
| `WODBY_GROUP_ID` | `1000`        |
| `WODBY_USER_ID`  | `1000`        |

Change `WODBY_USER_ID` and `WODBY_GROUP_ID` mainly for local dev image variants. If either value matches an existing
system user/group id, the existing user/group will be deleted before creating the `wodby` user.

## Changelog

For changes in each image revision, see the [release notes](https://github.com/wodby/dotnet/releases).

## Crond

You can run Crond with this image by changing the command to `sudo -E crond -f -d 0` and mounting a crontab file to
`./crontab:/etc/crontabs/wodby`. Example crontab file contents:

```
# min	hour	day	month	weekday	command
*/1	*	*	*	*	echo "test" > /mnt/files/cron
```

## SSHD

You can run SSHD with this image by changing the command to `sudo /usr/sbin/sshd -De` and mounting authorized public
keys to `/home/wodby/.ssh/authorized_keys`.

## Adding SSH key

You can add a private SSH key to the container by mounting it to `/home/wodby/.ssh/id_rsa`.

## Complete ASP.NET Core stack

See https://github.com/wodby/stack-aspnetcore

## Orchestration Actions

Usage:

```
make COMMAND [params ...]

commands:
    check-ready [host max_try wait_seconds delay_seconds]
    files-import source
    files-link public_dir
```

## Building with pinned base images

Build with the Makefile to use the base image digests in `base-images.mk`. Local builds and CI resolve the same
version and variant to the same multi-platform image. A version without a pin fails before the build starts.
`DOTNET_VER` selects the ASP.NET Core runtime and `DOTNET_SDK_VER` the SDK release that carries the same runtime.

### Development workspace contract

Development variants declare `com.wodby.workspace.contract=1`. Configuration-only startup
(`/docker-entrypoint.sh --configure-runtime`) does not rewrite developer SSH/Git settings, initialize shared storage,
or run application hooks. Normal startup retains its existing behavior. `WODBY_WORKSPACE=1` selects the workspace
startup command. Login-shell tools remain available when the developer home is mounted.

`workspace-dotnet prepare` restores the project's dependencies, and the solution's when there is exactly one
`*.sln` or `*.slnx` at the checkout's root, and restores the local tools of a `dotnet-tools.json` manifest.
`workspace-dotnet start` runs the project with `dotnet watch`: a change to the checkout is applied to the running
application with Hot Reload, or the application is rebuilt and restarted when the change cannot be applied. A build
that fails leaves the running application up and prints the compiler's errors. The checkout is polled, because file
events don't reach a shared volume. Browser refresh is off: it needs a connection from the browser to the container.
`WORKSPACE_DOTNET_WATCH=0` runs the project without watching.

The project is `WORKSPACE_DOTNET_PROJECT`, or the only project file at the checkout's root, or the only one in a
`src/<name>/` directory. When there are several, the only runnable one (a `Microsoft.NET.Sdk.Web` or
`Microsoft.NET.Sdk.Worker` project, or one with `<OutputType>Exe</OutputType>`) is chosen.
`WORKSPACE_DOTNET_COMMAND` overrides startup. `DOTNET_ENVIRONMENT` defaults to `Development` and
`ASPNETCORE_HTTP_PORTS` to `8080`; values set on the service stay as set. With a `packages.lock.json` in the checkout,
`RestoreLockedMode` is set, so a restore fails instead of rewriting the lock file.

NuGet packages (`nuget`) use `.wodby-workspace/` in the shared checkout, so preparation's downloads reach the
application; a `NUGET_PACKAGES` set to anything else stays as set. The cache counts against the checkout's volume and
can be deleted at any time. The directory is excluded through `.git/info/exclude` without editing `.gitignore`.
Build output goes to the projects' `bin/` and `obj/` directories as usual. A tracked directory or symlink at the
reserved path is refused. MSBuild targets and package scripts remain application-owned and may modify files; review
Git changes after preparation.

CI checks labels for all image variants, runs the published test application on every variant, and runs
configuration, developer-state, reserved-path and runtime tests for development variants. Publish a new image
revision before enabling this contract in a consuming service.
