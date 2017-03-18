# Project setting
PROJECT_NAME := stm32_quest1

TOOLCHAIN_PATH = ./toolchain
ifeq ($(OS),Windows_NT)
include $(TOOLCHAIN_PATH)/Makefile.windows
else
include $(TOOLCHAIN_PATH)/Makefile.posix
endif

MK := mkdir -p
RM := rm -rf

#echo suspend
ifeq ("$(VERBOSE)","1")
NO_ECHO :=
else
NO_ECHO := @
endif

# Toolchain commands
CC              := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-gcc'
AS              := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-as'
AR              := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-ar' -r
LD              := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-ld'
NM              := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-nm'
OBJDUMP         := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-objdump'
OBJCOPY         := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-objcopy'
SIZE            := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-size'
GDB             := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-gdb'

#function for removing duplicates in a list
remduplicates = $(strip $(if $1,$(firstword $1) $(call remduplicates,$(filter-out $(firstword $1),$1))))

# Board/MCU
DEVICE_FAMILY = STM32F4xx
DEVICE_TYPE = STM32F407xx
STARTUP_FILE = stm32f407xx

# CMSIS(Cortex Microcontroller Software Interface Standard)
CMSIS = Drivers/CMSIS
CMSIS_DEVSUP = $(CMSIS)/Device/ST/$(DEVICE_FAMILY)
CMSIS_OPT = -D$(DEVICE_TYPE) -DUSE_HAL_DRIVER
OTHER_OPT = "-D__weak=__attribute__((weak))" "-D__packed=__attribute__((__packed__))"
CPU = -mlittle-endian -mthumb -mcpu=cortex-m4 -mfloat-abi=hard -mfpu=fpv4-sp-d16 -mthumb-interwork

# HAL Driver
HAL_DRIVER = Drivers/$(DEVICE_FAMILY)_HAL_Driver

# Linker
LDSCRIPT = STM32F407VG_FLASH.ld

# DIR
SRCDIR := Src
INCDIR := Inc
LIBDIR := Libs
STARTUPDIR := startup

# OUTPUT DIRECTORY
OBJECT_DIR := build
LISTING_DIR := $(OBJECT_DIR)
OUTPUT_BINARY_DIR := $(OBJECT_DIR)
# Sorting removes duplicates
BUILD_DIR := $(sort $(OBJECT_DIR) $(OUTPUT_BINARY_DIR) $(LISTING_DIR) )

# project c source files
C_SRC_FILES = $(wildcard $(SRCDIR)/*.c)
C_SRC_FILE_NAMES = $(notdir $(C_SRC_FILES))
C_PATHS = $(call remduplicates, $(dir $(C_SRC_FILES) ) )
C_OBJECTS = $(addprefix $(OBJECT_DIR)/, $(C_SRC_FILE_NAMES:.c=.o) )

#assembly files
ASM_SRC_FILES = $(STARTUPDIR)/startup_$(STARTUP_FILE).s
ASM_SRC_FILE_NAMES = $(notdir $(ASM_SRC_FILES))
ASM_PATHS = $(call remduplicates, $(dir $(ASM_SRC_FILES) ))
ASM_OBJECTS = $(addprefix $(OBJECT_DIR)/, $(ASM_SRC_FILE_NAMES:.s=.o) )

OBJECTS = $(C_OBJECTS) $(ASM_OBJECTS)

# library c source file
LIB_SRC_FILES := $(shell find $(HAL_DRIVER)/Src -name *.[cs])
LIB_FILE_NAMES = $(notdir $(LIB_SRC_FILES))
LIB_PATHS = $(call remduplicates, $(dir $(LIB_SRC_FILES) ))
LIB_OBJECTS = $(addprefix $(OBJECT_DIR)/$(LIBDIR)/, $(LIB_FILE_NAMES:.c=.o) )

# INCLUDE
INC_PATHS = -I$(INCDIR)
INC_PATHS += -I$(CMSIS)/Include
INC_PATHS += -I$(HAL_DRIVER)/Inc
INC_PATHS += -I$(CMSIS_DEVSUP)/Include

# CFLAGS
CFLAGS  = $(CPU) $(CMSIS_OPT) $(OTHER_OPT)
CFLAGS += -Wall -fno-common -fno-strict-aliasing -O2
CFLAGS += -Wfatal-errors -g
CFLAGS += --specs=nosys.specs

# ASM FlAGS
ASMFLAGS = $(CFLAGS) -x assembler-with-cpp

LDFLAGS = -Wl,--gc-sections,-Map=$(PROJECT_NAME).map,-cref -T $(LDSCRIPT) $(CPU)

OBJCOPYFLAGS = -Obinary
OBJDUMPFLAGS = -S


# Library file
LIBSTM32 = lib$(DEVICE_FAMILY)_hal.a

LIBS := $(LIBDIR)/$(LIBSTM32)
LIBS += -L$(LIBDIR)
LIBS += -lm
LIBS += -l$(DEVICE_FAMILY)_hal

vpath %.c $(C_PATHS)
vpath %.s $(ASM_PATHS)
vpath %.c $(LIB_PATHS)

# Create objects from C Lib files
$(OBJECT_DIR)/$(LIBDIR)/%.o: %.c
	@echo Compiling file: $(notdir $<)
	$(NO_ECHO)$(CC) $(CFLAGS) $(INC_PATHS) -c -o $@ $<

# Create objects from C SRC files
$(OBJECT_DIR)/%.o: %.c
	@echo Compiling file: $(notdir $<)
	$(NO_ECHO)$(CC) $(CFLAGS) $(INC_PATHS) -c -o $@ $<

# Assemble files
$(OBJECT_DIR)/%.o: %.s
	@echo Assembly file: $(notdir $<)
	$(NO_ECHO)$(CC) $(ASMFLAGS) $(INC_PATHS) -c -o $@ $<

#building all targets
all: library project

clean: library-clean project-clean

help:
	# To do

project: $(PROJECT_NAME).elf

project-clean:
	$(RM) $(BUILD_DIR)

$(PROJECT_NAME).elf: $(BUILD_DIR) $(OBJECTS)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJECTS) $(INC_PATHS) -o $@ $(LIBS)
	$(OBJDUMP) $(OBJDUMPFLAGS) $@ > $(PROJECT_NAME).list
	$(OBJCOPY) -O ihex $@ $(PROJECT_NAME).hex
	$(OBJCOPY) -O binary $@ $(PROJECT_NAME).bin

library-clean:
	$(RM) $(BUILD_DIR)/$(LIBDIR)
	$(RM) $(LIBDIR)/$(LIBSTM32)

$(LIBDIR)/$(LIBSTM32): $(LIBDIR) $(BUILD_DIR) $(LIB_OBJECTS)
	$(AR) $@ $(LIB_OBJECTS)

$(BUILD_DIR)/$(LIBDIR):
	$(MK) $@

$(LIBDIR): $(BUILD_DIR)/$(LIBDIR)
	$(MK) $@

$(BUILD_DIR):
	$(MK) $@

library: $(LIBDIR)/$(LIBSTM32)

reset:

flash:
	st-flash write $(PROJECT_NAME).bin 0x8000000
