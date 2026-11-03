# check=skip=InvalidDefaultArgInFrom
ARG SDK_IMAGE
ARG DOTNET_IMAGE=wodby/dotnet:10.0

FROM ${SDK_IMAGE} AS build
COPY app /src
RUN dotnet publish /src/TestApp.csproj -c Release -o /out

FROM ${DOTNET_IMAGE}
COPY --from=build --chown=wodby:wodby /out /usr/src/app
