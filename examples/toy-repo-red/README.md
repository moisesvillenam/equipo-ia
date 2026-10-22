# Toy repo con base roja

Repositorio mínimo para comprobar la validación relativa: la prueba
`legacy: el saludo no lleva coma` ya falla en el commit base.

Un parche que no añada fallos nuevos debe poder validarse. Un parche que rompa
`greet devuelve el saludo con coma` introduce una regresión y se rechaza.

No se usa en la demo principal; solo en las pruebas de extremo a extremo.
