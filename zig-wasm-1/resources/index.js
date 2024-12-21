// Functions imported from WASM.
let add, alloc, free, sub, zlog;
let memory = new WebAssembly.Memory({ initial: 1024, maximum: 1024 });

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

// The environment we export to WASM.
let importObject = {
  env: {
    // We export this function to WASM land.
    jsLog: (ptr, len) => {
      const msg = decodeStr(ptr, len);
      document.querySelector("#log").textContent = msg;
      console.log(msg);
    },
    memory: memory, //Only useful when importing memory in wasm
    __indirect_function_table: new WebAssembly.Table({ initial: 256, element: "anyfunc" }),
    __stack_pointer: new WebAssembly.Global({ value: "i32", mutable: true }, 0),
    __memory_base: 1024,
    __table_base: 0,
  },
};

// Instantiate WASM module and run our test code.
WebAssembly.instantiateStreaming(fetch("./zig-wasm-1.wasm"), importObject).then(
  (wasm_binary) => {
    // Import the functions from WASM land.
    ({ add, alloc, free, sub, zlog } = wasm_binary.instance.exports);

    // Passing a string across the JS to WASM boundary.
    const [ptr, len, capacity] = encodeStr("Hello from Zig + JS + WASM 🦎⚡!");
    zlog(ptr, len);
    // We need to manually free the string's bytes in WASM memory.
    free(ptr, capacity);

    // Call the math functions.
    document.querySelector("#sum").textContent = "add(45, 12): " + add(45, 12);
    document.querySelector("#diff").textContent = "sub(43, 1): " + sub(43, 1);
  },
);
