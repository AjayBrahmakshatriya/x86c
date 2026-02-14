-include Makefile.inc

BASE_DIR=$(shell pwd)
SRC_DIR=$(BASE_DIR)/src
BUILD_DIR?=$(BASE_DIR)/build

SRCS=$(wildcard $(SRC_DIR)/*.S)
OBJS=$(subst $(SRC_DIR),$(BUILD_DIR),$(SRCS:.S=.o))


EXECUTABLE_NAME=$(BUILD_DIR)/x86c

all: $(EXECUTABLE_NAME)

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.S
	mkdir -p $(@D)
	gcc $^ -o $@ -c -I $(SRC_DIR)

$(EXECUTABLE_NAME): $(OBJS)
	mkdir -p $(@D)
	gcc $^ -o $@

