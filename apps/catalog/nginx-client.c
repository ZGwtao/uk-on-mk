/* SPDX-License-Identifier: BSD-3-Clause */

#include <arpa/inet.h>
#include <errno.h>
#include <stdio.h>
#include <sys/socket.h>
#include <unistd.h>

#define NGINX_ADDR "10.0.2.15"
#define NGINX_ADDR_HOST_ORDER 0x0a00020fU
#define NGINX_PORT 80
#define NGINX_CONNECT_RETRIES 30
#define BUFLEN 2048

static char sendbuf[BUFLEN];
static char recvbuf[BUFLEN];

static int build_nginx_request(void)
{
	return snprintf(sendbuf, sizeof(sendbuf),
			"GET / HTTP/1.1\r\n"
			"Host: %s\r\n"
			"Connection: close\r\n"
			"\r\n",
			NGINX_ADDR);
}

int uk_app_main(int argc __attribute__((unused)),
			char *argv[] __attribute__((unused)))
{
	struct sockaddr_in nginx_addr = { 0 };
	int attempt;
	int connect_errno = 0;
	int peer = -1;
	int request_len;
	ssize_t n;

	nginx_addr.sin_family = AF_INET;
	nginx_addr.sin_port = htons(NGINX_PORT);
	nginx_addr.sin_addr.s_addr = htonl(NGINX_ADDR_HOST_ORDER);

	for (attempt = 1; attempt <= NGINX_CONNECT_RETRIES; ++attempt) {
		peer = socket(AF_INET, SOCK_STREAM, 0);
		if (peer < 0) {
			fprintf(stderr, "Failed to create nginx socket: %d\n", errno);
			return 1;
		}

		if (connect(peer, (struct sockaddr *)&nginx_addr,
			    sizeof(nginx_addr)) == 0)
			break;

		connect_errno = errno;
		close(peer);
		peer = -1;
		if (attempt == NGINX_CONNECT_RETRIES) {
			fprintf(stderr, "Failed to connect to nginx at %s:%d: %d\n",
				NGINX_ADDR, NGINX_PORT, connect_errno);
			return 1;
		}

		printf("Waiting for nginx at %s:%d (%d/%d)...\n",
		       NGINX_ADDR, NGINX_PORT, attempt, NGINX_CONNECT_RETRIES);
		sleep(1);
	}

	request_len = build_nginx_request();
	if (request_len < 0 || (size_t)request_len >= sizeof(sendbuf)) {
		fprintf(stderr, "Failed to build nginx request\n");
		close(peer);
		return 1;
	}

	n = write(peer, sendbuf, request_len);
	if (n != (ssize_t)request_len) {
		fprintf(stderr, "Failed to send request to nginx: %d\n", errno);
		close(peer);
		return 1;
	}

	n = read(peer, recvbuf, sizeof(recvbuf) - 1);
	if (n <= 0) {
		fprintf(stderr, "Failed to receive response from nginx: %d\n", errno);
		close(peer);
		return 1;
	}

	recvbuf[n] = '\0';
	printf("Received response from nginx:\n%s\n", recvbuf);
	close(peer);
	return 0;
}
