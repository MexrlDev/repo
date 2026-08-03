# -*- coding: utf-8 -*-
import traceback
import time
import os
import sys
import pygame_sdl2
from pygame_sdl2 import CONTROLLER_BUTTON_Y, CONTROLLER_BUTTON_A

# Only import what we need from utils.rp
from utils.rp import log, log_exc
from utils.tcp import (
    create_tcp_client,
    create_tcp_server,
    accept_client,
    get_socket_name,
    read_all_from_socket,
    close_socket,
    write_to_socket,
)
from utils.fs import file_exists, read_file_data
from constants import CONSOLE_KIND, SHARED_VARS, rp
from sc import sc

PORT = 9025

# Local payload log for capturing logs sent back to TCP clients
payload_log = []

# ----------------------------------------------------------------------
# Clean incoming script (strip BOM and encoding declaration)
# ----------------------------------------------------------------------

def clean_script(script):
    """Remove UTF-8 BOM and encoding declarations from a script string."""
    if script.startswith(u'\ufeff'):
        script = script[1:]

    lines = script.splitlines()
    if not lines:
        return script

    if lines[0].strip().startswith('# -*- coding:'):
        lines = lines[1:]

    return '\n'.join(lines)

# ----------------------------------------------------------------------
# Safe filesystem helpers (never crash)
# ----------------------------------------------------------------------

def safe_listdir(path):
    try:
        entries = os.listdir(path)
        return entries if entries is not None else []
    except Exception as e:
        log("[!] Could not list %s: %s" % (path, e))
        return []

def safe_exists(path):
    try:
        return os.path.exists(path)
    except Exception:
        return False

# ----------------------------------------------------------------------
# Syscall test (includes dup)
# ----------------------------------------------------------------------

def test_syscalls():
    log("[*] Running syscall test...")
    try:
        pid = sc.syscalls.getpid()
        log("[+] getpid() = %d" % pid)

        uid = sc.syscalls.getuid()
        log("[+] getuid() = %d" % uid)

        # Open /dev/null to get a valid fd
        dev_null = b"/dev/null\0"
        fd = sc.syscalls.open(dev_null, 0)  # O_RDONLY
        if fd == -1 or fd == 0xFFFFFFFFFFFFFFFF:
            log("[-] open(/dev/null) failed, errno=%d" % sc.syscalls.open.errno)
            return

        log("[*] Opened /dev/null, fd = %d" % fd)

        # Test dup on valid fd
        if not hasattr(sc.syscalls, 'dup'):
            sc.make_syscall_if_needed('dup', 0x29)

        new_fd = sc.syscalls.dup(fd)
        if new_fd == -1 or new_fd == 0xFFFFFFFFFFFFFFFF:
            log("[-] dup(%d) failed, errno=%d" % (fd, sc.syscalls.dup.errno))
        else:
            log("[+] dup(%d) = %d" % (fd, new_fd))
            sc.syscalls.close(new_fd)

        sc.syscalls.close(fd)
        log("[*] Syscall test completed")
    except Exception as e:
        log_exc(traceback.format_exc())

# ----------------------------------------------------------------------
# Jailbreak check (setuid)
# ----------------------------------------------------------------------

def check_jailbroken():
    try:
        if not hasattr(sc.syscalls, 'setuid'):
            sc.make_syscall_if_needed('setuid', 0x17)
        if not hasattr(sc.syscalls, 'getuid'):
            sc.make_syscall_if_needed('getuid', 0x18)

        uid_before = sc.syscalls.getuid()
        log("[*] UID before setuid: %d" % uid_before)

        ret = sc.syscalls.setuid(0)
        if ret == -1 or ret == 0xFFFFFFFFFFFFFFFF:
            log("[*] setuid(0) failed, errno=%d" % sc.syscalls.setuid.errno)
        else:
            log("[*] setuid(0) returned %d" % ret)

        uid_after = sc.syscalls.getuid()
        log("[*] UID after setuid: %d" % uid_after)

        jailbroken = (uid_after == 0)
        log("[+] Jailbroken: %s" % ("YES" if jailbroken else "NO"))
        return jailbroken
    except Exception as e:
        log_exc(traceback.format_exc())
        return False

