#!/usr/bin/env bash
# A change another container writes to the shared checkout is served without restarting the
# container, a build that fails leaves the running application up, and stopping the
# container stops the application. This does not substitute for cross-node NFS acceptance.
set -euo pipefail
volume="workspace-dotnet-reload-$$"
server="workspace-dotnet-reload-server-$$"
docker volume create "$volume" >/dev/null
cleanup() { docker rm -f "$server" >/dev/null 2>&1 || true; docker volume rm "$volume" >/dev/null; }
trap cleanup EXIT
image="${IMAGE:?Set IMAGE to the candidate .NET development image}"
# Run as the image's own user: the checkout belongs to it in a workspace.
write() { docker run --rm -i --network none --entrypoint sh -v "$volume:/fixture" "$image" -ec "$1"; }
docker run --rm --user 0 --entrypoint sh -v "$volume:/fixture" "$image" -ec 'chown "$(id -u wodby):$(id -g wodby)" /fixture'
write '
cd /fixture
git init -q
cat > Reload.csproj <<XML
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
</Project>
XML
cat > Program.cs <<CS
var app = WebApplication.Create(args);
app.MapGet("/", () => Messages.Greeting());
app.MapGet("/environment", (IWebHostEnvironment environment) => environment.EnvironmentName);
app.Run();

static class Messages
{
    public static string Greeting() => "before-edit";
}
CS
'
start() { docker run -d --name "$server" --network none --entrypoint /usr/local/bin/workspace-dotnet -e APP_ROOT=/fixture "$@" -v "$volume:/fixture" "$image" start >/dev/null; }
get() { docker exec "$server" wget -qO- "http://127.0.0.1:8080$1" 2>/dev/null; }
# Waits until a path answers with the wanted text; prints the server's log when it never does.
serves() {
 for _ in $(seq 1 150); do
  if [ "$(get "$1" || true)" = "$2" ]; then return 0; fi
  sleep 1
 done
 echo "$1 never answered $2" >&2; docker logs "$server" >&2; exit 1
}
start
serves / before-edit
serves /environment Development
first=$(docker inspect -f '{{.State.StartedAt}}' "$server")

write 'sed -i "s/before-edit/after-edit/" /fixture/Program.cs'
serves / after-edit
echo 'dotnet: a change to the source was served'

# A build that fails must not take the running application down.
write 'sed -i "s/=> \"after-edit\";/=> \"broken\"/" /fixture/Program.cs'
sleep 15
serves / after-edit
echo 'dotnet: a failed build left the running application up'

write 'sed -i "s/=> \"broken\"/=> \"fixed\";/" /fixture/Program.cs'
serves / fixed
echo 'dotnet: a fixed build was served'

# All of that happened in one container.
test "$(docker inspect -f '{{.State.StartedAt}} {{.RestartCount}}' "$server")" = "$first 0"

# Stopping the container stops the application without waiting for the kill timeout.
began=$(date +%s)
docker stop -t 30 "$server" >/dev/null
test $(( $(date +%s) - began )) -lt 15
docker rm -f "$server" >/dev/null
echo 'dotnet: stopping the container stopped the application'

# Without watching the application runs as built.
start -e WORKSPACE_DOTNET_WATCH=0
serves / fixed
write 'sed -i "s/=> \"fixed\";/=> \"unwatched\";/" /fixture/Program.cs'
sleep 10
test "$(get /)" = fixed
echo 'dotnet: WORKSPACE_DOTNET_WATCH=0 runs the application without a watcher'
