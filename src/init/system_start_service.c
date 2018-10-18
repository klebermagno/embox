/**
 * @file
 * @brief Runs start script
 *
 * @date 04.10.11
 * @author Alexander Kalmuk
 */
#include <util/log.h>

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <util/array.h>

#include <framework/cmd/api.h>
#include <cmd/shell.h>
#include <cmd/cmdline.h>

#include "setup_tty.h"

static const char *script_commands[] = {
	#include <system_start.inc>
};

#if OPTION_GET(NUMBER,log_level) >= LOG_INFO
#	define MD(x) do {\
		x;\
	} while (0);
#else
#	define MD(x) do{\
	} while (0);
#endif

int system_start(void) {
	const char *command;
	char *argv[10];
	int argc;
	const struct cmd *cmd;

	setup_tty(OPTION_STRING_GET(tty_dev));

	array_foreach(command, script_commands, ARRAY_SIZE(script_commands)) {
		MD(printf(">%s\n", command));
		argc = cmdline_tokenize((char *)command, argv);
		if (0 == strncmp(argv[0], "pthread", 7)) {
			cmd = cmd_lookup(argv[1]);
			continue;
		}
		cmd = cmd_lookup(argv[0]);
		cmd_exec(cmd, argc, argv);
	}

	return 0;
}
