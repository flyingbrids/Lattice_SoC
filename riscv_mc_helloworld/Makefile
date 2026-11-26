PROPEL_HOME ?= C:/lscc/propel/2025.1
SDK_ROOT := $(PROPEL_HOME)/sdk
BUILD_TOOLS := $(SDK_ROOT)/build_tools/bin
RISCV_BIN := $(SDK_ROOT)/riscv-none-embed-gcc/bin
TOOLS_BIN := $(SDK_ROOT)/tools/bin

SHELL := $(BUILD_TOOLS)/sh.exe
MKDIR := "$(BUILD_TOOLS)/mkdir.exe"
RM := "$(BUILD_TOOLS)/rm.exe"
CC := "$(RISCV_BIN)/riscv-none-embed-gcc.exe"
OBJCOPY := "$(RISCV_BIN)/riscv-none-embed-objcopy.exe"
OBJDUMP := "$(RISCV_BIN)/riscv-none-embed-objdump.exe"
SIZE := "$(RISCV_BIN)/riscv-none-embed-size.exe"
SREC_CAT := "$(TOOLS_BIN)/srec_cat.exe"

BUILD_DIR ?= build
APP_NAME := riscv_mc_helloworld

INCLUDE_DIRS := \
	src \
	src/bsp \
	src/bsp/driver \
	src/bsp/driver/gpio \
	src/bsp/driver/riscv_mc \
	src/bsp/driver/uart

C_SOURCES := $(wildcard \
	src/*.c \
	src/bsp/*.c \
	src/bsp/driver/gpio/*.c \
	src/bsp/driver/riscv_mc/*.c \
	src/bsp/driver/uart/*.c)
ASM_SOURCES := $(wildcard src/bsp/driver/riscv_mc/*.S)
OBJECTS := \
	$(patsubst src/%.c,$(BUILD_DIR)/%.o,$(C_SOURCES)) \
	$(patsubst src/%.S,$(BUILD_DIR)/%.o,$(ASM_SOURCES))
DEPS := $(OBJECTS:.o=.d)

ELF := $(BUILD_DIR)/$(APP_NAME).elf
BIN := $(BUILD_DIR)/$(APP_NAME).bin
MEM := $(BUILD_DIR)/$(APP_NAME).mem
LIST := $(BUILD_DIR)/$(APP_NAME).lst

COMMON_FLAGS := -march=rv32ic -mabi=ilp32 -msmall-data-limit=8 \
	-mno-save-restore -O0 -fmessage-length=0 -fsigned-char \
	-ffunction-sections -fdata-sections -Wframe-larger-than=2560 -g3
CPP_FLAGS := $(addprefix -I,$(INCLUDE_DIRS)) -DLSCC_STDIO_UART_APB
C_FLAGS := $(COMMON_FLAGS) $(CPP_FLAGS) -std=gnu11 \
	--specs=picolibc.specs -DPICOLIBC_INTEGER_PRINTF_SCANF
LINK_FLAGS := $(COMMON_FLAGS) -T src/linker.ld -nostartfiles \
	-Xlinker --gc-sections -Wl,-Map,$(BUILD_DIR)/$(APP_NAME).map \
	--specs=picolibc.specs -DPICOLIBC_INTEGER_PRINTF_SCANF

.PHONY: all clean

all: $(ELF) $(BIN) $(MEM)

$(BUILD_DIR)/%.o: src/%.c Makefile
	$(MKDIR) -p "$(@D)"
	$(CC) $(C_FLAGS) -MMD -MP -MF"$(@:.o=.d)" -MT"$@" -c -o "$@" "$<"

$(BUILD_DIR)/%.o: src/%.S Makefile
	$(MKDIR) -p "$(@D)"
	$(CC) $(COMMON_FLAGS) -x assembler-with-cpp -MMD -MP \
		-MF"$(@:.o=.d)" -MT"$@" -c -o "$@" "$<"

$(ELF): $(OBJECTS) src/linker.ld
	$(CC) $(LINK_FLAGS) -o "$@" $(OBJECTS)

$(BIN): $(ELF)
	$(OBJCOPY) -O binary --gap-fill 0 "$<" "$@"

$(MEM): $(BIN)
	$(SREC_CAT) "$<" -Binary -byte-swap 4 -Disable Header -Output "$@" -MEM 32

$(LIST): $(ELF)
	$(OBJDUMP) --source --all-headers --demangle --line-numbers --wide "$<" > "$@"

size: $(ELF)
	$(SIZE) --format=berkeley "$<"

clean:
	$(RM) -rf "$(BUILD_DIR)"

-include $(DEPS)
