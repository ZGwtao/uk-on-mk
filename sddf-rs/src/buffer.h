#pragma once

#include <sddf/network/config.h>
#include <sddf/network/queue.h>
#include <stdbool.h>
#include <stdint.h>

/* Limits of our static reference tables, not sDDF queue capacities. */
#define SDDF_RS_MAX_TX_BUFFERS 1024
#define SDDF_RS_MAX_RX_BUFFERS 1024

typedef struct tx_slot {
    /* Live client references, including the owner returned by acquire. */
    uint16_t references;
    /* Link in the local ready queue; valid only while the slot is ready. */
    uint16_t next_ready;
    /* The descriptor has been published but not yet returned by sDDF. */
    bool in_flight;
} tx_slot_t;

typedef struct rx_slot {
    /* Last release returns desc to the sDDF RX free queue. */
    uint16_t references;
    net_buff_desc_t desc;
} rx_slot_t;

/* The queue handles and config must outlive all acquired references. */
int demi_sddf_tx_init(net_client_config_t *config, net_queue_handle_t *tx);
int demi_sddf_rx_init(net_client_config_t *config, net_queue_handle_t *rx);
/* Call after net_buffers_init(tx, 0) to move the initial free descriptors to the ready list. */
void demi_sddf_tx_init_ready(void);

/* TX: acquire a ready slot, share it, then publish or release it. */
int demi_sddf_net_tx_acquire(uint64_t *offset, uint8_t **data);
void demi_sddf_net_tx_retain(uint64_t offset);
bool demi_sddf_net_tx_is_returned(uint64_t offset);
void demi_sddf_net_tx_release(uint64_t offset);
int demi_sddf_net_tx_publish(uint64_t offset, uint16_t len);

/* RX: acquire an active descriptor; final release returns it to sDDF. */
int demi_sddf_net_rx_acquire(uint64_t *offset, uint8_t **data, uint16_t *len);
void demi_sddf_net_rx_retain(uint64_t offset);
void demi_sddf_net_rx_release(uint64_t offset);
