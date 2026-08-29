extern int sqlite_main(int argc, char *argv[]);

int uk_app_main(int argc, char *argv[])
{
	if (argc < 2) {
		char *fallback[] = {
			(char *)"sqlite",
			(char *)"-interactive",
			(char *)"/test.db",
			0,
		};

		return sqlite_main(3, fallback);
	}

	return sqlite_main(argc, argv);
}
