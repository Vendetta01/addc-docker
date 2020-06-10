
REGISTRY:=npodewitz
IMAGE_NAME:=addc
CONTAINER_NAME:=${IMAGE_NAME}
DOCKER_RUN_ARGS:=--rm --cap-add SYS_ADMIN --hostname addc.podewitz.de -e LOG_LEVEL="debug"
VERSION:=


.PHONY: build build-nc build-debug run debug debug-exec stop up up-debug clean ldap-test all

all: build

build:
	docker build -t ${IMAGE_NAME} .
	docker tag ${IMAGE_NAME} ${REGISTRY}/${IMAGE_NAME}:latest

build-nc:
	docker build --no-cache -t ${IMAGE_NAME} .
	docker tag ${IMAGE_NAME} ${REGISTRY}/${IMAGE_NAME}:latest

run:
	docker run -it --name ${CONTAINER_NAME} ${DOCKER_RUN_ARGS} ${IMAGE_NAME}

debug:
	docker run -it --name ${CONTAINER_NAME} ${DOCKER_RUN_ARGS} ${IMAGE_NAME} /bin/bash

debug-exec:
	docker exec -it ${CONTAINER_NAME} /bin/bash

stop:
	-docker stop ${CONTAINER_NAME}

up: clean build run

up-debug: clean build-debug run

clean: stop
	-docker rm -v ${CONTAINER_NAME}
