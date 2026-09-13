#include <uk/print.h>
#include <unistd.h>

#include <lwip/dhcp.h>
#include <lwip/inet.h>
#include <lwip/netif.h>

extern int redis_server_main(int argc, char *argv[]);

static void print_dhcp_address(void)
{
	struct netif *nf;
	unsigned int waited;

	for (waited = 0; waited < 30; waited++) {
		nf = netif_default;
		if (nf && dhcp_supplied_address(nf)) {
			char addr[IP4ADDR_STRLEN_MAX];
			char mask[IP4ADDR_STRLEN_MAX];
			char gateway[IP4ADDR_STRLEN_MAX];

			ip4addr_ntoa_r(netif_ip4_addr(nf), addr, sizeof(addr));
			ip4addr_ntoa_r(netif_ip4_netmask(nf), mask,
					 sizeof(mask));
			ip4addr_ntoa_r(netif_ip4_gw(nf), gateway,
					 sizeof(gateway));
			uk_pr_info("%c%c%u: DHCP address %s netmask %s gateway %s\n",
				   nf->name[0], nf->name[1], nf->num,
				   addr, mask, gateway);
			return;
		}
		sleep(1);
	}

	uk_pr_warn("DHCP address was not available after %u seconds\n", waited);
}

int uk_app_main(int argc, char *argv[])
{
	static char fallback_storage[512] =
		"redis-server\0"
		"/redis.conf";
	char *fallback[] = {
		fallback_storage,
		fallback_storage + sizeof("redis-server"),
		0,
	};

	print_dhcp_address();

	if (argc < 2) {
		uk_pr_info("Starting Redis with /redis.conf\n");
		return redis_server_main(2, fallback);
	}

	return redis_server_main(argc, argv);
}
