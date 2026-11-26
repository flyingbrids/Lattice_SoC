#ifndef SPI_H
#define SPI_H

#include <stdint.h>

typedef enum {
	SPI_SLAVE_ADC = 0,
	SPI_SLAVE_DAC,
	SPI_SLAVE_FLASH,
	SPI_SLAVE_COUNT
} spi_slave_t;

typedef enum {
	SPI_STATUS_OK = 0,
	SPI_STATUS_INVALID_ARGUMENT,
	SPI_STATUS_APB_ERROR,
	SPI_STATUS_BUSY,
	SPI_STATUS_START_TIMEOUT,
	SPI_STATUS_TRANSFER_TIMEOUT
} spi_status_t;

/*
 * Transfers bytes to one slave and copies the received bytes from SPI BRAM
 * into rx_data when it is non-NULL. The current RTL starts a transfer when
 * SPI_CONTROL is written; it does not implement a separate start bit.
 */
spi_status_t spi_transfer_to_slave(spi_slave_t slave, const uint8_t *tx_data,
		uint8_t *rx_data, uint16_t byte_count);

/*
 * Sends the same payload to ADC, DAC, then flash, stopping on the first error.
 * failed_slave is SPI_SLAVE_COUNT on success or invalid arguments.
 */
spi_status_t spi_transfer_round_robin(const uint8_t *tx_data,
		uint16_t byte_count, spi_slave_t *failed_slave);

#endif
