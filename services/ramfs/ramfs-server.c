/* SPDX-License-Identifier: BSD-2-Clause */
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include <uk/print.h>
#include <uk/sched.h>
#include <carrels/events.h>
#include <sddf/util/printf.h>
#include <lions/fs/config.h>
#include <lions/fs/protocol.h>

#define OPEN_LIMIT 256
#define FREE_FILE_SLOT (-1)

/* Copied from FAT Server */
__attribute__((section(".fs_server_config"))) fs_server_config_t fs_config;

static fs_queue_t *commands;
static fs_queue_t *completions;
static char *share;
static uint64_t share_size;

/* Table that records the active/opened files owned by the client.
 * The 'slot' index of this table is provided to the client as client-side fd,
 * while the content in each slot is the POSIX fd provided by Unikraft vfs.
 * This table contains the mappings between the client-side fd and the POSIX fd
 */
static int files[OPEN_LIMIT];

static void init_file_table(void)
{
	for (int i = 0; i < OPEN_LIMIT; ++i)
		files[i] = FREE_FILE_SLOT;
}

static int find_free_file_slot(void)
{
	for (int fd = 0; fd < OPEN_LIMIT; ++fd) {
		if (files[fd] == FREE_FILE_SLOT)
			return fd;
	}

	return FREE_FILE_SLOT;
}

static int get_active_file_slot(uint64_t client_fd)
{
	if (client_fd >= OPEN_LIMIT)
		return FREE_FILE_SLOT;

	int slot = (int)client_fd;

	return files[slot] == FREE_FILE_SLOT ? FREE_FILE_SLOT : slot;
}

static uint64_t error_status(int error)
{
	switch (error) {
	case ENOENT:	return FS_STATUS_NO_FILE;
	case ENOTDIR: 	return FS_STATUS_NOT_DIRECTORY;
	case EACCES: 	return FS_STATUS_SERVER_WAS_DENIED;
	case EMFILE: 	return FS_STATUS_TOO_MANY_OPEN_FILES;
	default: 		return FS_STATUS_ERROR;
	}
}

static uint64_t close_all_files(void)
{
	uint64_t status = FS_STATUS_SUCCESS;

	for (int fd = 0; fd < OPEN_LIMIT; ++fd) {
		if (files[fd] == FREE_FILE_SLOT)
			continue;

		if (close(files[fd]) < 0 && status == FS_STATUS_SUCCESS)
			status = error_status(errno);

		files[fd] = FREE_FILE_SLOT;
	}

	return status;
}

static void *shared_buffer(fs_buffer_t b)
{
	if (!b.size || b.offset >= share_size || b.size > share_size - b.offset)
		return NULL;

	return share + b.offset;
}

static int copy_path(fs_buffer_t b, char path[FS_MAX_PATH_LENGTH + 1])
{
	const char *src = shared_buffer(b);
	if (!src || b.size > FS_MAX_PATH_LENGTH)
		return -1;

	memcpy(path, src, b.size);

	path[b.size] = '\0';
	if (memchr(path, '\0', b.size) == NULL)
		return -1;

	return 0;
}

