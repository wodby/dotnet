-include env_make

DOTNET_VER ?= 10.0.15
DOTNET_SDK_VER ?= 10.0.404
DOTNET_VER_MINOR := $(shell v='$(DOTNET_VER)'; echo "$${v%.*}")

REPO = wodby/dotnet
NAME = dotnet-$(DOTNET_VER_MINOR)

PLATFORM ?= linux/arm64

ifeq ($(WODBY_USER_ID),)
    WODBY_USER_ID := 1000
endif

ifeq ($(WODBY_GROUP_ID),)
    WODBY_GROUP_ID := 1000
endif

ifeq ($(TAG),)
	ifneq ($(DOTNET_DEV),)
		TAG := $(DOTNET_VER_MINOR)-dev
		NAME := $(NAME)-dev
	else
		TAG := $(DOTNET_VER_MINOR)
	endif
endif

IMAGETOOLS_TAG ?= $(TAG)

ifneq ($(ARCH),)
	override TAG := $(TAG)-$(ARCH)
endif

.PHONY: build buildx-build buildx-push test push shell run start stop logs clean release buildx-imagetools-create

# Resolve the same pinned base images for every local and CI build target.
include base-images.mk

BUILD_ARGS = --build-arg BASE_IMAGE="$(BASE_IMAGE)" \
	--build-arg DOTNET_DEV=$(DOTNET_DEV) \
	--build-arg WODBY_GROUP_ID=$(WODBY_GROUP_ID) \
	--build-arg WODBY_USER_ID=$(WODBY_USER_ID)

default: build

build:
	docker build $(BUILD_ARGS) -t $(REPO):$(TAG) ./

buildx-build:
	docker buildx build $(BUILD_ARGS) --platform $(PLATFORM) -t $(REPO):$(TAG) --load ./

buildx-push:
	docker buildx build $(BUILD_ARGS) --platform $(PLATFORM) --push -t $(REPO):$(TAG) ./

buildx-imagetools-create:
	docker buildx imagetools create -t $(REPO):$(IMAGETOOLS_TAG) \
				  $(REPO):$(TAG)-amd64 \
				  $(REPO):$(TAG)-arm64

# Every variant runs the application tests: the published test application is built with the
# pinned SDK and run by this image. Development variants also run the workspace tests.
test:
	cd ./tests && IMAGE=$(REPO):$(TAG) bash ./workspace-contract.sh
	cd ./tests && DOTNET_IMAGE=$(REPO):$(TAG) SDK_IMAGE="$(SDK_IMAGE)" DOTNET_VERSION=$(DOTNET_VER) ./run.sh
ifneq ($(DOTNET_DEV),)
	cd ./tests && IMAGE=$(REPO):$(TAG) bash ./workspace-reload.sh
endif

push:
	docker push $(REPO):$(TAG)

shell:
	docker run --rm --name $(NAME) -i -t $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) /bin/bash

run:
	docker run --rm --name $(NAME) $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) $(CMD)

start:
	docker run -d --name $(NAME) $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG)

stop:
	docker stop $(NAME)

logs:
	docker logs $(NAME)

clean:
	cd ./tests && DOTNET_IMAGE=$(REPO):$(TAG) SDK_IMAGE="$(SDK_IMAGE)" docker compose down -v
	-docker rm -f $(NAME)

release: build push

# Keep CI scans aligned with the version, variant and architecture built by make.
.PHONY: image-ref
image-ref:
	@printf '%s\n' '$(REPO):$(TAG)'