# ----------------------------------------------------------------------
# Kernel exploit (lapse)
# ----------------------------------------------------------------------

def run_kernel_exploit():
    log("[*] Attempting kernel exploit (lapse)...")
    try:
        import lapse
        if hasattr(lapse, 'main'):
            lapse.main()
        time.sleep(1)
        return check_jailbroken()
    except Exception as e:
        log_exc(traceback.format_exc())
        return False

# ----------------------------------------------------------------------
# USB detection
# ----------------------------------------------------------------------

def scan_usb():
    """List contents of /mnt/ and USB drives for diagnostics."""
    log("[*] Scanning USB mounts...")
    mnt = safe_listdir("/mnt/")
    if mnt:
        log("[*] /mnt/ contains: %s" % ", ".join(mnt))
        for entry in mnt:
            if entry.startswith("usb"):
                usb_path = "/mnt/%s" % entry
                content = safe_listdir(usb_path)
                if content:
                    log("[*] %s contains: %s" % (usb_path, ", ".join(content)))
                else:
                    log("[*] %s is empty" % usb_path)
    else:
        log("[*] /mnt/ is empty or inaccessible")

    # Also list /saves/ for reference
    saves = safe_listdir("/saves/")
    if saves:
        log("[*] /saves/ contains: %s" % ", ".join(saves))
    else:
        log("[*] /saves/ is empty or inaccessible")

# ----------------------------------------------------------------------
# USB Stage2
# ----------------------------------------------------------------------

def find_stage2_folder():
    for i in range(8):
        test = "/mnt/usb%d/stage2/stage2.txt" % i
        if safe_exists(test):
            log("[*] Found stage2.txt at %s" % test)
            return "/mnt/usb%d/stage2" % i
    mnt = safe_listdir("/mnt/")
    for entry in mnt:
        if entry.startswith("usb"):
            test = "/mnt/%s/stage2/stage2.txt" % entry
            if safe_exists(test):
                log("[*] Found stage2.txt at %s" % test)
                return "/mnt/%s/stage2" % entry
    return None

def run_stage2_from_usb(folder):
    txt = os.path.join(folder, "stage2.txt")
    try:
        with open(txt, "r") as f:
            lines = f.read().splitlines()
    except Exception as e:
        log("[!] Failed to read stage2.txt: %s" % e)
        return

    delay = 2.0
    scripts = []
    delay_parsed = False
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if not delay_parsed:
            try:
                delay = float(line)
                delay_parsed = True
                continue
            except ValueError:
                pass
        scripts.append(line)

    if not scripts:
        log("[!] No scripts found")
        return

    log("[*] Executing %d scripts with %.1f s delay" % (len(scripts), delay))
    for script in scripts:
        path = os.path.join(folder, script)
        if not safe_exists(path):
            log("[!] Script not found: %s" % path)
            continue
        log("[*] Executing: %s" % path)
        try:
            with open(path, "r") as f:
                code = f.read()
            scope = dict(globals(), **locals())
            exec(code, scope)
            log("[*] Done")
        except Exception as e:
            log_exc(traceback.format_exc())
        if delay > 0:
            time.sleep(delay)

# ----------------------------------------------------------------------
# Autoload
# ----------------------------------------------------------------------

