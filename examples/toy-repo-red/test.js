const test = require("node:test");
const assert = require("node:assert");
const { greet } = require("./index");

// Expectativa obsoleta que ya falla en la base: el saludo real lleva coma.
test("legacy: el saludo no lleva coma", () => {
  assert.strictEqual(greet("Mundo"), "Hola Mundo");
});

test("greet devuelve el saludo con coma", () => {
  assert.strictEqual(greet("Mundo"), "Hola, Mundo");
});
