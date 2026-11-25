#include <unistd.h>

#include <lwip/ip4_addr.h>
#include <lwip/netif.h>
#include <uk/print.h>

const char carrels_cmdline[] = "nginx -p /nginx/ -c conf/nginx.conf";

extern int nginx_main(int argc, char *argv[]);

static void wait_for_network(void)
{
	const struct netif *nf;
	char ip[IP4ADDR_STRLEN_MAX];

	uk_pr_crit("NGINX WRAPPER: waiting for DHCP lease\n");
	for (;;) {
		nf = netif_default;
		if (nf && netif_is_up(nf) &&
		    !ip4_addr_isany_val(*netif_ip4_addr(nf)))
			break;
		sleep(1);
	}

	uk_pr_crit("NGINX WRAPPER: DHCP ready, ip=%s\n",
		   ip4addr_ntoa_r(netif_ip4_addr(nf), ip, sizeof(ip)));
}

int uk_app_main(int argc, char *argv[])
{
	int rc;
	int i;

	uk_pr_crit("NGINX WRAPPER: entered argc=%d\n", argc);

	for (i = 0; i < argc; ++i)
		uk_pr_crit("NGINX WRAPPER: argv[%d]='%s'\n",
			   i, argv[i] ? argv[i] : "(null)");

	wait_for_network();
	rc = nginx_main(argc, argv);

	uk_pr_crit("NGINX WRAPPER: nginx_main returned %d\n", rc);

	return rc;
}
