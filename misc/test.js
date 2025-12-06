/* This file is to be used for testing of WebAssembly output using
   node.  It requires the existence of a "out.wasm" file in the same
   directory. Moreover, that file should define a function "main()"
   that serves as the entry point for Walrus.  See Walrus/wasm.py for
   more details.  You should not have to modify any part of this file.

   To run this code, type a command such as this:

   bash % node test.js
   ... should see the output from Walrus ...
*/

const fs = require ('fs');
const bytes = fs.readFileSync (__dirname + '/out.wasm');

let importObject = {
    // Runtime functions imported by Walrus from the JavaScript environment. 
    env: {
        _print_int: (x) => { console.log(x); },
	_print_float: (x) => { console.log(x); },
	_print_char: (x) => { process.stdout.write(String.fromCharCode(x)); }
      },
};

// Run the program.  
(async () => {
    const obj = await WebAssembly.instantiate (new Uint8Array(bytes), importObject);
    obj.instance.exports.main();
})();
