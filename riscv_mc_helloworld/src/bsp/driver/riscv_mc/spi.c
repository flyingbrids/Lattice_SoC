#include "spi.h"

#include <stddef.h>
#include "apb2fabric.h"

#define SPI_MAX_TRANSFER_BYTES APB2FABRIC_SPI_BRAM_BYTES
#define SPI_BUSY_POLL_LIMIT 1000000U
#define SPI_STATUS_BUSY_MASK 0x0001U

static spi_status_t wait_for_busy_state(uint8_t expected_busy)
{
	uint16_t status;

	for (uint32_t poll = 0; poll < SPI_BUSY_POLL_LIMIT; ++poll) {
		if (apb2fabric_reg_read(APB2FABRIC_REG_SPI_STATUS, &status) !=
				APB2FABRIC_STATUS_OK)
			return SPI_STATUS_APB_ERROR;

		if (((status & SPI_STATUS_BUSY_MASK) != 0U) == (expected_busy != 0U))
			return SPI_STATUS_OK;
	}

	return expected_busy ? SPI_STATUS_START_TIMEOUT :
			SPI_STATUS_TRANSFER_TIMEOUT;
}

spi_status_t spi_transfer_to_slave(spi_slave_t slave, const uint8_t *tx_data,
		uint8_t *rx_data, uint16_t byte_count)
{
	uint16_t status;
	uint16_t control;
	spi_status_t result;

	if (tx_data == NULL || byte_count == 0U ||
			byte_count > SPI_MAX_TRANSFER_BYTES ||
			slave < SPI_SLAVE_ADC || slave >= SPI_SLAVE_COUNT)
		return SPI_STATUS_INVALID_ARGUMENT;

	if (apb2fabric_reg_read(APB2FABRIC_REG_SPI_STATUS, &status) !=
			APB2FABRIC_STATUS_OK)
		return SPI_STATUS_APB_ERROR;
	if ((status & SPI_STATUS_BUSY_MASK) != 0U)
		return SPI_STATUS_BUSY;

	if (apb2fabric_reg_write(APB2FABRIC_REG_SPI_BYTE_COUNT, byte_count) !=
			APB2FABRIC_STATUS_OK)
		return SPI_STATUS_APB_ERROR;

	for (uint16_t i = 0; i < byte_count; ++i) {
		if (apb2fabric_spi_bram_write_byte(i, tx_data[i]) !=
				APB2FABRIC_STATUS_OK)
			return SPI_STATUS_APB_ERROR;
	}


	control = 1U;  // enable Bit 0 for read back
	control = control + (uint16_t)(1U << ((uint16_t)slave + 1U)); // bits 3:1 select one active-low chip select.
    control = control + (1U << 4U); // reverse clock polarity

	if (apb2fabric_reg_write(APB2FABRIC_REG_SPI_CONTROL, control) !=
			APB2FABRIC_STATUS_OK)
		return SPI_STATUS_APB_ERROR;

	result = wait_for_busy_state(1U);
	if (result != SPI_STATUS_OK)
		return result;

	result = wait_for_busy_state(0U);
	if (result != SPI_STATUS_OK)
		return result;

	if (rx_data != NULL) {
		for (uint16_t i = 0; i < byte_count; ++i) {
			if (apb2fabric_spi_bram_read_byte(i, &rx_data[i]) !=
					APB2FABRIC_STATUS_OK)
				return SPI_STATUS_APB_ERROR;
		}
	}

	return SPI_STATUS_OK;
}

spi_status_t spi_transfer_round_robin(const uint8_t *tx_data,
		uint16_t byte_count, spi_slave_t *failed_slave)
{
	static const spi_slave_t slaves[] = {
		SPI_SLAVE_ADC,
		SPI_SLAVE_DAC,
		SPI_SLAVE_FLASH
	};

	if (tx_data == NULL || byte_count == 0U ||
			byte_count > SPI_MAX_TRANSFER_BYTES)
		return SPI_STATUS_INVALID_ARGUMENT;

	if (failed_slave != NULL)
		*failed_slave = SPI_SLAVE_COUNT;

	for (uint32_t i = 0; i < (uint32_t)SPI_SLAVE_COUNT; ++i) {
		if (failed_slave != NULL)
			*failed_slave = slaves[i];
		spi_status_t result = spi_transfer_to_slave(slaves[i], tx_data,
				NULL, byte_count);
		if (result != SPI_STATUS_OK) {
			return result;
		}
	}

	if (failed_slave != NULL)
		*failed_slave = SPI_SLAVE_COUNT;
	return SPI_STATUS_OK;
}
