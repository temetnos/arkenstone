#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <spawn.h>
#include <IOKit/IOKitLib.h>
#include "smc.h"

extern char **environ;

static int safe_run_pmset(char *const argv[]) {
    pid_t pid;
    int status;
    if (posix_spawn(&pid, "/usr/bin/pmset", NULL, NULL, argv, environ) != 0) {
        return -1;
    }
    if (waitpid(pid, &status, 0) == -1) {
        return -1;
    }
    return (WIFEXITED(status) && WEXITSTATUS(status) == 0) ? 0 : 1;
}

static int check_clamshell_active(void) {
    int pipefd[2];
    if (pipe(pipefd) != 0) return 0;

    pid_t pid = fork();
    if (pid == 0) {
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        dup2(pipefd[1], STDERR_FILENO);
        close(pipefd[1]);
        char *const args[] = {"pmset", "-g", NULL};
        execve("/usr/bin/pmset", args, environ);
        _exit(127);
    } else if (pid > 0) {
        close(pipefd[1]);
        char buf[2048];
        ssize_t bytesRead = 0;
        size_t total = 0;
        while ((bytesRead = read(pipefd[0], buf + total, sizeof(buf) - total - 1)) > 0) {
            total += bytesRead;
            if (total >= sizeof(buf) - 1) break;
        }
        buf[total] = '\0';
        close(pipefd[0]);
        int status;
        waitpid(pid, &status, 0);

        char *target = strstr(buf, "SleepDisabled");
        if (target != NULL) {
            target += strlen("SleepDisabled");
            while (*target == ' ' || *target == '\t') {
                target++;
            }
            if (*target == '1') return 1;
        }
    }
    return 0;
}

int write_key(const char *key, const char *hex_val, io_connect_t conn) {
    UInt32Char_t k;
    strncpy(k, key, sizeof(k));
    k[sizeof(k) - 1] = '\0';
    kern_return_t ret = SMCWriteSimple(k, (char *)hex_val, conn);
    return (ret == kIOReturnSuccess) ? 0 : 1;
}

int read_key(const char *key, SMCVal_t *val, io_connect_t conn) {
    UInt32Char_t k;
    strncpy(k, key, sizeof(k));
    k[sizeof(k) - 1] = '\0';
    kern_return_t ret = SMCReadKey2(k, val, conn);
    return (ret == kIOReturnSuccess) ? 0 : 1;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Arken Power Helper v1.1 (Apple Silicon PMU/SMC Manager)\n");
        printf("Usage: arken-power-helper [status | stop | start | check-root | clamshell-enable | clamshell-disable | clamshell-status]\n");
        return 1;
    }

    const char *cmd = argv[1];

    if (strcmp(cmd, "check-root") == 0) {
        if (geteuid() == 0) {
            printf("ROOT_OK\n");
            return 0;
        } else {
            printf("NEED_ROOT\n");
            return 2;
        }
    }

    if (strcmp(cmd, "clamshell-enable") == 0) {
        setuid(0);
        setgid(0);
        char *const args[] = {"pmset", "-a", "disablesleep", "1", NULL};
        int ret = safe_run_pmset(args);
        if (ret == 0) {
            printf("CLAMSHELL_ENABLED\n");
            return 0;
        } else {
            fprintf(stderr, "ERROR: failed to set pmset disablesleep 1\n");
            return 1;
        }
    } else if (strcmp(cmd, "clamshell-disable") == 0) {
        setuid(0);
        setgid(0);
        char *const args[] = {"pmset", "-a", "disablesleep", "0", NULL};
        int ret = safe_run_pmset(args);
        if (ret == 0) {
            printf("CLAMSHELL_DISABLED\n");
            return 0;
        } else {
            fprintf(stderr, "ERROR: failed to set pmset disablesleep 0\n");
            return 1;
        }
    } else if (strcmp(cmd, "clamshell-status") == 0) {
        if (check_clamshell_active()) {
            printf("STATUS: CLAMSHELL_ACTIVE\n");
        } else {
            printf("STATUS: CLAMSHELL_INACTIVE\n");
        }
        return 0;
    }

    io_connect_t conn;
    if (SMCOpen(&conn) != kIOReturnSuccess) {
        fprintf(stderr, "ERROR: Cannot open AppleSMC connection\n");
        return 3;
    }

    if (strcmp(cmd, "status") == 0) {
        SMCVal_t val = {0};
        int is_bypass = 0;
        
        // 1. Check CHTE (M1/M2/Tahoe)
        if (read_key("CHTE", &val, conn) == 0 && val.dataSize >= 1) {
            if (val.bytes[0] == 0x01) {
                is_bypass = 1;
            }
        }
        
        // 2. Check CH0I (Apple Silicon M3/M4 Inflow Inhibit)
        if (!is_bypass && read_key("CH0I", &val, conn) == 0 && val.dataSize >= 1) {
            if (val.bytes[0] == 0x01) {
                is_bypass = 1;
            }
        }

        // 3. Check CH0B (Legacy/Alternative PMU firmware)
        if (!is_bypass && read_key("CH0B", &val, conn) == 0 && val.dataSize >= 1) {
            if (val.bytes[0] == 0x02) {
                is_bypass = 1;
            }
        }

        if (is_bypass) {
            printf("STATUS: BYPASS_ACTIVE\n");
        } else {
            printf("STATUS: CHARGING_NORMAL\n");
        }
        SMCClose(conn);
        return 0;
    } else if (strcmp(cmd, "stop") == 0) {
        // Enforce root for write
        if (geteuid() != 0) {
            fprintf(stderr, "ERROR: root permissions required to stop charging\n");
            SMCClose(conn);
            return 2;
        }

        // Write Tahoe / M1 / M2 key
        write_key("CHTE", "01000000", conn);
        // Write M3 / M4 Inflow Inhibit key
        write_key("CH0I", "01", conn);
        // Write fallback keys
        write_key("CH0B", "02", conn);
        write_key("CH0C", "02", conn);

        printf("CHARGING_STOPPED\n");
        SMCClose(conn);
        return 0;
    } else if (strcmp(cmd, "start") == 0) {
        // Enforce root for write
        if (geteuid() != 0) {
            fprintf(stderr, "ERROR: root permissions required to start charging\n");
            SMCClose(conn);
            return 2;
        }

        // Restore normal charging across all chip variants
        write_key("CHTE", "00000000", conn);
        write_key("CH0I", "00", conn);
        write_key("CH0B", "00", conn);
        write_key("CH0C", "00", conn);

        printf("CHARGING_STARTED\n");
        SMCClose(conn);
        return 0;
    }

    fprintf(stderr, "Unknown command: %s\n", cmd);
    SMCClose(conn);
    return 1;
}
