# Modify this variable to fit your NEORV32 setup (neorv32 home folder)
NEORV32_HOME = ../lib/neorv32

# Compiler toolchain
RISCV_PREFIX = riscv32-unknown-elf-

# CPU architecture
MARCH = rv32ia_zicsr

# Count of CPU HARTS
NUM_HARTS = 4

# FreeRTOS kernel home folder
FREERTOS_HOME = ../lib/FreeRTOS-Kernel

# User flags for additional configuration (will be added to compiler flags)
USER_FLAGS := $(CLI_FLAGS)
USER_FLAGS += -Wl,--defsym,__neorv32_rom_size=16K
USER_FLAGS += -Wl,--defsym,__neorv32_ram_size=32M
USER_FLAGS += -Wl,--defsym,__neorv32_stack_size=8K
USER_FLAGS += -Wl,--defsym,__neorv32_num_harts=$(NUM_HARTS)
USER_FLAGS += -Wl,--defsym,__neorv32_heap_size=4M
USER_FLAGS += -Og

# Build in SMP mode if NUM_HARTS > 1.
ifneq (1,$(NUM_HARTS))
USER_FLAGS += -DSMP
endif
USER_FLAGS += -DNUM_HARTS=$(NUM_HARTS)

# Change flags if we are building for the simulation.
ifneq (,$(findstring SIMULATION,$(USER_FLAGS)))
USER_FLAGS += -DUART0_SIM_MODE
USER_FLAGS += -DUART1_SIM_MODE
endif

# Add application sources
APP_SRC += $(wildcard ./src/*.c) $(wildcard ./src/*.s) $(wildcard ./src/*.cpp) $(wildcard ./src/*.S)
APP_INC += -I ./include
ASM_INC += -I ./include

# Add FreeRTOS sources
APP_SRC += $(wildcard $(FREERTOS_HOME)/*.c)
APP_INC += -I $(FREERTOS_HOME)/include
APP_SRC += $(wildcard  $(FREERTOS_HOME)/portable/GCC/RISC-V/*.c)
APP_SRC +=  $(FREERTOS_HOME)/portable/GCC/RISC-V/portASM.S
APP_INC += -I  $(FREERTOS_HOME)/portable/GCC/RISC-V
APP_SRC += $(wildcard  $(FREERTOS_HOME)/portable/MemMang/heap_4.c)

# Include the common neorv32 buildsystem. Provides targets like exe, bin etc.
include $(NEORV32_HOME)/sw/common/common.mk

# Extend buildsystem with custom targets.
GDB = $(RISCV_PREFIX)gdb
OCD = /opt/aji_openocd/openocd

PHONY: flash debug

# Flash the program with OpenOCD and GDB to the SoC.
flash: exe
	$(OCD) -f ./openocd_target.cfg &
	$(GDB) -x ./gdb_flash.cfg
	pkill openocd

# Flash the program to the SoC and start cli debugging session.
debug: exe
	$(OCD) -f ./openocd_target.cfg &
	$(GDB) -x ./gdb_debug.cfg
	pkill openocd
