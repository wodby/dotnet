# Base image inputs shared by local builds and CI. Each digest identifies the complete
# multi-platform image index. Ordinary images build on the ASP.NET Core runtime and -dev
# images on the .NET SDK whose runtime is the same patch release.
BASE_IMAGE_VERSION_SUFFIX := -alpine3.24
RUNTIME_BASE_IMAGE_REPOSITORY := mcr.microsoft.com/dotnet/aspnet
SDK_BASE_IMAGE_REPOSITORY := mcr.microsoft.com/dotnet/sdk

BASE_IMAGE_DIGEST_aspnet_10.0.15-alpine3.24 := sha256:21c3f9798416cba4c0576a947c286231cb71ea2884896cb968253f5c9668f930
BASE_IMAGE_DIGEST_sdk_10.0.404-alpine3.24 := sha256:0294f285d062afacc8b5f6d7febb0cd4ee879320e5585fa15f2f4ebf1feb9ba7

# Fail before building when a version or variant has no reviewed pin.
pinned_image = $(1):$(2)@$(or $(BASE_IMAGE_DIGEST_$(notdir $(1))_$(2)),$(error No base image digest for $(1):$(2); update base-images.mk))
RUNTIME_IMAGE = $(call pinned_image,$(RUNTIME_BASE_IMAGE_REPOSITORY),$(DOTNET_VER)$(BASE_IMAGE_VERSION_SUFFIX))
SDK_IMAGE = $(call pinned_image,$(SDK_BASE_IMAGE_REPOSITORY),$(DOTNET_SDK_VER)$(BASE_IMAGE_VERSION_SUFFIX))
BASE_IMAGE = $(if $(DOTNET_DEV),$(SDK_IMAGE),$(RUNTIME_IMAGE))
