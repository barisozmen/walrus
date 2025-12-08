/**
 * Walrus WebAssembly Runtime
 *
 * This module provides runtime functions for Walrus programs compiled to WebAssembly.
 * These functions are imported by the generated Wasm module.
 */

/**
 * Create the runtime import object for WebAssembly instantiation
 * @returns {Object} Import object with runtime functions
 */
function createRuntime() {
  return {
    runtime: {
      /**
       * Print an integer value
       * @param {number} x - Integer to print
       * @returns {number} Always returns 0
       */
      print_int: (x) => {
        console.log(`Out: ${x}`);
        return 0;
      },

      /**
       * Print a floating point value
       * @param {number} x - Float to print
       * @returns {number} Always returns 0
       */
      print_float: (x) => {
        console.log(`Out: ${x}`);
        return 0;
      },

      /**
       * Print a character
       * @param {number} x - Character code point to print
       * @returns {number} Always returns 0
       */
      print_char: (x) => {
        process.stdout.write(String.fromCharCode(x));
        return 0;
      },

      /**
       * Print a string (placeholder - strings not fully supported yet)
       * @param {number} ptr - String pointer/index
       * @returns {number} Always returns 0
       */
      print_str: (ptr) => {
        console.log(`Out: [string@${ptr}]`);
        return 0;
      },

      /**
       * Read an integer from input
       * In Node.js, this is a placeholder that returns 0
       * @returns {number} The input integer
       */
      gets_int: () => {
        // In a real implementation, this would read from stdin
        // For now, return 0 as a placeholder
        console.warn('Warning: gets_int not fully implemented, returning 0');
        return 0;
      }
    }
  };
}

// Export for use in loader
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { createRuntime };
}
