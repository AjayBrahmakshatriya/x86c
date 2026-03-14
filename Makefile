-include Makefile.inc

BASE_DIR=$(shell pwd)
SRC_DIR=$(BASE_DIR)/src
BUILD_DIR?=$(BASE_DIR)/build
EX_DIR=$(BASE_DIR)/examples

SRCS=$(wildcard $(SRC_DIR)/*.S)
OBJS=$(subst $(SRC_DIR),$(BUILD_DIR),$(SRCS:.S=.o))
EXAMPLES=$(wildcard $(EX_DIR)/*.c)
EXAMPLE_EXECUTABLES=$(subst $(EX_DIR),$(BUILD_DIR)/examples,$(EXAMPLES:.c=))

EXECUTABLE_NAME=$(BUILD_DIR)/x86c

.PHONY: test
.PHONY: run
.PHONY: clean

all: $(EXECUTABLE_NAME)

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.S
	@mkdir -p $(@D)
	gcc $^ -o $@ -c -I $(SRC_DIR)

$(EXECUTABLE_NAME): $(OBJS)
	@mkdir -p $(@D)
	gcc $^ -o $@

$(BUILD_DIR)/examples/%: $(EX_DIR)/%.c $(EXECUTABLE_NAME)
	@mkdir -p $(@D)
	$(EXECUTABLE_NAME) $< $@

test: $(EXAMPLE_EXECUTABLES)

run: test
	@for exec in $(EXAMPLE_EXECUTABLES); do \
		$$exec; \
		echo $$exec \($$?\); \
	done	
clean:
	rm -rf $(BUILD_DIR)
