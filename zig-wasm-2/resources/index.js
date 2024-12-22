const canvas = document.getElementById("myCanvas");
const ctx = canvas.getContext("2d");

// Functions imported from WASM.
let memory, _start, gameLoop;
//let memory = new WebAssembly.Memory({ initial: 0x1000, maximum: 0x1000 });

// Convenience function to prepare a typed byte array
// from a pointer and a length into WASM memory.
function getView(ptr, len) {
  return new Uint8Array(memory.buffer, ptr, len);
}

// JS strings are UTF-16 and have to be encoded into an
// UTF-8 typed byte array in WASM memory.
function encodeStr(str) {
  const capacity = str.length * 2 + 5; // As per MDN
  const ptr = alloc(capacity);
  const { written } = new TextEncoder().encodeInto(str, getView(ptr, capacity));
  return [ptr, written, capacity];
}

// Decode UTF-8 typed byte array in WASM memory into
// UTF-16 JS string.
function decodeStr(ptr, len) {
  return new TextDecoder().decode(getView(ptr, len));
}

// Helper function to convert color from u32 to CSS color string
function u32ToCssColor(color) {
  const r = (color >> 24) & 0xff;
  const g = (color >> 16) & 0xff;
  const b = (color >> 8) & 0xff;
  const a = (color & 0xff) / 255; // Alpha in range [0, 1]
  return `rgba(${r},${g},${b},${a})`;
}

function wasi_fd_write(fd, iovs, iovs_len, ret_ptr) {
  //const m_memory = new Uint32Array(memory.buffer);
  
  let nwritten = 0;
  for (let i = 0; i < iovs_len; i++) {
      const offset = i * 8; // = jump over 2 i32 values per iteration
      const iov = new Uint32Array(memory.buffer, iovs + offset, 2);
      // use the iovs to read the data from the memory
      const bytes = new Uint8Array(memory.buffer, iov[0], iov[1]);
      const data = new TextDecoder("utf8").decode(bytes);
      console.log(fd, data);
      nwritten += iov[1];
  }

  // Set the nwritten in ret_ptr
  const bytes_written = new Uint32Array(memory.buffer, ret_ptr, 1);
  bytes_written[0] = nwritten;
  console.log(`bytes written: ${memory[ret_ptr]}`)

  return 0;
}

const wasi_random_get = (memory, ptr, len) => {
    if (typeof crypto === 'undefined' || typeof crypto.getRandomValues !== 'function') {
        throw new Error("Secure random number generation is not supported in this environment.");
    }

    // Create a view of the WASM memory to fill with random data
    const view = new Uint8Array(memory.buffer, ptr, len);

    // Fill the memory with random values
    crypto.getRandomValues(view);

    return 0; // WASI_ERRNO_SUCCESS
};

const wasi_proc_exit = (exit_code) => {
    // In a browser-like environment, simulate process exit
    throw new Error(`WASI process exited with code: ${exit_code}`);
};

// The environment we export to WASM.
let importObject = {
  env: {
    // We export this function to WASM land.
    jsLog: (ptr, len) => {
      const msg = decodeStr(ptr, len);
      console.log(msg);
    },
    drawRectangle: (xpos, ypos, xsize, ysize, color) => {
      ctx.fillStyle = u32ToCssColor(color);
      ctx.fillRect(xpos, ypos, xsize, ysize);
    },
    clearBackground: (color) => {
      ctx.fillStyle = u32ToCssColor(color);
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    },
    requestAnimationFrame: (callback) => window.requestAnimationFrame(callback),
  },
  wasi_snapshot_preview1: {
    fd_write: wasi_fd_write,
    random_get: (ptr, len) => wasi_random_get(memory, ptr, len),
    proc_exit: wasi_proc_exit,
  },
};

// Instantiate WASM module and run our test code.
(async () => {
WebAssembly.instantiateStreaming(fetch("./zig-wasm-2.wasm"), importObject).then(
  (wasm_binary) => {
    // Import the functions from WASM land.
    ({ _start, gameLoop, memory } = wasm_binary.instance.exports);
    _start();

    // Provide the `requestAnimationFrame` function for WASM
    //window.requestAnimationFrame(gameLoop);

  },
);
})();
