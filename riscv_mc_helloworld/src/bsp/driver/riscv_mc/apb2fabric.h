#ifndef APB2FABRIC_H
#define APB2FABRIC_H

#include <stdint.h>

/* The hardware implements 50 registers; each register occupies 2 bytes. */
#define APB2FABRIC_REGISTER_WINDOW_BYTES 512U
#define APB2FABRIC_REGISTER_COUNT 50U
#define APB2FABRIC_SPI_BRAM_OFFSET 512U
#define APB2FABRIC_SPI_BRAM_BYTES 512U
#define APB2FABRIC_SPI_BRAM_WORD_COUNT (APB2FABRIC_SPI_BRAM_BYTES / 4U)

typedef enum {
	APB2FABRIC_REG_VERSION = 0,
	APB2FABRIC_REG_SERIAL = 1,
	APB2FABRIC_REG_TYPE = 2,
	APB2FABRIC_REG_RST_HIST = 3,
	APB2FABRIC_REG_START_HIST = 4,
	APB2FABRIC_REG_STOP_HIST = 5,
	APB2FABRIC_REG_LLD = 6,
	APB2FABRIC_REG_ULD = 7,
	APB2FABRIC_REG_THRESHOLD = 8,
	APB2FABRIC_REG_ROI = 9,
	APB2FABRIC_REG_DEAD_LOW = 10,
	APB2FABRIC_REG_DEAD_HIGH = 11,
	APB2FABRIC_REG_LIVE_LOW = 12,
	APB2FABRIC_REG_LIVE_HIGH = 13,
	APB2FABRIC_REG_REAL_LOW = 14,
	APB2FABRIC_REG_REAL_HIGH = 15,
	APB2FABRIC_REG_HV_FEEDBACK = 16,
	APB2FABRIC_REG_HV = 17,
	APB2FABRIC_REG_GAIN = 18,
	APB2FABRIC_REG_HIST = 19,
	APB2FABRIC_REG_MODE = 20,
	APB2FABRIC_REG_RESERVED_21 = 21,
	APB2FABRIC_REG_RESERVED_22 = 22,
	APB2FABRIC_REG_RESERVED_23 = 23,
	APB2FABRIC_REG_RESERVED_24 = 24,
	APB2FABRIC_REG_ZONE1 = 25,
	APB2FABRIC_REG_ZONE2 = 26,
	APB2FABRIC_REG_ZONE3 = 27,
	APB2FABRIC_REG_ZONE_SET = 28,
	APB2FABRIC_REG_ZONE4 = 29,
	APB2FABRIC_REG_ZONE5 = 30,
	APB2FABRIC_REG_ZONE6 = 31,
	APB2FABRIC_REG_SDI_LOW = 32,
	APB2FABRIC_REG_SDI_HIGH = 33,
	APB2FABRIC_REG_PZ = 34,
	APB2FABRIC_REG_A_LOW = 35,
	APB2FABRIC_REG_A_HIGH = 36,
	APB2FABRIC_REG_B_LOW = 37,
	APB2FABRIC_REG_B_HIGH = 38,
	APB2FABRIC_REG_C = 39,
	APB2FABRIC_REG_D = 40,
	APB2FABRIC_REG_INITIAL_GAIN = 41,
	APB2FABRIC_REG_GAIN_STAB = 42,
	APB2FABRIC_REG_GATE_WIDTH = 43,
	APB2FABRIC_REG_ADC_CONTROL = 44,
	APB2FABRIC_REG_ADC_STATUS = 45,
	APB2FABRIC_REG_TEMPERATURE = 46,
	APB2FABRIC_REG_SPI_BYTE_COUNT = 47,
	APB2FABRIC_REG_SPI_CONTROL = 48,
	APB2FABRIC_REG_SPI_STATUS = 49
} apb2fabric_reg_index_t;

typedef enum {
	APB2FABRIC_STATUS_OK = 0,
	APB2FABRIC_STATUS_INVALID_ARGUMENT,
	APB2FABRIC_STATUS_OUT_OF_RANGE
} apb2fabric_status_t;

typedef enum {
	APB2FABRIC_RW_CHECK_OK = 0,
	APB2FABRIC_RW_CHECK_READ_ERROR,
	APB2FABRIC_RW_CHECK_WRITE_ERROR,
	APB2FABRIC_RW_CHECK_MISMATCH,
	APB2FABRIC_RW_CHECK_RESTORE_ERROR
} apb2fabric_rw_check_status_t;

/* Register indices are halfword slots: byte address = base + reg_index * 2. */
apb2fabric_status_t apb2fabric_reg_read(uint16_t reg_index, uint16_t *value);
apb2fabric_status_t apb2fabric_reg_write(uint16_t reg_index, uint16_t value);

/*
 * Tests writable registers with a temporary bit-0 change, then restores them.
 * Command registers that trigger histogram/SPI actions are intentionally skipped.
 */
apb2fabric_rw_check_status_t apb2fabric_check_rw_registers(
		uint16_t *failed_reg_index);

/* Byte writes are non-atomic; avoid them while the SPI engine accesses BRAM. */
apb2fabric_status_t apb2fabric_spi_bram_read_word(uint16_t word_index,
		uint32_t *value);
apb2fabric_status_t apb2fabric_spi_bram_write_word(uint16_t word_index,
		uint32_t value);
apb2fabric_status_t apb2fabric_spi_bram_read_byte(uint16_t byte_offset,
		uint8_t *value);
apb2fabric_status_t apb2fabric_spi_bram_write_byte(uint16_t byte_offset,
		uint8_t value);

#endif