static void handle(const fs_cmd_t *cmd, fs_cmpl_t *out)
{
	char path[FS_MAX_PATH_LENGTH + 1];
	int fd;
	struct stat st;
	ssize_t n;
	void *buffer;

	memset(out, 0, sizeof(*out));

	out->id = cmd->id;
	out->status = FS_STATUS_SUCCESS;

	switch (cmd->type) {
	case FS_CMD_INITIALISE: {
		/* It's safe to do nothing here, as initrd is init at boot */
		break;
	}
	case FS_CMD_DEINITIALISE: {
		out->status = close_all_files();
		break;
	}
	case FS_CMD_FILE_OPEN: {
		if (copy_path(cmd->params.file_open.path, path)) {
			out->status = FS_STATUS_INVALID_PATH;
			break;
		}
		if (cmd->params.file_open.flags != FS_OPEN_FLAGS_READ_ONLY) {
			out->status = FS_STATUS_SERVER_WAS_DENIED;
			break;
		}

		fd = find_free_file_slot();
		if (fd == FREE_FILE_SLOT) {
			out->status = FS_STATUS_TOO_MANY_OPEN_FILES;
			break;
		}

		files[fd] = open(path, O_RDONLY);
		if (files[fd] < 0) {
			out->status = error_status(errno);
			break;
		}

		out->data.file_open.fd = (uint64_t)fd;
		break;
	}
	case FS_CMD_FILE_CLOSE: {
		fd = get_active_file_slot(cmd->params.file_close.fd);
		if (fd == FREE_FILE_SLOT) {
			out->status = FS_STATUS_INVALID_FD;
			break;
		}
	
		if (close(files[fd]) < 0) {
			out->status = error_status(errno);
		}
		files[fd] = FREE_FILE_SLOT;
		break;
	}
	case FS_CMD_FILE_SIZE: {
		fd = get_active_file_slot(cmd->params.file_size.fd);
		if (fd == FREE_FILE_SLOT) {
			out->status = FS_STATUS_INVALID_FD;
			break;
		}

		if (fstat(files[fd], &st) < 0) {
			out->status = error_status(errno);
		} else {
			out->data.file_size.size = (uint64_t)st.st_size;
		}
		break;
	}
	case FS_CMD_FILE_READ: {
		uint64_t offset = cmd->params.file_read.offset;
		uint64_t size = cmd->params.file_read.buf.size;

		fd = get_active_file_slot(cmd->params.file_read.fd);
		if (fd == FREE_FILE_SLOT) {
			out->status = FS_STATUS_INVALID_FD;
			break;
		}

		/* Get the client buffer */
		buffer = shared_buffer(cmd->params.file_read.buf);
		if (!buffer) {
			out->status = FS_STATUS_INVALID_BUFFER;
			break;
		}

		if (offset > INT64_MAX) {
			out->status = FS_STATUS_ERROR;
			break;
		}

		n = pread(files[fd], buffer, (size_t)size, (off_t)offset);
		if (n < 0) {
			out->status = error_status(errno);
		} else {
			out->data.file_read.len_read = (uint64_t)n;
		}
		break;
	}
	default: {
		out->status = FS_STATUS_INVALID_COMMAND;
		break;
	}
	}
}

static void process_requests(microkit_channel ch, void *arg)
{
	/* Needed only when multiplexer is enabled. */
	(void)ch;
	(void)arg;

	uint64_t count = 0;

	/* FS server takes commands, generates completions */
	while (fs_queue_length_consumer(commands) > 0 &&
	       fs_queue_length_producer(completions) < FS_QUEUE_CAPACITY) {

		fs_cmpl_t result;

		/* Process filesystem commands */
		handle(&fs_queue_idx_filled(commands, 0)->cmd, &result);

		/* Enqueue the completion after processing the command */
		fs_queue_idx_empty(completions, 0)->cmpl = result;
		fs_queue_publish_consumption(commands, 1);
		fs_queue_publish_production(completions, 1);

		count++;
	}

	/* If there is any actual update (in completion), signal the client */
	if (count) {
		microkit_notify(fs_config.client.id);
	}
}

int uk_app_main(int argc, char **argv)
{
	int rc;

	(void)argc;
	(void)argv;

	sddf_printf("RAMFS: starting on channel %u\n", fs_config.client.id);

	if (!fs_config_check_magic(&fs_config)) {
        sddf_printf("RAMFS: invalid FS configuration\n");
        return 1;
    }

	commands = fs_config.client.command_queue.vaddr;
	completions = fs_config.client.completion_queue.vaddr;
	share = fs_config.client.share.vaddr;
	share_size = fs_config.client.share.size;

	init_file_table();

	/* Init a handler for the FS events from clients */
	rc = carrels_event_register(fs_config.client.id, process_requests, NULL);
    if (rc) {
        sddf_printf("RAMFS: event registration failed: %d\n", rc);
        return 1;
    }

	uk_pr_info("RAMFS: LionsOS server ready on channel %u\n", fs_config.client.id);
    /*
     * Current Carrels event delivery wakes a dedicated handler thread.
     * The main thread receives the Microkit notification, then yields so
     * that the runnable handler can drain the LionsOS request queue.
     */
    for (;;) {
        uk_carrels_microkit_wait();
        uk_sched_yield();
    }
}
