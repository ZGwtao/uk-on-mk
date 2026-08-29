#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

#include <uk/sddf.h>

static const char sqlite_script[] =
	"CREATE TABLE IF NOT EXISTS users ("
	"  id INTEGER PRIMARY KEY,"
	"  name TEXT NOT NULL,"
	"  score INTEGER"
	");"
	"DELETE FROM users;"
	"INSERT INTO users (name, score) VALUES "
	"  (\"Alice\", 95),"
	"  (\"Bob\", 87),"
	"  (\"Carol\", 91);"
	"SELECT id, name, score FROM users ORDER BY id;";

extern int sqlite_main(int argc, char *argv[]);

static int setup_stdio(void)
{
	int out;

	errno = 0;
	out = open("/dev/stdout", O_WRONLY);
	sddf_printf("open /dev/stdout: fd=%d errno=%d\n", out, errno);

	if (out < 0)
		return -1;

	if (dup2(out, STDOUT_FILENO) < 0) {
		sddf_printf("dup2(%d, 1) failed: errno=%d\n", out, errno);
		return -1;
	}

	if (dup2(out, STDERR_FILENO) < 0) {
		sddf_printf("dup2(%d, 2) failed: errno=%d\n", out, errno);
		return -1;
	}

	if (out != STDOUT_FILENO && out != STDERR_FILENO)
		close(out);

	setvbuf(stdout, NULL, _IONBF, 0);
	setvbuf(stderr, NULL, _IONBF, 0);

	return 0;
}

int uk_app_main(int argc, char *argv[])
{
	if (setup_stdio() < 0)
		sddf_printf("stdio setup failed\n");

	char *fallback[] = { (char *)"sqlite", (char *)"/test.db",
		(char *)sqlite_script, NULL };

	return sqlite_main(3, fallback);
}
