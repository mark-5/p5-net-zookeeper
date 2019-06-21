.PHONY: default build clean realclean shell test

ROOT = $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
COMPOSE = docker-compose -f $(ROOT)docker-compose.yml

default: build

$(ROOT)Dockerfile: $(ROOT)Dockerfile.PL
	$(ROOT)Dockerfile.PL

build: $(ROOT)Dockerfile
	   $(COMPOSE) build code \
    && $(COMPOSE) up -d zookeeper \
    && $(COMPOSE) run --rm wait-for-it

shell: build
	$(COMPOSE) run --rm code /bin/bash

test: build
	$(COMPOSE) run --rm code /bin/sh -c 'make test TEST_VERBOSE=1'

clean:
	$(COMPOSE) logs zookeeper
	$(COMPOSE) down
	rm $(ROOT)Dockerfile

realclean: clean
	$(COMPOSE) down --rmi local --volumes --remove-orphans

