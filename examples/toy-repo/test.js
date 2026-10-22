const assert = require("node:assert");
const { greet } = require("./index");

assert.strictEqual(greet("Mundo"), "Hola, Mundo");
console.log("ok: greet");
