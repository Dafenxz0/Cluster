# Clúster de LLM locales sin GPU

Proyecto práctico de inferencia de modelos de lenguaje con **tres ordenadores activos** (Intel Core i7-4770, 16 GiB RAM por nodo), usando Ubuntu, llama.cpp, modelos cuantizados, Ray y una API compatible con clientes OpenAI.

**El README principal está en inglés:** [README.md](README.md).

## Resultados documentados

Según las notas guardadas el **21 de septiembre de 2026**, con tres nodos y seis peticiones simultáneas se observaron aproximadamente **33,22 tokens generados por segundo en total**. Con doce peticiones, **34,92 tok/s agregados**. No significa que una sola respuesta genere 34,92 tok/s, ni que se haya entrenado un LLM distribuido.

## ¿Qué hay aquí?

- `api/`: implementación de referencia reconstruida y sanitizada, no copia exacta del servidor final.
- `legacy/`: ejemplo del enfoque anterior de actores Ray con afinidad por nodo.
- `scripts/`: benchmark, arranque de llama-server y un artefacto RPC experimental recuperado y sanitizado.
- `docs/`: decisiones de arquitectura, resultados históricos, lecciones técnicas y consideraciones de seguridad.
- `tests/`: pruebas unitarias del balanceador y la configuración.

**Límites:** el cuarto nodo estaba planeado, no se documenta como activo. Los resultados se basan en notas históricas, no en un benchmark repetido ahora. No se incluyen pesos de modelos, contraseñas, direcciones reales ni información de la organización donde se probó el sistema.
