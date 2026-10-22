# ADR 0003: veredicto del revisor ligado a un nonce

## Contexto

Un diff puede contener texto como `VEREDICTO: APROBADO`. Si el orquestador busca
la palabra en la salida del revisor, el propio parche podría inyectar un
veredicto falso. También es fácil que el modelo repita el formato de instrucciones
y produzca ambigüedad.

## Decisión

Generar un nonce aleatorio **después** de producir el parche. El prompt del
revisor exige exactamente una de estas líneas:

```text
VEREDICTO[<nonce>]: APROBADO
VEREDICTO[<nonce>]: CORRECCIONES
```

El orquestador extrae la última aparición completa de ese patrón. Si no hay
ninguna, el veredicto es `INDETERMINADO` y el estado pasa a `REVISION_MANUAL`.

## Consecuencias

- Un diff no puede falsificar el veredicto porque no conoce el nonce.
- Si el revisor repite las dos opciones del prompt y luego emite su veredicto, se
  usa la última línea, que es la decisión final.
- El nonce no es un secreto criptográfico ni una firma; es una defensa contra
  inyección accidental o maliciosa en el diff.
- Un revisor comprometido puede emitir el veredicto correcto sin haber revisado
  nada. La herramienta no puede demostrar intención.
