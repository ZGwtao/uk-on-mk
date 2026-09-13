#include <unistd.h>

#include <lwip/ip4_addr.h>
#include <lwip/netif.h>
#include <uk/print.h>

const char carrels_cmdline[] =
	"nginx";

extern int nginx_main(int argc, char *argv[]);

static void wait_for_network(void)
{
	const struct netif *nf;
	char ip[IP4ADDR_STRLEN_MAX];
	char netmask[IP4ADDR_STRLEN_MAX];
	char gateway[IP4ADDR_STRLEN_MAX];

	uk_pr_crit("NGINX WRAPPER: waiting for DHCP lease\n");

	for (;;) {
		nf = netif_default;
		if (nf && netif_is_up(nf) &&
		    !ip4_addr_isany_val(*netif_ip4_addr(nf)))
			break;

		sleep(1);
	}

	uk_pr_crit("NGINX WRAPPER: DHCP ready on %c%c%u "
		   "ip=%s netmask=%s gateway=%s\n",
		   nf->name[0], nf->name[1], nf->num,
		   ip4addr_ntoa_r(netif_ip4_addr(nf), ip, sizeof(ip)),
		   ip4addr_ntoa_r(netif_ip4_netmask(nf), netmask,
				  sizeof(netmask)),
		   ip4addr_ntoa_r(netif_ip4_gw(nf), gateway,
				  sizeof(gateway)));
}

int uk_app_main(int argc, char *argv[])
{
	char *nginx_argv[] = {
		"nginx",
		"-p", "/nginx/",
		"-c", "conf/nginx.conf",
		NULL,
	};
	int rc;
	int i;

	uk_pr_crit("NGINX WRAPPER: entered argc=%d\n", argc);

	for (i = 0; i < argc; ++i)
		uk_pr_crit("NGINX WRAPPER: argv[%d]='%s'\n",
			   i, argv[i] ? argv[i] : "(null)");

	wait_for_network();
	uk_pr_crit("NGINX WRAPPER: starting nginx on DHCP address, port 80\n");
	rc = nginx_main(5, nginx_argv);

	uk_pr_crit("NGINX WRAPPER: nginx_main returned %d\n", rc);

	return rc;
}
