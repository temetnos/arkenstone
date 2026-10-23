#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <IOKit/IOKitLib.h>
#include "smc.h"

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
        printf("Arken Power Helper v1.0 (Apple Silicon PMU/SMC Manager)\n");
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
        int ret = system("/usr/bin/pmset -a disablesleep 1");
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
        int ret = system("/usr/bin/pmset -a disablesleep 0");
        if (ret == 0) {
            printf("CLAMSHELL_DISABLED\n");
            return 0;
        } else {
            fprintf(stderr, "ERROR: failed to set pmset disablesleep 0\n");
            return 1;
        }
    } else if (strcmp(cmd, "clamshell-status") == 0) {
        int ret = system("/usr/bin/pmset -g | grep -q 'SleepDisabled[[:space:]]*1'");
        if (ret == 0) {
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
        
        // Check CHTE
        if (read_key("CHTE", &val, conn) == 0 && val.dataSize >= 1) {
            if (val.bytes[0] == 0x01) {
                is_bypass = 1;
            }
        }
        
        // Also check CH0B
        if (read_key("CH0B", &val, conn) == 0 && val.dataSize >= 1) {
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

        // 1. CHTE (Apple Silicon Tahoe / M1/M2/M3)
        int ret = write_key("CHTE", "01000000", conn);
        if (ret != 0) {
            // Fallback for older models
            write_key("CH0B", "02", conn);
            write_key("CH0C", "02", conn);
        }

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

        // 1. CHTE
        int ret = write_key("CHTE", "00000000", conn);
        if (ret != 0) {
            write_key("CH0B", "00", conn);
            write_key("CH0C", "00", conn);
        }

        printf("CHARGING_STARTED\n");
        SMCClose(conn);
        return 0;
    }

    fprintf(stderr, "Unknown command: %s\n", cmd);
    SMCClose(conn);
    return 1;
}
