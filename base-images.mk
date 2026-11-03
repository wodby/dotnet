# Base image inputs shared by local builds and CI. Each digest identifies the complete
# multi-platform image index. Ordinary images build on the ASP.NET Core runtime and -dev
# images on the .NET SDK whose runtime is the same patch release.
BASE_IMAGE_VERSION_SUFFIX := -alpine3.24
RUNTIME_BASE_IMAGE_REPOSITORY := mcr.microsoft.com/dotnet/aspnet
SDK_BASE_IMAGE_REPOSITORY := mcr.microsoft.com/dotnet/sdk

BASE_IMAGE_DIGEST_aspnet_10.0.14-alpine3.24 := sha256:254fe017495996d3abcc487ffacdcce2b73affb380d3af87af12c8dff41fe0b0
BASE_IMAGE_DIGEST_sdk_10.0.403-alpine3.24 := sha256:cc02b814237a76c4735fb6eeee87181597b5e56f2ce458a435e527674d91f4d7

# Fail before building when a version or variant has no reviewed pin.
pinned_image = $(1):$(2)@$(or $(BASE_IMAGE_DIGEST_$(notdir $(1))_$(2)),$(error No base image digest for $(1):$(2); update base-images.mk))
RUNTIME_IMAGE = $(call pinned_image,$(RUNTIME_BASE_IMAGE_REPOSITORY),$(DOTNET_VER)$(BASE_IMAGE_VERSION_SUFFIX))
SDK_IMAGE = $(call pinned_image,$(SDK_BASE_IMAGE_REPOSITORY),$(DOTNET_SDK_VER)$(BASE_IMAGE_VERSION_SUFFIX))
BASE_IMAGE = $(if $(DOTNET_DEV),$(SDK_IMAGE),$(RUNTIME_IMAGE))
