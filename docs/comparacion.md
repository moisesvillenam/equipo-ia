# Comparación

## Con un agente y `git diff`

Un agente puede producir un parche rápido. Equipo IA añade:

- ejecución sobre una copia, no sobre el árbol real;
- pruebas actuales y del commit base;
- detección de cambios en rutas protegidas;
- revisión con nonce;
- acta y estados explícitos.

## Con CI tradicional

La CI responde “¿pasan las pruebas de este commit?”. Equipo IA responde además:

- ¿el parche se aplica sobre la base?
- ¿las pruebas de la base siguen pasando con el parche?
- ¿el agente tocó las pruebas o la configuración?
- ¿un revisor independiente aprobó el diff?
- ¿qué evidencia queda de todo eso?

No reemplaza a la CI: el parche validado debería pasar también por la CI del
proyecto antes de fusionarse.

## Con frameworks multiagente

CrewAI, AutoGen, LangGraph y similares se centran en roles, conversación y
herramientas. Equipo IA se centra en una **política de aceptación**:

| Aspecto | Frameworks típicos | Equipo IA |
|---|---|---|
| Objetivo | Coordinar agentes | Validar un parche |
| Salida | Conversación / acciones | Parche + acta |
| Pruebas | Depende del agente | Actuales + base congelada |
| Rutas protegidas | Poco común | Sí, por defecto |
| Veredicto | Texto libre | Nonce + formato exigido |
| Aplicación | Automática o manual | Manual, con comprobaciones |
| Instalación | SDK y runtime | Bash + CLIs existentes |

## Con procedencia formal (in-toto, SLSA)

Equipo IA no pretende ser una cadena de procedencia firmada. Su acta es evidencia
local y verificable, no una atestación criptográfica de identidad. Una versión
futura podría firmar el acta y encadenarla con la CI. Hoy la propuesta es más
modesta: hacer visible lo que se verificó y lo que no.

## La combinación distintiva

Lo novedoso no es “usar varios agentes”. Es la combinación de:

1. parche aislado contra un commit base;
2. pruebas congeladas sobre la base + parche;
3. rutas protegidas que fuerzan revisión humana;
4. veredicto ligado a un nonce generado después del parche;
5. estados honestos y acta con límites explícitos.

Esa combinación es la que convierte una conversación con agentes en un artefacto
revisable.
