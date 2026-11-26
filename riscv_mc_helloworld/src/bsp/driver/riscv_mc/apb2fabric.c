#include "apb2fabric.h"

#include <stddef.h>
#include "sys_platform.h"

static const uint16_t rw_register_indices[] = {
	APB2FABRIC_REG_LLD,
	APB2FABRIC_REG_ULD,
	APB2FABRIC_REG_THRESHOLD,
	APB2FABRIC_REG_HV,
	APB2FABRIC_REG_GAIN,
	APB2FABRIC_REG_HIST,
	APB2FABRIC_REG_MODE,
	APB2FABRIC_REG_RESERVED_21,
	APB2FABRIC_REG_RESERVED_22,
	APB2FABRIC_REG_RESERVED_23,
	APB2FABRIC_REG_RESERVED_24,
	APB2FABRIC_REG_ZONE1,
	APB2FABRIC_REG_ZONE2,
	APB2FABRIC_REG_ZONE3,
	APB2FABRIC_REG_ZONE_SET,
	APB2FABRIC_REG_ZONE4,
	APB2FABRIC_REG_ZONE5,
	APB2FABRIC_REG_ZONE6,
	APB2FABRIC_REG_PZ,
	APB2FABRIC_REG_A_LOW,
	APB2FABRIC_REG_A_HIGH,
	APB2FABRIC_REG_B_LOW,
	APB2FABRIC_REG_B_HIGH,
	APB2FABRIC_REG_C,
	APB2FABRIC_REG_D,
	APB2FABRIC_REG_INITIAL_GAIN,
	APB2FABRIC_REG_GAIN_STAB,
	APB2FABRIC_REG_GATE_WIDTH,
	APB2FABRIC_REG_ADC_CONTROL,
	APB2FABRIC_REG_SPI_BYTE_COUNT
};

static uintptr_t register_address(uint16_t reg_index)
{
	return (uintptr_t)APB2FABRIC_INST_BASE_ADDR +
			((uintptr_t)reg_index * 2U);
}

apb2fabric_rw_check_status_t apb2fabric_check_rw_registers(
		uint16_t *failed_reg_index)
{
	for (size_t i = 0; i < sizeof(rw_register_indices) /
			sizeof(rw_register_indices[0]); ++i)
	{
		uint16_t reg_index = rw_register_indices[i];
		uint16_t original;
		uint16_t expected;
		uint16_t actual;
		apb2fabric_rw_check_status_t result = APB2FABRIC_RW_CHECK_OK;

		if (apb2fabric_reg_read(reg_index, &original) !=
				APB2FABRIC_STATUS_OK) {
			result = APB2FABRIC_RW_CHECK_READ_ERROR;
		} else {
			expected = (uint16_t)(original ^ 0x0001U);
			if (apb2fabric_reg_write(reg_index, expected) !=
					APB2FABRIC_STATUS_OK) {
				result = APB2FABRIC_RW_CHECK_WRITE_ERROR;
			} else if (apb2fabric_reg_read(reg_index, &actual) !=
					APB2FABRIC_STATUS_OK) {
				result = APB2FABRIC_RW_CHECK_READ_ERROR;
			} else if (actual != expected) {
				result = APB2FABRIC_RW_CHECK_MISMATCH;
			}

			if (apb2fabric_reg_write(reg_index, original) !=
					APB2FABRIC_STATUS_OK) {
				result = APB2FABRIC_RW_CHECK_RESTORE_ERROR;
			}
		}

		if (result != APB2FABRIC_RW_CHECK_OK) {
			if (failed_reg_index != NULL)
				*failed_reg_index = reg_index;
			return result;
		}

	}

	if (failed_reg_index != NULL)
		*failed_reg_index = UINT16_MAX;
	return APB2FABRIC_RW_CHECK_OK;
}

static uintptr_t spi_bram_word_address(uint16_t word_index)
{
	return (uintptr_t)APB2FABRIC_INST_BASE_ADDR +
			APB2FABRIC_SPI_BRAM_OFFSET +
			((uintptr_t)word_index * 4U);
}

apb2fabric_status_t apb2fabric_reg_read(uint16_t reg_index, uint16_t *value)
{
	if (value == NULL)
		return APB2FABRIC_STATUS_INVALID_ARGUMENT;
	if (reg_index >= APB2FABRIC_REGISTER_COUNT)
		return APB2FABRIC_STATUS_OUT_OF_RANGE;

	*value = *(volatile uint16_t *)register_address(reg_index);
	return APB2FABRIC_STATUS_OK;
}

apb2fabric_status_t apb2fabric_reg_write(uint16_t reg_index, uint16_t value)
{
	if (reg_index >= APB2FABRIC_REGISTER_COUNT)
		return APB2FABRIC_STATUS_OUT_OF_RANGE;

	*(volatile uint16_t *)register_address(reg_index) = value;
	return APB2FABRIC_STATUS_OK;
}

apb2fabric_status_t apb2fabric_spi_bram_read_word(uint16_t word_index,
		uint32_t *value)
{
	if (value == NULL)
		return APB2FABRIC_STATUS_INVALID_ARGUMENT;
	if (word_index >= APB2FABRIC_SPI_BRAM_WORD_COUNT)
		return APB2FABRIC_STATUS_OUT_OF_RANGE;

	*value = *(volatile uint32_t *)spi_bram_word_address(word_index);
	return APB2FABRIC_STATUS_OK;
}

apb2fabric_status_t apb2fabric_spi_bram_write_word(uint16_t word_index,
		uint32_t value)
{
	if (word_index >= APB2FABRIC_SPI_BRAM_WORD_COUNT)
		return APB2FABRIC_STATUS_OUT_OF_RANGE;

	*(volatile uint32_t *)spi_bram_word_address(word_index) = value;
	return APB2FABRIC_STATUS_OK;
}

apb2fabric_status_t apb2fabric_spi_bram_read_byte(uint16_t byte_offset,
		uint8_t *value)
{
	uint32_t word;
	apb2fabric_status_t status;

	if (value == NULL)
		return APB2FABRIC_STATUS_INVALID_ARGUMENT;
	if (byte_offset >= APB2FABRIC_SPI_BRAM_BYTES)
		return APB2FABRIC_STATUS_OUT_OF_RANGE;

	status = apb2fabric_spi_bram_read_word(byte_offset / 4U, &word);
	if (status != APB2FABRIC_STATUS_OK)
		return status;

	*value = (uint8_t)(word >> ((byte_offset % 4U) * 8U));
	return APB2FABRIC_STATUS_OK;
}

apb2fabric_status_t apb2fabric_spi_bram_write_byte(uint16_t byte_offset,
		uint8_t value)
{
	uint32_t word;
	uint32_t shift;
	uint32_t mask;
	uint16_t word_index;
	apb2fabric_status_t status;

	if (byte_offset >= APB2FABRIC_SPI_BRAM_BYTES)
		return APB2FABRIC_STATUS_OUT_OF_RANGE;

	word_index = byte_offset / 4U;
	shift = (byte_offset % 4U) * 8U;
	mask = 0xFFU << shift;

	status = apb2fabric_spi_bram_read_word(word_index, &word);
	if (status != APB2FABRIC_STATUS_OK)
		return status;

	word = (word & ~mask) | ((uint32_t)value << shift);
	return apb2fabric_spi_bram_write_word(word_index, word);
}
