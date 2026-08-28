#include <uk/print.h>

const char carrels_cmdline[] = "nginx -p /nginx/ -c conf/nginx.conf";

extern int nginx_main(int argc, char *argv[]);

int uk_app_main(int argc, char *argv[])
{
	int rc;
	int i;

	uk_pr_crit("NGINX WRAPPER: entered argc=%d\n", argc);

	for (i = 0; i < argc; ++i)
		uk_pr_crit("NGINX WRAPPER: argv[%d]='%s'\n",
			   i, argv[i] ? argv[i] : "(null)");

	rc = nginx_main(argc, argv);

	uk_pr_crit("NGINX WRAPPER: nginx_main returned %d\n", rc);

	return rc;
}