def run_autoload():
    paths = ["/mnt/usb%d/yarpe_autoload/autoload.txt" % i for i in range(8)]
    paths += ["/data/yarpe_autoload/autoload.txt", "/saves/yarpe_autoload/autoload.txt"]

    auto_path = None
    for p in paths:
        if safe_exists(p):
            auto_path = p
            break

    if not auto_path:
        log("[*] No autoload found")
        return

    log("[*] Autoload: %s" % auto_path)
    try:
        loaded_from_save = auto_path.startswith("/saves/")
        with open(auto_path, "r") as f:
            lines = f.read().splitlines()
        autoload_dir = os.path.dirname(auto_path)
        for line in lines:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("!"):
                time.sleep(float(line[1:].strip()) / 1000.0)
                continue
            exec_path = os.path.join(autoload_dir, line)
            if not safe_exists(exec_path):
                log("[!] Not found: %s" % exec_path)
                continue
            ext = os.path.splitext(exec_path)[-1].lower()
            if ext == ".py":
                log("[*] Executing autoload script: %s" % exec_path)
                with open(exec_path, "r") as f:
                    code = f.read()
                scope = dict(globals(), **locals())
                exec(code, scope)
            elif ext in [".bin", ".elf"]:
                log("[*] Loading binary: %s" % exec_path)
                with open(exec_path, "rb") as f:
                    data = f.read()
                if sc.platform == "ps5":
                    sock = create_tcp_client("127.0.0.1", 9021)
                    write_to_socket(sock, data)
                    close_socket(sock)
                    sc.kill_game()
                else:
                    BinLoader = SHARED_VARS.get("BinLoader")
                    if BinLoader:
                        loader = BinLoader(data)
                        loader.run()
                        loader.join()
                    else:
                        log("[!] BinLoader not available")
            else:
                log("[*] Ignoring: %s" % exec_path)
    except Exception as e:
        log_exc(traceback.format_exc())

# ----------------------------------------------------------------------
# Main Entry Point
# ----------------------------------------------------------------------

def poc():
    log("[*] Detected game: %s %s" % (rp.config.name, CONSOLE_KIND))
    log("[*] Console: %s %s" % (sc.platform.upper(), sc.version))

    test_syscalls()

    jailbroken = check_jailbroken()
    if not jailbroken:
        log("[*] Not jailbroken. Running kernel exploit...")
        if run_kernel_exploit():
            jailbroken = True
        else:
            log("[!] Kernel exploit failed. Continuing with limited permissions.")

    # Scan USB and save directories (diagnostics)
    if jailbroken:
        log("[*] Jailbroken – scanning USB and /saves/")
        scan_usb()
    else:
        log("[*] Not jailbroken – USB may be limited")

    # Autoload (skip if triangle held)
    c = pygame_sdl2.controller.Controller(0)
    c.init()
    run_auto = c.get_button(CONTROLLER_BUTTON_Y) == 0
    c.quit()
    if run_auto:
        run_autoload()

    # USB Stage2
    stage2_folder = find_stage2_folder()
    if stage2_folder:
        log("[*] Found USB stage2 at %s" % stage2_folder)
        log("[*] Press X to run, or wait 3s...")
        start = time.time()
        pressed = False
        while time.time() - start < 3.0:
            c = pygame_sdl2.controller.Controller(0)
            c.init()
            if c.get_button(CONTROLLER_BUTTON_A):
                pressed = True
                break
            time.sleep(0.05)
            c.quit()
        if pressed:
            run_stage2_from_usb(stage2_folder)

    # ---- TCP Listener (fallback) ----
    log("[*] Starting TCP listener on port %d..." % PORT)
    s = None
    try:
        s, _ = create_tcp_server(PORT)
    except Exception as e:
        log_exc(traceback.format_exc())
        return

    _, port = get_socket_name(s)
    ip = sc.get_current_ip() or "0.0.0.0"
    msg = "Listening on %s:%d for stage2..." % (ip, port)
    sc.send_notification(msg)
    log(msg)

    while True:
        log("[*] Waiting for client...")
        try:
            client = accept_client(s)
        except Exception as e:
            log_exc(traceback.format_exc())
            break

        log("[*] Client connected on socket %d" % client)

        try:
            data = read_all_from_socket(client).decode("utf-8", errors="ignore")
        except Exception as e:
            log_exc(traceback.format_exc())
            close_socket(client)
            continue

        script = clean_script(data)
        log("[*] Received payload (%d chars), executing..." % len(script))

        # Setup local payload_log and expose it to the executed script
        global payload_log
        payload_log = []
        SHARED_VARS["client_sock"] = client
        scope = dict(globals(), **locals())
        scope['payload_log'] = payload_log

        try:
            exec(script, scope)
            log("[*] Payload executed successfully")
        except Exception as e:
            log_exc(traceback.format_exc())
        finally:
            if payload_log:
                try:
                    write_to_socket(client, "".join(payload_log).encode("utf-8"))
                except Exception:
                    pass
            SHARED_VARS.pop("client_sock", None)
            close_socket(client)

    close_socket(s)

poc()
