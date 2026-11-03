#!/usr/bin/env bash
# Run inside the image with the normal entrypoint bypassed and without a network.
set -euo pipefail
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/repo" "$fixture/home/.ssh" "$fixture/empty"
export APP_ROOT="$fixture/repo" HOME="$fixture/home"
printf 'Host saved\n' > "$HOME/.ssh/config"
printf '[user]\n  name = Developer\n' > "$HOME/.gitconfig"
cp "$HOME/.ssh/config" "$fixture/ssh.expected"
cp "$HOME/.gitconfig" "$fixture/git.expected"
# Configuration succeeds repeatedly without running storage/init or identity setup.
/docker-entrypoint.sh --configure-runtime
/docker-entrypoint.sh --configure-runtime
cmp "$HOME/.ssh/config" "$fixture/ssh.expected"
cmp "$HOME/.gitconfig" "$fixture/git.expected"
bash -lc 'command -v dotnet' >/dev/null
# The default command refuses a directory without a published application.
if APP_ROOT="$fixture/empty" dotnet-app 2>"$fixture/err"; then echo 'started without an application' >&2; exit 1; fi
grep -q 'no published application' "$fixture/err"
touch "$fixture/empty/One.runtimeconfig.json" "$fixture/empty/Two.runtimeconfig.json"
if APP_ROOT="$fixture/empty" dotnet-app 2>"$fixture/err"; then echo 'chose between two applications' >&2; exit 1; fi
grep -q 'set DOTNET_APP' "$fixture/err"
if [ -z "${DOTNET_DEV:-}" ]; then
    echo 'Runtime checks passed'
    exit 0
fi

cd "$APP_ROOT"
git init -q
printf 'tracked\n' > source.txt
git add source.txt
workspace-path > "$fixture/path"
test "$(cat "$fixture/path")" = "$APP_ROOT/.wodby-workspace"
test -z "$(git ls-files --others --exclude-standard)"
# A tracked collision is refused, even when local exclude rules hide new files.
printf collision > .wodby-workspace/collision
git add -f .wodby-workspace/collision
if workspace-path; then echo 'accepted tracked runtime storage' >&2; exit 1; fi
git rm -q --cached .wodby-workspace/collision
rm .wodby-workspace/collision
state="$APP_ROOT/.wodby-workspace"

# Without a project there is nothing to run.
if workspace-dotnet prepare 2>"$fixture/err"; then echo 'prepared without a project' >&2; exit 1; fi
grep -q 'found 0 runnable projects' "$fixture/err"

# A runnable project in src/<name>/ is found next to a library; restore and run need no network.
mkdir -p src/Hello src/Library
cat > src/Hello/Hello.csproj <<'XML'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
  </PropertyGroup>
</Project>
XML
printf 'System.Console.Write($"before {System.Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT")}");\n' > src/Hello/Program.cs
cat > src/Library/Library.csproj <<'XML'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
  </PropertyGroup>
</Project>
XML
git add src
cp src/Hello/Hello.csproj "$fixture/csproj.expected"
workspace-dotnet prepare
test -f src/Hello/obj/project.assets.json
WORKSPACE_DOTNET_WATCH=0 workspace-dotnet start > "$fixture/out"
grep -q 'before Development' "$fixture/out"
# A value set on the service stays as set.
DOTNET_ENVIRONMENT=Staging WORKSPACE_DOTNET_WATCH=0 workspace-dotnet start > "$fixture/out"
grep -q 'before Staging' "$fixture/out"

# NuGet's packages are kept with the checkout, not in the container's home, which a
# restart discards; a custom start command gets the same cache. A cache set to anything
# else stays as set.
test "$(WORKSPACE_DOTNET_COMMAND='printf %s "$NUGET_PACKAGES"' workspace-dotnet start)" = "$state/nuget"
test "$(NUGET_PACKAGES="$fixture/nuget" WORKSPACE_DOTNET_COMMAND='printf %s "$NUGET_PACKAGES"' workspace-dotnet start)" = "$fixture/nuget"
test -z "$(git ls-files --others --exclude-standard -- .wodby-workspace)"

# A NuGet lock file makes every restore refuse to rewrite it.
test -z "$(WORKSPACE_DOTNET_COMMAND='printf %s "${RestoreLockedMode:-}"' workspace-dotnet start)"
printf '{"version": 1, "dependencies": {}}\n' > src/Hello/packages.lock.json
test "$(WORKSPACE_DOTNET_COMMAND='printf %s "${RestoreLockedMode:-}"' workspace-dotnet start)" = true
rm src/Hello/packages.lock.json

# Two runnable projects need a choice.
mkdir -p src/Other
cp src/Hello/Hello.csproj src/Other/Other.csproj
printf 'System.Console.Write("other");\n' > src/Other/Program.cs
if workspace-dotnet prepare 2>"$fixture/err"; then echo 'chose between two runnable projects' >&2; exit 1; fi
grep -q 'found 2 runnable projects' "$fixture/err"
WORKSPACE_DOTNET_PROJECT=src/Other/Other.csproj workspace-dotnet prepare
WORKSPACE_DOTNET_PROJECT=src/Other/Other.csproj WORKSPACE_DOTNET_WATCH=0 workspace-dotnet start > "$fixture/out"
grep -q '^other$' "$fixture/out"
rm -rf src/Other

# The entrypoint starts the workspace command in a workspace.
sed -i 's/before/after/' src/Hello/Program.cs
WODBY_WORKSPACE=1 WORKSPACE_DOTNET_WATCH=0 /docker-entrypoint.sh ignored > "$fixture/out"
grep -q 'after Development' "$fixture/out"
cmp src/Hello/Hello.csproj "$fixture/csproj.expected"
cmp "$HOME/.ssh/config" "$fixture/ssh.expected"
cmp "$HOME/.gitconfig" "$fixture/git.expected"
echo 'Workspace runtime checks passed'
